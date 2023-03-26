resource "aws_ecr_repository" "main" {
  count                = length(["movie","music"])
  name                 = "${var.project}-${var.env}-${element(["movie","music"], count.index)}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}