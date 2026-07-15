environment_config = {
  name              = "dev"
  instance_count    = 1
  enable_monitoring = false
  allowed_cidrs     = ["10.0.0.0/8"]
  extra_tags        = { Owner = "platform-lab" }
}
