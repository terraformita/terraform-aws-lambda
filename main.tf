terraform {
  experiments = [module_variable_optional_attrs]
}

data "aws_caller_identity" "this" {}

locals {
  stage = var.stage
  tags  = var.tags

  lambda_defaults = {
    policy_attachments = []
    permissions        = {}
    policies           = {}
    env                = []
    s3_permissions     = {}

    runtime        = "nodejs14.x"
    memsize        = 128
    timeout        = 900
    track_versions = false
  }

  function_definition = {
    for k, v in var.function : k => v if v != null
  }

  lambda = merge(local.lambda_defaults, local.function_definition)

  env        = lookup(local.lambda, "env", [])
  role       = lookup(local.lambda, "role", aws_iam_role.lambda)
  vpc_config = var.function.vpc_config == null ? [] : [var.function.vpc_config]

  layer = var.layer
  logs  = var.logs

  default_policy = {
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
  retention_in_days = local.logs.log_retention_days
  kms_key_id        = local.logs.kms_key_arn

  tags = merge(
    local.tags,
    { Name = "${local.stage}-${local.lambda.name}" }
  )
}

resource "aws_lambda_function" "lambda" {
  function_name    = "${local.stage}-${local.lambda.name}"
  filename         = local.lambda.zip
  source_code_hash = try(local.lambda.hash, filebase64sha256(local.lambda.zip))
  layers           = local.layer == null ? [] : [aws_lambda_layer_version.layer[0].arn]
  handler          = local.lambda.handler
  role             = local.role.arn
  memory_size      = local.lambda.memsize
  runtime          = local.lambda.runtime
  timeout          = local.lambda.timeout
  description      = lookup(local.lambda, "description", "")
  publish          = lookup(local.lambda, "track_versions", false)

  dynamic "vpc_config" {
    for_each = local.vpc_config[*]
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_groups
    }
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
  compatible_runtimes = local.layer.compatible_runtimes
}

resource "aws_iam_role" "lambda" {
  name               = "${local.stage}-${local.lambda.name}-role"
  assume_role_policy = jsonencode(lookup(local.lambda, "policy", local.default_policy))
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "${local.stage}-${local.lambda.name}-cloudwatch"
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

resource "aws_iam_role_policy_attachment" "policy_attachments" {
  for_each   = toset(local.lambda.policy_attachments)
  role       = local.role.name
  policy_arn = each.key
}

resource "aws_lambda_permission" "permissions" {
  for_each      = lookup(local.lambda, "permissions", {})
  function_name = aws_lambda_function.lambda.function_name

  principal  = local.lambda.permissions[each.key]["principal"]
  action     = try(local.lambda.permissions[each.key]["action"], "lambda:InvokeFunction")
  source_arn = try(local.lambda.permissions[each.key]["source_arn"], aws_lambda_function.lambda.arn)
}

resource "aws_lambda_permission" "s3_permissions" {
  for_each       = local.lambda.s3_permissions
  function_name  = aws_lambda_function.lambda.function_name
  source_account = data.aws_caller_identity.this.account_id

  action     = try(each.value.action, "lambda:InvokeFunction")
  principal  = try(each.value.principal, "s3.amazonaws.com")
  source_arn = each.value.source_arn
}

resource "aws_iam_role_policy" "policies" {
  for_each = local.lambda.policies
  policy   = local.lambda.policies[each.key]
  role     = local.role.id
}
