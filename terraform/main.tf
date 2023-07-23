module "vpc" {
  source  = "punkerside/vpc/aws"
  version = "0.0.5"

  name = var.name
}

module "eks" {
  source  = "punkerside/eks/aws"
  version = "0.0.4"

  name               = var.name
  instance_types     = [ "r6a.large" ]
  eks_version        = var.eks_version
  subnet_public_ids  = module.vpc.subnet_public_ids.*.id
  subnet_private_ids = module.vpc.subnet_private_ids.*.id
}

resource "aws_ecr_repository" "main" {
  count                = length(var.services)
  name                 = "${var.name}-${element(var.services, count.index)}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}