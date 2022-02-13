output "lambda_function" {
  value = {
    arn           = aws_lambda_function.lambda.arn
    version       = aws_lambda_function.lambda.version
    qualified_arn = aws_lambda_function.lambda.qualified_arn
    function_name = aws_lambda_function.lambda.function_name
    role_arn      = aws_iam_role.lambda.arn
  }
  description = "Parameters of created Lambda function: Function Name, ARN, Version, Qualified ARN, IAM role ARN"
}

output "log_group" {
  value = aws_cloudwatch_log_group.lambda.arn
  description = "ARN of the CloudWatch log group with Lambda execution logs"
}
