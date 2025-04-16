terraform {
  required_providers {
    aws = ">= 3.40.0"
  }
}

data "aws_caller_identity" "this" {}

locals {
  stage = var.stage
  tags = merge(
    var.tags,
    { Name = "${local.function_name}" }
  )

  function_name = "${local.stage}-${var.function.name}"

  function = {
    name        = local.function_name
    zip         = var.function.zip
    handler     = var.function.handler
    runtime     = var.function.runtime
    description = var.function.description
    publish     = var.function.track_versions

    memsize       = var.function.memsize
    timeout       = var.function.timeout
    env           = try(var.function.env, {})
    hash          = try(var.function.hash, null) == null ? filebase64sha256(var.function.zip) : var.function.hash
    architectures = var.function.architectures

    ignore_code_changes  = try(var.function.ignore_code_changes, false)
    reserved_concurrency = try(var.function.reserved_concurrency, -1)

    policy             = try(var.function.policy, null) == null ? jsonencode(local.policy_template) : jsonencode(var.function.policy)
    policies           = merge(try(var.function.policies, {}), {})
    policy_attachments = try(var.function.policy_attachments, null) == null ? [] : var.function.policy_attachments
    permissions        = merge(try(var.function.permissions, {}), {})
    s3_permissions     = merge(try(var.function.s3_permissions, {}), {})
    vpc_config         = try(var.function.vpc_config, null) == null ? [] : [var.function.vpc_config]
    dead_letter_config = try(var.function.dead_letter_config, null)
  }

  default_layer = {
    "${local.function_name}-default" = try(var.layer, null)
  }

  layers = {
    for k, v in merge(local.default_layer, var.layers) :
    k => v if v != null
  }

  layer = var.layer
  logs  = var.logs

  policy_template = {
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
  name              = "/aws/lambda/${module.lambda.lambda_function.function_name}"
  retention_in_days = local.logs.log_retention_days
  kms_key_id        = local.logs.kms_key_arn

  tags = local.tags
}

module "lambda" {
  source = "./modules/lambda"

  function = local.function
  layers   = local.layers
  role     = var.function.role == null ? aws_iam_role.lambda : var.function.role
  tags     = var.tags

  depends_on = [aws_iam_role.lambda]
}

resource "aws_iam_role" "lambda" {
  name               = "${local.function_name}-role"
  assume_role_policy = local.function.policy

  tags = local.tags
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "${local.function_name}-cloudwatch"
  role = try(var.function.role.id, aws_iam_role.lambda.id)

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
  role       = try(var.function.role.name, aws_iam_role.lambda.name)
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "policy_attachments" {
  for_each   = toset(local.function.policy_attachments)
  role       = try(var.function.role.name, aws_iam_role.lambda.name)
  policy_arn = each.key
}

resource "aws_lambda_permission" "permissions" {
  for_each      = local.function.permissions
  function_name = module.lambda.lambda_function.function_name

  principal  = local.function.permissions[each.key]["principal"]
  action     = try(local.function.permissions[each.key]["action"], "lambda:InvokeFunction")
  source_arn = try(local.function.permissions[each.key]["source_arn"], module.lambda.lambda_function.arn)

  depends_on = [module.lambda]
}

resource "aws_lambda_permission" "s3_permissions" {
  for_each       = local.function.s3_permissions
  function_name  = module.lambda.lambda_function.function_name
  source_account = data.aws_caller_identity.this.account_id

  action     = try(each.value.action, "lambda:InvokeFunction")
  principal  = try(each.value.principal, "s3.amazonaws.com")
  source_arn = each.value.source_arn

  depends_on = [module.lambda]
}

resource "aws_iam_policy" "policies" {
  for_each = local.function.policies
  name     = "${local.function_name}-${each.key}"
  path     = "/"
  policy   = local.function.policies[each.key]
  tags     = local.tags

  depends_on = [module.lambda]
}

resource "aws_iam_role_policy_attachment" "attachments" {
  for_each   = aws_iam_policy.policies
  role       = try(var.function.role.name, aws_iam_role.lambda.name)
  policy_arn = each.value.arn
}
