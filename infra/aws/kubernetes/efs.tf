
resource "aws_efs_file_system" "efs_ephemeral" {
  creation_token   = format("efs-%s", var.cluster_name)
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = "true"
  tags = {
    Name = format("%s-ephemeral-storage", var.cluster_name)
  }
}


resource "aws_efs_mount_target" "efs-ephemeral-mt" {
   for_each = toset(module.aws_cluster.subnet_ids)
   subnet_id = each.value
   file_system_id  = aws_efs_file_system.efs_ephemeral.id
   security_groups = module.aws_cluster.worker_security_groups
 }
 