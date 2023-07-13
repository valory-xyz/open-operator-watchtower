terraform {
  backend "s3" {
    #bucket         = "open-operator-aks"
    key            = "tf_docker_compose/terraform.tfstate"
    region         = "us-east-2"
    #dynamodb_table = "open_operator_terraform_state_lock"
    #encrypt        = true
  }
}

resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  tags = {
    Name = "operator-vpc"

  }
}

resource "aws_subnet" "public-subnet" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = format("%sa", var.deployment_region)
    tags = {
        Name = "public-subnet"
    }
}
#
resource "aws_route_table" "public-route" {
 vpc_id = aws_vpc.vpc.id
 tags = {
   Name = "public-route"
  }
} 
#
#
resource "aws_internet_gateway" "internet-gateway" {
 vpc_id = aws_vpc.vpc.id
 tags = {
        Name = "internet-gateway"
  }
} 
#
resource "aws_route" "internet-access" {
  route_table_id         = aws_route_table.public-route.id
  destination_cidr_block = "0.0.0.0/0" 
  gateway_id             = aws_internet_gateway.internet-gateway.id

} 

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-route.id
} 

resource "aws_key_pair" "operator_ssh_pub_key" {
  key_name   = "operator_ssh_pub_key"
  public_key = file(var.operator_ssh_pub_key_path)
}

resource "aws_instance" "ubuntu-host" {
  ami                    = "ami-0a695f0d95cefc163"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public-subnet.id
  key_name               = aws_key_pair.operator_ssh_pub_key.key_name
  security_groups        = [
    aws_security_group.ingress.id,
    aws_security_group.tendermint_ingress.id
    ]

  tags = {
    Name = "as-docker-compose-instance"
    }
  user_data = file("${path.module}/../../../scripts/provision_instance.sh")
}


resource "aws_security_group" "ingress" {
name = "allow-all-sg"
vpc_id = "${aws_vpc.vpc.id}"
ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
from_port = 22
    to_port = 22
    protocol = "tcp"
  }
// Terraform removes the default rule
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}

resource "aws_security_group" "tendermint_ingress" {
name = "allow-tendermint-sg"
vpc_id = "${aws_vpc.vpc.id}"
ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = var.tendermint_ingress_port
    to_port = var.tendermint_ingress_port
    protocol = "tcp"
  }
// Terraform removes the default rule
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}
