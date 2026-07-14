output "application_summary" {
  description = "Application values and the network identity referenced by the application."
  value = {
    application = terraform_data.application.output.name
    network_id  = terraform_data.application.output.network_id
    owner       = terraform_data.application.output.owner
  }
}
