# Keysight CloudLens Manager - AWS Terraform Deployment
# For use with existing VPC and network infrastructure

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

# Existing VPC Configuration
variable "existing_vpc_id" {
  description = "ID of the existing VPC to deploy into"
  type        = string
}

variable "existing_subnet_id" {
  description = "ID of the existing public subnet to deploy CloudLens Manager into"
  type        = string
}

variable "existing_route_table_id" {
  description = "ID of the existing route table (optional - for validation)"
  type        = string
  default     = ""
}

# CloudLens Instance Configuration
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

# Security Configuration
variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access (use 0.0.0.0/0 with caution)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "additional_security_group_ids" {
  description = "List of additional security group IDs to attach to the instance"
  type        = list(string)
  default     = []
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

  ami_id = lookup(local.cloudlens_amis, var.aws_region, null)
  
  # Combine CloudLens security group with any additional security groups
  all_security_group_ids = concat([aws_security_group.cloudlens.id], var.additional_security_group_ids)
}

# ============================================================================
# DATA SOURCES - Validate existing infrastructure
# ============================================================================

data "aws_vpc" "existing" {
  id = var.existing_vpc_id
}

data "aws_subnet" "existing" {
  id = var.existing_subnet_id
}

data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.existing_vpc_id]
  }
}

# ============================================================================
# SECURITY GROUP
# ============================================================================

resource "aws_security_group" "cloudlens" {
  name_prefix = "cloudlens-manager-"
  description = "Security group for CloudLens Manager"
  vpc_id      = var.existing_vpc_id

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

  subnet_id                   = var.existing_subnet_id
  vpc_security_group_ids      = local.all_security_group_ids
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

    precondition {
      condition     = data.aws_subnet.existing.vpc_id == var.existing_vpc_id
      error_message = "The specified subnet does not belong to the specified VPC."
    }

    precondition {
      condition     = data.aws_subnet.existing.map_public_ip_on_launch == true || true
      error_message = "Warning: Subnet may not auto-assign public IPs. Instance will still get public IP via associate_public_ip_address=true."
    }
  }

  depends_on = [data.aws_internet_gateway.existing]
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "existing_vpc_info" {
  description = "Information about the existing VPC"
  value = {
    vpc_id     = data.aws_vpc.existing.id
    vpc_cidr   = data.aws_vpc.existing.cidr_block
    subnet_id  = data.aws_subnet.existing.id
    subnet_az  = data.aws_subnet.existing.availability_zone
    igw_id     = data.aws_internet_gateway.existing.id
  }
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
    CloudLens Manager Deployment Successful! (Using Existing VPC)
    ========================================================================
    
    Access URL: https://${aws_instance.cloudlens_manager.public_ip}
    
    IMPORTANT - WAIT 15 MINUTES before accessing the UI
    CloudLens Manager needs time to fully initialize after deployment.
    
    Default Credentials:
      Username: admin
      Password: Cl0udLens@dm!n
    
    Infrastructure Details:
      VPC ID: ${var.existing_vpc_id}
      Subnet ID: ${var.existing_subnet_id}
      Region: ${var.aws_region}
      Instance Type: ${var.instance_type}
      AMI ID: ${local.ami_id}
      Public IP: ${aws_instance.cloudlens_manager.public_ip}
      Private IP: ${aws_instance.cloudlens_manager.private_ip}
    
    CRITICAL SECURITY STEPS:
    1. Change the default password IMMEDIATELY after first login
    2. Review security group rules
    3. Configure license activation in the CloudLens UI
    
    Next Steps:
    1. Verify AWS Marketplace subscription is active
    2. Configure sensor agents to connect to this manager
    3. Set up projects and groups in the CloudLens UI
    ========================================================================
  EOT
}