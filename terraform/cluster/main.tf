module "vpc" {
  source  = "punkerside/vpc/aws"
  version = "0.0.4"

  name = "${var.project}-${var.env}"
}

module "eks" {
  source  = "punkerside/eks/aws"
  version = "0.0.3"

  name               = "${var.project}-${var.env}"
  instance_types     = [ "r6a.large" ]
  eks_version        = var.eks_version
  subnet_public_ids  = module.vpc.subnet_public_ids.*.id
  subnet_private_ids = module.vpc.subnet_private_ids.*.id
}