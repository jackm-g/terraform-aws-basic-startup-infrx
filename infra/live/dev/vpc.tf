module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = "${var.project}-${var.env}-vpc"
  cidr = var.vpc_cidr

  azs              = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_subnets   = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 64)]
  database_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 128)]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = var.use_nat_gateway
  single_nat_gateway = true

  public_subnet_tags   = { "tier" = "public" }
  private_subnet_tags  = { "tier" = "private" }
  database_subnet_tags = { "tier" = "db" }
  tags                 = { Project = var.project, Env = var.env }
}


data "aws_availability_zones" "available" {}
