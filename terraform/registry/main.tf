resource "aws_ecr_repository" "main" {
  name                 = "${var.project}-${var.env}-${var.service}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}