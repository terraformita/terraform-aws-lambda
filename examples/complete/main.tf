provider "aws" {
  region = local.region
}

resource "random_pet" "stage_name" {}
resource "random_pet" "function_name" {}

# Uncomment the block below to create test KMS Key.
# WARNING! After destroying the example resources, it will still take 7 days to actually delete the KMS Key.
#
# resource "aws_kms_key" "test" {
#   description             = "Test KMS Key"
#   deletion_window_in_days = 7
# }

locals {
  region = "us-east-1"

  full_name = "${random_pet.stage_name.id}-${random_pet.function_name.id}"
  zip_path  = "${path.module}/lambda/lambda_handler.zip"
}

data "archive_file" "lambda" {
  type = "zip"

  source_dir  = "${path.module}/lambda/code"
  output_path = local.zip_path
}

module "lambda" {
  source = "../../"

  # General variables definition
  stage = random_pet.stage_name.id
  tags = {
    Name = local.full_name
  }

  # Function definition
  function = {
    name        = random_pet.function_name.id
    description = "Example Hello World Lambda Function"

    zip           = local.zip_path
    handler       = "lambda_handler.lambda_handler"
    runtime       = "python3.8"
    architectures = ["arm64"]
    memsize       = 128

    env = {
      STAGE_NAME    = random_pet.stage_name.id
      FUNCTION_NAME = random_pet.function_name.id
      REGION        = local.region
    }

    policies = {
      "test" = jsonencode({
        Version = "2012-10-17",
        Statement = [{
          Effect   = "Allow",
          Action   = "ce:*",
          Resource = "*"
        }]
      })

      "test2" = jsonencode({
        Version = "2012-10-17",
        Statement = [{
          Effect   = "Allow",
          Action   = "s3:*",
          Resource = "*"
        }]
      })
    }
    permissions        = {}
    policy_attachments = []
  }

  # Lambda Layer configuration
  layer = {
    zip                      = "${path.module}/lambda/sdk-layer.zip"
    compatible_runtimes      = ["python3.8"]
    compatible_architectures = ["x86_64", "arm64"]
  }

  # Lambda logs retention and encryption configuration
  logs = {
    log_retention_days = 14

    # Uncomment this block to test KMS key assignment on Lambda's CloudWatch Log Group
    #
    # kms_key_arn = aws_kms_key.test
  }

  depends_on = [
    data.archive_file.lambda,
    random_pet.stage_name,
    random_pet.function_name
  ]
}
