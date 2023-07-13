variable "deployment_region"{
  description = "Region to deploy"
  type = string
  default = "us-east-2"
}

variable "operator_ssh_pub_key_path"{
  description = "SSH public key path to access the EC2 instances"
  type = string
  default = "~/.ssh/id_rsa.pub"
}

variable "hosted_zone" {
  description = "Hosted zone name"
  type = string
  default     = "astest.online"
}

variable "hosted_zone_id" {
  description = "AWS Route53 hosted zone ID"
  type = string
  default     = "Z0000000000000000000"
}

variable "cluster_name" {
  description = "Cluster name"
  type = string
  default     = "as-cluster"
}

# Do not choose a controller_type smaller than t2.small.
# Smaller instances are not sufficient for running a controller.
variable "controller_type"{
  description = "Type of EC2 to be used for the controller nodes"
  default     = "m5.large"
}

variable "controller_count"{
  description = "Number of controller nodes"
  default     = 2
}

variable "worker_type"{
  description = "Type of EC2 to be used for the worker nodes"
  default     = "m5.large"
}

variable "worker_count"{
  description = "Number of worker nodes."
  default     = 2
}
