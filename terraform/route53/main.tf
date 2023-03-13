data "aws_route53_zone" "main" {
  name         = "${var.domain}."
  private_zone = false
}

data "aws_lb" "main" {
  tags = {
    Name = "${var.project}-${var.env}"
  }
}

resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "awsday.${var.domain}"
  type    = "A"

  alias {
    name                   = data.aws_lb.main.dns_name
    zone_id                = data.aws_lb.main.zone_id
    evaluate_target_health = false
  }
}