terraform { required_version = ">= 1.5.0, < 2.0.0" }

variable "add_compute" {
  description = "Create a separate object to compare a pure add with replacement."
  type        = bool
  default     = false
}

import {
  to = terraform_data.legacy
  id = "legacy-service-001"
}

resource "terraform_data" "legacy" {
  input = {
    name  = "legacy-service"
    owner = "platform-team"
  }

}

resource "terraform_data" "new_compute" {
  count = var.add_compute ? 1 : 0
  input = {
    name = "new-stateless-compute"
  }
}

output "imported_identity" { value = terraform_data.legacy.id }
