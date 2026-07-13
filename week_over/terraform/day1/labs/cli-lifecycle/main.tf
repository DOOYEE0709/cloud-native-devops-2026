terraform {
  required_version = ">= 1.5.0, < 2.0.0"
}

variable "environment" {
  description = "Name used to distinguish the practice environment."
  type        = string
  default     = "study"

  validation {
    condition     = length(trimspace(var.environment)) >= 3
    error_message = "The environment name must contain at least three characters."
  }
}

resource "terraform_data" "lesson" {
  input = {
    course      = "terraform"
    environment = var.environment
    checkpoint  = "write-plan-apply"
  }

  triggers_replace = [var.environment]
}
