variable "region" {
  description = "Region"
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Base name for the S3 bucket"
  default     = "olist-ecom-dev"
}

variable "environment" {
  description = "Deployment environment"
  default     = "dev"
}

variable "pipeline_name" {
  type        = string
  description = "Name for the pipeline"
}

variable "cpu" {
  type    = string
  default = "256"
}

variable "memory" {
  type    = string
  default = "512"
}

variable "cpu_architecture" {
  type    = string
  default = "ARM64"
}

variable "redshift_db_name" {
  description = "Name of the Redshift database"
  type        = string
  default     = "olist_dev"
}

variable "redshift_admin_username" {
  description = "Redshift admin username"
  type        = string
  default     = "admin"
}

variable "redshift_admin_password" {
  description = "Redshift admin password"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID for the Redshift security group"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to Redshift (e.g. your home IP)"
  type        = list(string)
  default     = []
}