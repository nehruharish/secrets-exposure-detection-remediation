variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "project_name" {
  type    = string
  default = "secrets-exposure-demo"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers and hyphens."
  }
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "github_repository" {
  description = "GitHub OWNER/REPOSITORY used by the OIDC trust policy"
  type        = string
  default     = "REPLACE_ME/secrets-exposure-detection-remediation"
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use OWNER/REPOSITORY format."
  }
}

variable "demo_secret_value" {
  description = "Synthetic demo value only; never use a real credential."
  type        = string
  sensitive   = true
  default     = "EXAMPLE_NOT_A_REAL_SECRET_123"
}

variable "alert_email" {
  description = "Email address subscribed to the security-alerts SNS topic that the CloudWatch alarm publishes to. Leave empty to skip creating a subscription (the topic and alarm still exist)."
  type        = string
  default     = ""
}

variable "TF_STATE_BUCKET" {
  description = "Bucket to store Terraform state file"
  type        = string
  default     = ""
}