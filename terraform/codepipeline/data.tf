data "aws_secretsmanager_secret" "main" {
  name = "github-token"
}

data "aws_secretsmanager_secret_version" "main" {
  secret_id = data.aws_secretsmanager_secret.main.id
}