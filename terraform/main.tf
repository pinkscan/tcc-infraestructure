terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.20.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region     = var.region
}

module "network" {
  source                = "./modules/network"
  region                = var.region
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  private_subnet_cidrs  = var.private_subnet_cidrs
  availability_zone     = var.availability_zone
}

module "ssh" {
  source   = "./modules/ssh"
  key_name = var.key_name
}

module "compute" {
  source               = "./modules/compute"
  instance_type        = var.instance_type
  key_name             = module.ssh.key_name
  key_private          = module.ssh.private_key
  subnet_public_id     = module.network.public_subnet_id
  private_subnet_ids   = module.network.private_subnet_ids
  boundary_sg_id       = module.network.boundary_sg_id
  instance_sg_id       = module.network.infra_services_sg_id
  instance_profile     = module.iam.instance_profile_name
}
