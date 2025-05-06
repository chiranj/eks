output "env_file_path" {
  description = "Path to the generated environment variables file"
  value       = "${path.module}/terraform-outputs.env"
}

output "json_file_path" {
  description = "Path to the generated JSON configuration file"
  value       = "${path.module}/terraform-outputs.json"
}