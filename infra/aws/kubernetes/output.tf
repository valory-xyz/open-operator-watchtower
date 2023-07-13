output "worker_security_groups" {
  description = "module.aws_cluster.worker_security_groups"
  value       = module.aws_cluster.worker_security_groups
}

output "worker_target_group_http" {
  description = "module.aws_cluster.worker_target_group_http"
  value       = module.aws_cluster.worker_target_group_http
}
