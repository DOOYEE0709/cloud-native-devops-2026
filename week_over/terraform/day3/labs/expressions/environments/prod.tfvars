environment_config = {
  name              = "prod"
  instance_count    = 3
  enable_monitoring = true
  allowed_cidrs     = ["10.10.0.0/16", "10.20.0.0/16"]
  extra_tags        = { Owner = "platform-team", Criticality = "high" }
}
