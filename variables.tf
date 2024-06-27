# variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# VPC 
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}


# ECR
variable "private_subnet_ecr_cidr" {
  description = "CIDR block for ECR private subnet"
  type        = string
  default     = "10.0.101.0/24"
}

# DB
variable "private_subnet_db_0_cidr" {
  description = "CIDR block for db private subnet"
  type        = string
  default     = "10.0.103.0/24"
}

variable "private_subnet_db_1_cidr" {
  description = "CIDR block for db private subnet"
  type        = string
  default     = "10.0.104.0/24"
}


# EKS

variable "public_subnet_eks_0_cidr" {
  description = "CIDR block for EKS public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_eks_1_cidr" {
  description = "CIDR block for EKS public subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_eks_0_cidr" {
  description = "CIDR block for EKS private subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_eks_1_cidr" {
  description = "CIDR block for EKS private subnet"
  type        = string
  default     = "10.0.4.0/24"
}

# For DB & ECR
variable "allowed_ip" {
  description = "Allowed IP for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "mydbuser"
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "mydbPW5dhGf1ss880"
}
