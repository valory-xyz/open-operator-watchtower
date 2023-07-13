provider "aws" {
  region                  = var.deployment_region
  shared_credentials_files = ["~/.aws/credentials"]
}

