resource "aws_lambda_function" "lambda" {
  count = var.function.ignore_code_changes ? 0 : 1

  function_name    = var.function.name
  filename         = var.function.zip
  source_code_hash = var.function.hash
  layers           = [for layer in aws_lambda_layer_version.layer : layer.arn]
  handler          = var.function.handler
  role             = var.role.arn
  memory_size      = var.function.memsize
  runtime          = var.function.runtime
  architectures    = var.function.architectures
  timeout          = var.function.timeout
  description      = try(var.function.description, "")
  publish          = var.function.track_versions

  reserved_concurrent_executions = var.function.reserved_concurrency

  dynamic "vpc_config" {
    for_each = var.function.vpc_config[*]
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_groups
    }
  }

  dynamic "environment" {
    for_each = var.function.env[*]
    content {
      variables = environment.value
    }
  }

  tags = var.tags
}

resource "aws_lambda_function" "lambda_ignore_src_changes" {
  count = var.function.ignore_code_changes ? 1 : 0

  function_name    = var.function.name
  filename         = var.function.zip
  source_code_hash = var.function.hash
  layers           = [for layer in aws_lambda_layer_version.layer : layer.arn]
  handler          = var.function.handler
  role             = var.role.arn
  memory_size      = var.function.memsize
  runtime          = var.function.runtime
  architectures    = var.function.architectures
  timeout          = var.function.timeout
  description      = try(var.function.description, "")
  publish          = var.function.track_versions

  reserved_concurrent_executions = var.function.reserved_concurrency

  dynamic "vpc_config" {
    for_each = var.function.vpc_config[*]
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_groups
    }
  }

  dynamic "environment" {
    for_each = var.function.env[*]
    content {
      variables = environment.value
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      source_code_hash
    ]
  }
}

resource "aws_lambda_layer_version" "layer" {
  for_each                 = var.layers
  filename                 = each.value.zip
  layer_name               = each.key
  source_code_hash         = try(each.value.hash, filebase64sha256(each.value.zip))
  compatible_runtimes      = each.value.compatible_runtimes
  compatible_architectures = each.value.compatible_architectures
}
