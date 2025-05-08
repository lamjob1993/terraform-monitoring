variable "environments" {
  description = "Map of environment configurations"
  type = map(object({
    web_port    = number
    db_user     = string
    db_password = string
  }))
  default = {
    dev = {
      web_port    = 8080
      db_user     = "dev_user"
      db_password = "dev_password"
    }
    staging = {
      web_port    = 8081
      db_user     = "staging_user"
      db_password = "staging_password"
    }
    prod = {
      web_port    = 8082
      db_user     = "prod_user"
      db_password = "prod_password"
    }
  }
}
