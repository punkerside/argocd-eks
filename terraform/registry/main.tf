resource "aws_ecr_repository" "main" {
  count                = length(var.services)
  name                 = "${var.project}-${var.env}-${element(var.services, count.index)}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}