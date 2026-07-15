terraform { required_version = ">= 1.5.0, < 2.0.0" }
variable "ordered_services" { type = list(string) }
variable "services" { type = map(string) }

resource "terraform_data" "counted" {
  count = length(var.ordered_services)
  input = var.ordered_services[count.index]
}
resource "terraform_data" "keyed" {
  for_each = var.services
  input    = each.value
}
