module "vpc" {
  source  = "punkerside/vpc/aws"
  version = "0.0.4"

  name = "${var.project}-${var.env}"
}