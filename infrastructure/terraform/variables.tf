# =============================================================================
# DevOps Testing App - Terraform Variables
# =============================================================================
# All input variables for the infrastructure
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "AWS access key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret access key"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devops-testing-app"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be 'staging' or 'production'."
  }
}

variable "owner_email" {
  description = "Owner email for tagging"
  type        = string
  default     = "daniel.mazhbits@gmail.com"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH (your IP)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# EC2 Configuration - Jenkins
# -----------------------------------------------------------------------------
variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "t3.small"
}

variable "jenkins_volume_size" {
  description = "EBS volume size for Jenkins (GB)"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# EC2 Configuration - App
# -----------------------------------------------------------------------------
variable "app_instance_type" {
  description = "EC2 instance type for application server"
  type        = string
  default     = "t3.micro"
}

variable "app_volume_size" {
  description = "EBS volume size for app server (GB)"
  type        = number
  default     = 20
}

# -----------------------------------------------------------------------------
# SSH Key Configuration
# -----------------------------------------------------------------------------
variable "key_name" {
  description = "Name of the AWS key pair"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Local path to SSH private key"
  type        = string
}

# -----------------------------------------------------------------------------
# Docker Configuration
# -----------------------------------------------------------------------------
variable "docker_hub_username" {
  description = "Docker Hub username"
  type        = string
}

variable "docker_hub_token" {
  description = "Docker Hub access token"
  type        = string
  sensitive   = true
}

variable "docker_image_name" {
  description = "Docker image name (without registry)"
  type        = string
  default     = "devops-testing-app"
}

# -----------------------------------------------------------------------------
# GitHub Configuration
# -----------------------------------------------------------------------------
variable "github_username" {
  description = "GitHub username"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "devops-ci-cd-exercise"
}

# -----------------------------------------------------------------------------
# JIRA Configuration
# -----------------------------------------------------------------------------
variable "jira_url" {
  description = "JIRA instance URL"
  type        = string
}

variable "jira_email" {
  description = "JIRA user email"
  type        = string
}

variable "jira_api_token" {
  description = "JIRA API token"
  type        = string
  sensitive   = true
}

variable "jira_project_key" {
  description = "JIRA project key for issue creation"
  type        = string
  default     = "CICD"
}

# -----------------------------------------------------------------------------
# Jenkins Configuration
# -----------------------------------------------------------------------------
variable "jenkins_admin_user" {
  description = "Jenkins admin username"
  type        = string
  default     = "admin"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password"
  type        = string
  sensitive   = true
  default     = "admin123!"
}
