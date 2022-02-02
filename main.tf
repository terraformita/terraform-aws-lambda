# lambda {
#   name = ...
#   zip = ...
#   hash = ...
#   handler = ...
#   runtime = ...
#   subnet-ids = [...]
#   sg-ids = [...]
#   env = { ... }
#   policies = {}
#   policy-attachments = []
#   permissions = {}
#   memsize = ...
#   timeout = ...
# }
# layer = {
#   zip = ...
#   hash = ...
#   name = ...
#   compatible-runtimes = [...]
# }
# logs = {
#   log-retention-days = ...
#   kms-key-arn = ...
# }

terraform {
  required_providers {
    aws = ">= 3.40.0"
  }
}

locals {
  name   = var.arg.name
  tags   = var.arg.tags
  region = var.arg.region

  lambda = lookup(var.arg, "lambda", {
    policy-attachments = []
    permissions        = {}
    policies           = {}
    env                = []
    s3-permission      = {}
  })

  env  = lookup(local.lambda, "env", [])
  role = lookup(local.lambda, "role", aws_iam_role.lambda)

  layer = lookup(var.arg, "layer", null)
  logs  = lookup(var.arg, "logs", {})

  default-policy = {
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRole",
      Principal = {
        Service = [
          "lambda.amazonaws.com",
        ]
      }
    }]
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = lookup(local.logs, "log-retention-days", 7)
  kms_key_id        = lookup(local.logs, "kms-key-arn", null)

  tags = merge(
    local.tags,
    { Name = "${local.name}-${local.lambda.name}" }
  )
}

resource "aws_lambda_function" "lambda" {
  function_name    = "${local.name}-${local.lambda.name}"
  filename         = local.lambda.zip
  source_code_hash = try(local.lambda.hash, filebase64sha256(local.lambda.zip))
  layers           = local.layer == null ? [] : [aws_lambda_layer_version.layer[0].arn]
  handler          = local.lambda.handler # "index.handler"
  role             = local.role.arn
  memory_size      = lookup(local.lambda, "memsize", "128")
  runtime          = lookup(local.lambda, "runtime", "nodejs14.x")
  timeout          = lookup(local.lambda, "timeout", 900)
  description      = lookup(local.lambda, "description", "")
  publish          = lookup(local.lambda, "track-versions", false)

  vpc_config {
    subnet_ids         = lookup(local.lambda, "subnet-ids", null)
    security_group_ids = lookup(local.lambda, "sg-ids", null)
  }
  dynamic "environment" {
    for_each = local.env[*]
    content {
      variables = environment.value
    }
  }
}

resource "aws_lambda_layer_version" "layer" {
  count               = local.layer == null ? 0 : 1
  filename            = local.layer.zip
  layer_name          = local.layer.name
  source_code_hash    = try(local.layer.hash, filebase64sha256(local.layer.zip))
  compatible_runtimes = local.layer.compatible-runtimes
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name}-${local.lambda.name}-role"
  assume_role_policy = jsonencode(lookup(local.lambda, "policy", local.default-policy))
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "${local.name}-${local.lambda.name}-cloudwatch"
  role = local.role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:PutLogEvents",
        "logs:CreateLogStream"
      ],
      Effect = "Allow",
      Resource = [
        "${aws_cloudwatch_log_group.lambda.arn}:*",
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "default" {
  role       = local.role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "policy-attachments" {
  for_each   = toset(lookup(local.lambda, "policy-attachments", []))
  role       = local.role.name
  policy_arn = each.key
}

data "aws_caller_identity" "this" {}

resource "aws_lambda_permission" "permissions" {
  for_each      = lookup(local.lambda, "permissions", {})
  function_name = aws_lambda_function.lambda.function_name

  principal  = local.lambda.permissions[each.key]["principal"]
  action     = try(local.lambda.permissions[each.key]["action"], "lambda:InvokeFunction")
  source_arn = try(local.lambda.permissions[each.key]["source-arn"], aws_lambda_function.lambda.arn)
}

resource "aws_lambda_permission" "s3-permission" {
  count          = can(local.lambda.s3-permission.source-arn) ? 1 : 0
  function_name  = aws_lambda_function.lambda.function_name
  source_account = data.aws_caller_identity.this.account_id

  action     = try(local.lambda.s3-permission.action, "lambda:InvokeFunction")
  principal  = try(local.lambda.s3-permission.principal, "s3.amazonaws.com")
  source_arn = local.lambda.s3-permission.source-arn
}

resource "aws_iam_role_policy" "policies" {
  for_each = lookup(local.lambda, "policies", {})
  policy   = local.lambda.policies[each.key]
  role     = local.role.id
}
