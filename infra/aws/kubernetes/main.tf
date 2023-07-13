
# Kubernetes cluster for AWS 
#
# This script must be applied in two steps, due to the limitations of 
# the modules therein:
#
# terraform apply -target=module.aws_cluster
# terraform apply

terraform {
  required_providers {
    ct = {
      source = "poseidon/ct"
      version = "0.11.0"
    }
    aws = {
      source = "hashicorp/aws"
      version = "4.61.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.10.0"
    }
  }

  backend "s3" {
    bucket = "open-operator-aks"
    key    = "tf_kubernetes/terraform.tfstate"
    region = "us-east-2"
    #dynamodb_table = "open_operator_terraform_state_lock"
    #encrypt        = true
  }
}

provider "ct" {
}


provider "helm" {
  kubernetes {
    config_path = "kubefiles/kubeconfig"
  }
}


module "aws_cluster" {
  source = "git::https://github.com/poseidon/typhoon//aws/flatcar-linux/kubernetes?ref=v1.27.2"

  # AWS
  cluster_name = var.cluster_name
  dns_zone     = var.hosted_zone
  dns_zone_id  = var.hosted_zone_id

  # configuration
  ssh_authorized_key = chomp(file(var.operator_ssh_pub_key_path))

  # optional
  worker_count     = var.worker_count
  worker_type      = var.worker_type
  controller_count = var.controller_count
  controller_type  = var.controller_type
}


resource "aws_route53_record" "app-1" {
  zone_id = var.hosted_zone_id

  name = format("*.%s.%s", var.cluster_name, var.hosted_zone)
  type = "A"
  alias {
    name                   = module.aws_cluster.ingress_dns_name
    zone_id                = module.aws_cluster.ingress_zone_id
    evaluate_target_health = false
  } # DNS zone name
  # DNS record
}


resource "aws_security_group_rule" "nfs_inbound_rule" {
  for_each = toset(module.aws_cluster.worker_security_groups)

  security_group_id = each.value

  type            = "ingress"
  from_port       = 2049
  to_port         = 2049
  protocol        = "tcp"
  source_security_group_id = each.value
}


resource "local_file" "kubeconfig" {
  content  = module.aws_cluster.kubeconfig-admin
  filename = "kubefiles/kubeconfig"
}


resource "helm_release" "nfs-subdir-external-provisioner" {
  depends_on = [
    local_file.kubeconfig,
    module.aws_cluster,
    aws_security_group_rule.nfs_inbound_rule,
    aws_efs_mount_target.efs-ephemeral-mt
  ]

  name = "nfs-subdir-external-provisioner"

  repository = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/"
  chart      = "nfs-subdir-external-provisioner"

  set {
    name  = "nfs.server"
    value = aws_efs_file_system.efs_ephemeral.dns_name
  }

  set {
    name  = "nfs.path"
    value = "/"
  }

  set {
    name  = "storageClass.name"
    value = "nfs-ephemeral"
  }

  set {
    name  = "storageClass.archiveOnDelete"
    value = "false"
  }
}