# Keysight CloudLens Manager - Terraform Deployment Guide

## Table of Contents
- [Keysight CloudLens Manager - Terraform Deployment Guide](#keysight-cloudlens-manager---terraform-deployment-guide)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Document Overview](#document-overview)
  - [Getting Started with GitHub Clone](#getting-started-with-github-clone)
    - [Files in the Repository](#files-in-the-repository)
    - [Multi-Team Usage](#multi-team-usage)
  - [Prerequisites](#prerequisites)
  - [Understanding the Deployment Options](#understanding-the-deployment-options)
    - [Scenario 1: `clms.tf` (New VPC)](#scenario-1-clmstf-new-vpc)
    - [Scenario 2: `clms-existing-vpc.tf` (Existing VPC)](#scenario-2-clms-existing-vpctf-existing-vpc)
  - [Terraform Installation](#terraform-installation)
  - [AWS Configuration](#aws-configuration)
  - [Deployment Scenario 1: Creating New VPC Infrastructure (`clms.tf`)](#deployment-scenario-1-creating-new-vpc-infrastructure-clmstf)
  - [Deployment Scenario 2: Using Existing VPC Infrastructure (`clms-existing-vpc.tf`)](#deployment-scenario-2-using-existing-vpc-infrastructure-clms-existing-vpctf)
  - [Post-Deployment Steps](#post-deployment-steps)
  - [Troubleshooting](#troubleshooting)
  - [Cleanup and Resource Management](#cleanup-and-resource-management)
  - [Best Practices for Multi-Team Use](#best-practices-for-multi-team-use)

---

## Introduction
This guide provides step-by-step instructions for deploying **Keysight CloudLens Manager v6.12.1** on Amazon Web Services (AWS) using Terraform infrastructure-as-code. 

CloudLens Manager is a network visibility and packet tapping solution that enables you to monitor traffic across cloud instances and forward it to analysis tools.

---

## Document Overview
This documentation is designed for users with **no prior Terraform or infrastructure-as-code experience**. By following this guide, you will:

- Clone and set up the GitHub repository  
- Install and configure Terraform on your operating system  
- Set up AWS credentials for automated deployment  
- Choose between two deployment scenarios (`clms.tf` or `clms-existing-vpc.tf`)  
- Deploy CloudLens Manager with appropriate networking and security configurations  
- Access and configure your CloudLens Manager instance  
- Manage and clean up the deployed resources  

---

## Getting Started with GitHub Clone

To get started, clone the repository and navigate into it:

```bash
git clone https://github.com/YOUR_ORG/cloudlens-terraform.git
cd cloudlens-terraform
```

### Files in the Repository
- `clms.tf` → Deploys CloudLens Manager into a **new VPC** (Scenario 1).  
- `clms-existing-vpc.tf` → Deploys CloudLens Manager into an **existing VPC** (Scenario 2).  
- `ReadMe.md` → Documentation guide (this file).  

### Multi-Team Usage
- Each team can fork the repository or clone it locally.  
- Teams should customize their own **`terraform.tfvars`** (or use CLI vars).  
- Avoid conflicts by using separate Terraform state files (see [Best Practices](#best-practices-for-multi-team-use)).  

---

## Prerequisites
- AWS Marketplace subscription for Keysight CloudLens Manager  
- IAM user with programmatic access (EC2 + VPC permissions)  
- Existing EC2 key pair in your AWS region  
- Computer with Terraform and AWS CLI installed  
- Outbound internet access on port 443  

---

## Understanding the Deployment Options

### Scenario 1: `clms.tf` (New VPC)
Creates a new VPC, subnet, IGW, security group, and EC2 instance.  

### Scenario 2: `clms-existing-vpc.tf` (Existing VPC)
Uses your existing VPC and subnet, only creates security group + EC2 instance.  

---

## Terraform Installation

- [Terraform Installation Guide](https://developer.hashicorp.com/terraform/downloads)  
- [AWS CLI Installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)  

**Verify installs:**  
```bash
terraform version
aws --version
```

---

## AWS Configuration

Set up AWS credentials with your chosen profile:  

```bash
aws configure --profile YOUR_PROFILE_NAME
```

Update the Terraform provider block in `clms.tf` or `clms-existing-vpc.tf`:  
```hcl
provider "aws" {
  region  = var.aws_region
  profile = "YOUR_PROFILE_NAME"
}
```

---

## Deployment Scenario 1: Creating New VPC Infrastructure (`clms.tf`)

```bash
mkdir ~/cloudlens-new-vpc
cd ~/cloudlens-new-vpc

terraform init
terraform plan
terraform apply
```

**Outputs:**  
```bash
terraform output cloudlens_ui_url
terraform output -json default_credentials
```

---

## Deployment Scenario 2: Using Existing VPC Infrastructure (`clms-existing-vpc.tf`)

```bash
mkdir ~/cloudlens-existing-vpc
cd ~/cloudlens-existing-vpc

terraform init
terraform validate
terraform plan
terraform apply
```

**Outputs:**  
```bash
terraform output cloudlens_ui_url
terraform output existing_vpc_info
terraform output -json default_credentials
```

---

## Post-Deployment Steps

1. Wait **15 minutes** for CloudLens Manager initialization.  
2. Access the CloudLens UI using the output URL.  
3. Bypass SSL warning (self-signed certificate).  
4. Login with default credentials:  
   - **Username:** `admin`  
   - **Password:** `Cl0udLens@dm!n`  

Change the password immediately after first login.

---

## Troubleshooting

- **InvalidKeyPair.NotFound**  
```bash
aws ec2 describe-key-pairs --region us-east-1 --profile YOUR_PROFILE_NAME
```

- **OptInRequired** → Subscribe to CloudLens on AWS Marketplace.  
- **No valid credentials** → Run `aws configure --profile YOUR_PROFILE_NAME`.  
- **State lock error** → Remove `.terraform.tfstate.lock.info`.  

---

## Cleanup and Resource Management

Destroy all deployed resources:  
```bash
terraform destroy
```

---

## Best Practices for Multi-Team Use

1. **Separate State Files**  
   - Use `-state` flag or remote backend (S3 + DynamoDB) per team.  
   - Example S3 backend: [Terraform Remote State](https://developer.hashicorp.com/terraform/language/settings/backends/s3).  

2. **Branch per Team**  
   - Each team can maintain their own branch with customized variables.  

3. **Use Workspaces**  
   - `terraform workspace new team1`  
   - `terraform workspace select team1`  

4. **CI/CD Integration**  
   - Automate deployments with GitHub Actions or Jenkins for consistency.  

---

**Author:** Cloud Architecture Team  
**Docs:** [Terraform](https://developer.hashicorp.com/terraform/docs), [AWS EC2](https://docs.aws.amazon.com/ec2), [Keysight Support](https://support.keysight.com)
