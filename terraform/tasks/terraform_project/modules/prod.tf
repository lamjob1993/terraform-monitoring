module "prod" {
  source      = "./modules/environment"
  env_name    = "prod"
  web_port    = 8082
  db_user     = "prod_user"
  db_password = "prod_password"
}
