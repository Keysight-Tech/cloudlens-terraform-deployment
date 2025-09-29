# Keysight CloudLens Manager - AWS Terraform Deployment
# Production-ready template for deploying CloudLens Manager from AWS Marketplace

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# VARIABLES - Configure these to customize your deployment
# ============================================================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
  default     = "cloudlens-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the subnet (leave empty for automatic selection)"
  type        = string
  default     = "us-east-1a"
}

variable "instance_name" {
  description = "Name tag for the CloudLens Manager EC2 instance"
  type        = string
  default     = "cloudlens-manager"
}

variable "instance_type" {
  description = "EC2 instance type (minimum t3.xlarge recommended: 4 vCPUs, 16GB RAM)"
  type        = string
  default     = "t3.xlarge"
}

variable "key_pair_name" {
  description = "Name of existing EC2 key pair for SSH access (leave empty to skip SSH key)"
  type        = string
  default     = "eks-terraform-key"
}

variable "root_volume_size" {
  description = "Root volume size in GB (minimum 200GB required)"
  type        = number
  default     = 200
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access (use 0.0.0.0/0 with caution)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "CloudLens"
    Environment = "Dev"
    ManagedBy   = "Brine"
  }
}

# ============================================================================
# PROVIDER CONFIGURATION
# ============================================================================

provider "aws" {
  region  = var.aws_region
  profile = "brine"
}

# ============================================================================
# LOCAL VARIABLES
# ============================================================================

locals {
  # CloudLens Manager v6.12.1 AMI IDs per region (from AWS Marketplace)
  cloudlens_amis = {
    "ap-south-2"     = "ami-0b58a86b447402ebc"
    "ap-south-1"     = "ami-0de9998616b04343e"
    "eu-south-1"     = "ami-08c54eb5627676529"
    "eu-south-2"     = "ami-00fe9ffc05f1c83b9"
    "us-gov-east-1"  = "ami-01885059be96ad228"
    "me-central-1"   = "ami-0fb54089c3036f0cd"
    "il-central-1"   = "ami-071b41ac0cb423b82"
    "ca-central-1"   = "ami-0b4ec2f46fc51cd6d"
    "ap-east-2"      = "ami-088c50e1b751b01e6"
    "mx-central-1"   = "ami-0ad6409352b7419c9"
    "eu-central-1"   = "ami-0e8c6cc855fcfc22"
    "eu-central-2"   = "ami-0514eff795d7588e3"
    "us-west-1"      = "ami-0420c02f2c555a402"
    "us-west-2"      = "ami-0f3fba668617b18f1"
    "af-south-1"     = "ami-0b39c43b5ea96d07d"
    "eu-west-3"      = "ami-0ff96c646488ad267"
    "eu-north-1"     = "ami-051d4022ca7c470b6"
    "eu-west-2"      = "ami-0c8189014261e3c7f"
    "eu-west-1"      = "ami-0bf7638d1e75aac19"
    "ap-northeast-3" = "ami-01c9ec670e4788998"
    "ap-northeast-2" = "ami-099ba3b2908624c03"
    "me-south-1"     = "ami-0e5287f30ce6300ca"
    "ap-northeast-1" = "ami-05383c85ebe460ee6"
    "sa-east-1"      = "ami-0d2c8a03971d49c4b"
    "ap-east-1"      = "ami-023b7fb4377e4c6cc"
    "us-gov-west-1"  = "ami-064ec0e6029f94039"
    "ca-west-1"      = "ami-0022f9cbaa3b726ef"
    "ap-southeast-1" = "ami-04955ec1c6899170d"
    "ap-southeast-2" = "ami-00fb08ffc483a3ea1"
    "ap-southeast-3" = "ami-0527033d7fa838a8d"
    "ap-southeast-4" = "ami-01057ee69eba1ef76"
    "us-east-1"      = "ami-0bebd5e730315337e"
    "ap-southeast-5" = "ami-09f851ed8aae05210"
    "us-east-2"      = "ami-085c6b0cf292a110f"
    "ap-southeast-7" = "ami-0e5aa1deb5728b516"
  }

  ami_id            = lookup(local.cloudlens_amis, var.aws_region, null)
  availability_zone = var.availability_zone != "" ? var.availability_zone : data.aws_availability_zones.available.names[0]
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================================
# VPC RESOURCES
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.common_tags,
    {
      Name = var.vpc_name
    }
  )
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.vpc_name}-public-subnet"
      Type = "Public"
    }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.vpc_name}-igw"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.vpc_name}-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ============================================================================
# SECURITY GROUP
# ============================================================================

resource "aws_security_group" "cloudlens" {
  name_prefix = "cloudlens-manager-"
  description = "Security group for CloudLens Manager"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTPS access for CloudLens UI and sensor communication
  ingress {
    description = "HTTPS access for CloudLens UI and sensor communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.instance_name}-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# EC2 INSTANCE - CloudLens Manager
# ============================================================================

resource "aws_instance" "cloudlens_manager" {
  ami           = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name != "" ? var.key_pair_name : null

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.cloudlens.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      var.common_tags,
      {
        Name = "${var.instance_name}-root-volume"
      }
    )
  }

  tags = merge(
    var.common_tags,
    {
      Name = var.instance_name
    }
  )

  lifecycle {
    precondition {
      condition     = local.ami_id != null
      error_message = "CloudLens Manager AMI is not available in the selected region: ${var.aws_region}. Please choose a supported region."
    }

    precondition {
      condition     = var.root_volume_size >= 200
      error_message = "Root volume size must be at least 200GB for CloudLens Manager."
    }
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the CloudLens security group"
  value       = aws_security_group.cloudlens.id
}

output "instance_id" {
  description = "ID of the CloudLens Manager EC2 instance"
  value       = aws_instance.cloudlens_manager.id
}

output "instance_public_ip" {
  description = "Public IP address of CloudLens Manager"
  value       = aws_instance.cloudlens_manager.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of CloudLens Manager"
  value       = aws_instance.cloudlens_manager.private_ip
}

output "cloudlens_ui_url" {
  description = "URL to access CloudLens Manager UI (wait ~15 minutes after deployment)"
  value       = "https://${aws_instance.cloudlens_manager.public_ip}"
}

output "default_credentials" {
  description = "Default login credentials for first-time access"
  value = {
    username = "admin"
    password = "Cl0udLens@dm!n"
    note     = "CRITICAL: Change these credentials immediately after first login"
  }
  sensitive = true
}

output "deployment_notes" {
  description = "Important post-deployment information"
  value       = <<-EOT
    ========================================================================
    CloudLens Manager Deployment Successful!
    ========================================================================
    
    Access URL: https://${aws_instance.cloudlens_manager.public_ip}
    
    IMPORTANT - WAIT 15 MINUTES before accessing the UI
    CloudLens Manager needs time to fully initialize after deployment.
    
    Default Credentials:
      Username: admin
      Password: Cl0udLens@dm!n
    
    CRITICAL SECURITY STEPS:
    1. Change the default password IMMEDIATELY after first login
    2. Review and tighten security group rules if needed
    3. Configure license activation in the CloudLens UI
    
    Deployment Details:
      Region: ${var.aws_region}
      Instance Type: ${var.instance_type}
      AMI ID: ${local.ami_id}
      Public IP: ${aws_instance.cloudlens_manager.public_ip}
      Private IP: ${aws_instance.cloudlens_manager.private_ip}
    
    Next Steps:
    1. Verify AWS Marketplace subscription is active
    2. Configure sensor agents to connect to this manager
    3. Set up projects and groups in the CloudLens UI
    ========================================================================
  EOT
}