terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  backend "s3" {
    bucket = "filter-govt-bills"
    region = "eu-west-1"
    key    = "terraform.tfstate"
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "eu-west-1"
}

module "build" {
  source = "./modules/build"
}

module "deploy" {
  source          = "./modules/deploy"
  repository_name = module.build.repository_name
  image_tag       = var.image_tag
  port            = 80
  domain          = "elliotmarsden.com"
  subdomain       = "bills"
}
