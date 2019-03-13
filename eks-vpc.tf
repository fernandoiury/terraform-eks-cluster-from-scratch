provider "aws" {
  region = "${var.eks_region}"
}

module "eks-vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks-vpc"
  cidr = "${var.vpc_cidr}"

  azs             = "${var.eks_azs}"
  private_subnets = "${var.eks_private_cidrs}"
  public_subnets  = "${var.eks_public_cidrs}"

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = ""
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = ""
  }

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    Terraform                                   = "true"
    Environment                                 = "${var.environment_name}"
    Stack                                       = "${var.cluster_name}"
  }
}
