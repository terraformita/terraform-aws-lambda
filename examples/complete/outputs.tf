output "lambda" {
  value = module.lambda.lambda_function
}

output "log_group" {
  value = module.lambda.log_group
}
