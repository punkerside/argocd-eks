resource "aws_s3_bucket" "main" {
  bucket        = "${var.project}-${var.env}"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = false
  }

  tags = {
    Name    = "${var.project}-${var.env}"
    Project = "${var.project}"
    Env     = "${var.env}"
  }
}

resource "aws_cloudwatch_log_group" "main" {
  name = "${var.project}-${var.env}"

  tags = {
    Name    = "${var.project}-${var.env}"
    Project = "${var.project}"
    Env     = "${var.env}"
  }
}

resource "aws_iam_role" "main" {
  name = "${var.project}-${var.env}-codepipeline"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["codebuild.amazonaws.com", "codepipeline.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "main" {
  name = "${var.project}-${var.env}-codepipeline"
  role = aws_iam_role.main.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.main.bucket}",
        "arn:aws:s3:::${aws_s3_bucket.main.bucket}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "sns:*",
        "ecr:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "main" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess"
  role       = aws_iam_role.main.name
}

resource "aws_codebuild_project" "main" {
  count         = length(var.services)
  name          = "${var.project}-${var.env}-${element(var.services, count.index)}"
  build_timeout = "15"
  service_role  = aws_iam_role.main.arn

  artifacts {
    type     = "S3"
    location = aws_s3_bucket.main.id
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "SERVICE"
      value = element(var.services, count.index)
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file("buildspec.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.main.name
    }
  }

  tags = {
    Name    = "${var.project}-${var.env}-${element(var.services, count.index)}"
    Service = element(var.services, count.index)
    Project = "${var.project}"
    Env     = "${var.env}"
  }
}

resource "aws_codepipeline" "main" {
  count    = length(var.services)
  name     = "${var.project}-${var.env}-${element(var.services, count.index)}"
  role_arn = aws_iam_role.main.arn

  artifact_store {
    location = aws_s3_bucket.main.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = "punkerside"
        Repo       = "awsday-demo"
        Branch     = "main"
        OAuthToken = jsondecode(data.aws_secretsmanager_secret_version.main.secret_string)["token"]
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ProjectName = "${var.project}-${var.env}-${element(var.services, count.index)}"
      }
    }
  }
}