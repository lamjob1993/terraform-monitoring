module "staging" {
  source      = "./modules/environment"
  env_name    = "staging"
  web_port    = 8081
  db_user     = "staging_user"
  db_password = "staging_password"
}
