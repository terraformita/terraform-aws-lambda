output "lambda_function" {
  value = {
    arn           = module.lambda.lambda_function.arn
    version       = module.lambda.lambda_function.version
    qualified_arn = module.lambda.lambda_function.qualified_arn
    function_name = module.lambda.lambda_function.function_name
    role_arn      = aws_iam_role.lambda.arn
    role_id       = aws_iam_role.lambda.id
  }
  description = "Parameters of created Lambda function: Function Name, ARN, Version, Qualified ARN, IAM role ARN"
}

output "log_group" {
  value       = aws_cloudwatch_log_group.lambda.arn
  description = "ARN of the CloudWatch log group with Lambda execution logs"
}
