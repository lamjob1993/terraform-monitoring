output "web_container_name" {
  value = docker_container.web_server.name
}

output "db_container_name" {
  value = docker_container.database.name
}

output "network_name" {
  value = docker_network.env_network.name
}
