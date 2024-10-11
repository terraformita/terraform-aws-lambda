output "lambda_function" {
  value = {
    arn           = var.function.ignore_code_changes ? aws_lambda_function.lambda_ignore_src_changes[0].arn : aws_lambda_function.lambda[0].arn
    version       = var.function.ignore_code_changes ? aws_lambda_function.lambda_ignore_src_changes[0].version : aws_lambda_function.lambda[0].version
    qualified_arn = var.function.ignore_code_changes ? aws_lambda_function.lambda_ignore_src_changes[0].qualified_arn : aws_lambda_function.lambda[0].qualified_arn
    function_name = var.function.ignore_code_changes ? aws_lambda_function.lambda_ignore_src_changes[0].function_name : aws_lambda_function.lambda[0].function_name
  }
  description = "Parameters of created Lambda function: Function Name, ARN, Version, Qualified ARN"
}
