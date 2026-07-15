terraform { required_version = ">= 1.5.0, < 2.0.0" }

variable "environment_config" {
  type = object({
    name              = string
    instance_count    = number
    enable_monitoring = bool
    allowed_cidrs     = set(string)
    extra_tags        = map(string)
  })
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment_config.name)
    error_message = "Environment must be dev, stage, or prod."
  }
}

locals {
  monitoring_mode = var.environment_config.enable_monitoring ? "detailed" : "basic"
  common_tags     = merge({ Environment = var.environment_config.name, ManagedBy = "terraform" }, var.environment_config.extra_tags)
}

resource "terraform_data" "environment" {
  input = {
    name            = var.environment_config.name
    instance_count  = var.environment_config.instance_count
    monitoring_mode = local.monitoring_mode
    allowed_cidrs   = sort(tolist(var.environment_config.allowed_cidrs))
    tags            = local.common_tags
  }
}

output "environment_summary" { value = terraform_data.environment.output }
