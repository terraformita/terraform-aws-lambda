# terraform-aws-lambda-module
Opinionated Terraform Module that creates and manages AWS Lambda Function.

## Quick Start 

Create AWS Lambda resource by calling the `terraformita/lambda/aws` module:

```terraform
module "lambda_function" {
    source = "terraformita/lambda/aws"
    version = "Module Version"  # <--- make sure to specify correct version

    stage  = "Name of Target AWS Environment"
    tags = { 
        # map of tags 
    }

    function = {
        # Function Definition Here (see details below)
    }

    layer = {
        # Layer Definition Here (see details below)
        # IMPORTANT! Only one layer configuration per Lambda is currently supported.
    }

    logs = {
        # Logging Configuration Here (see details below)
    }
}
```

**NB!** Make sure to specify correct module version in the `version` parameter.

## Function Definition

Define your lambda function by the following parameters inside the `function` block:

```terraform
    function = {
        name = "Name of your Lambda Function"
        zip  = "Path to ZIP archive with Lambda Code"
        hash = "(Optional) Hashsum of the ZIP archive"

        handler = "Entry point of the lambda function. Example: lambda_handler.lambda_handler"
        runtime = "Lambda runtime. Defaults to 'nodejs14.x'."
        memsize = "(Optional) Memory size allocation for Lambda. Defaults to 128 Mb."
        timeout = "(Optional) Lambda timeout in seconds. Defaults to 900."

        role    = "(Optional) AWS IAM Role resource representing Lambda execution role."
        # If not provided, Lambda module will create role and attach all necessary
        # execution permissions.

        # (Optional) VPC configuration for Lambda function
        vpc_config = {
            subnet_ids      = [ "Array", "of", "Subnet IDs" ]
            security_groups = [ "Array", "of", "Security Groups" ] 
        }

        env                = { # map of environment variables }

        policies           = { 
            # (Optional) Map of inline IAM policies for the lambda function.
            #
            # Example (policy that allows S3 bucket notifications):
            #
            bucket-notifications = jsonencode({
                Version = "2012-10-17",
                Statement = [{
                    Effect = "Allow",
                    Action = [
                        "s3:GetBucketNotification"
                    ],
                    Resource = "arn:aws:s3:::bucket_name",
                }]
             })            
        }

        policy_attachments = [
            # (Optional) Array of ARNs of IAM policies to attach to the Lambda function.
            # 'AWSLambdaVPCAccessExecutionRole' is attached by default.
            #
            # Example:
            
            "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        ]

        permissions        = {
            # (Optional) Map of lambda invocation permissions 
            # *that do not require* "source_account" attribute.
            #
            # For S3 permissions, use "s3_permissions" block.
            #
            # Example: Allow Lambda invocation from CloudWatch Log Group

            cloudwatch = {
                action        = "lambda:InvokeFunction"
                principal     = "logs.us-east-1.amazonaws.com"
                source_arn    = "ARN of CloudWatch Group"
            }
        }

        s3_permissions = {
            # (Optional) Permissions for S3 buckets to invoke the given Lambda function
            # 
            # Example: Allow Lambda Invocation from an S3 bucket
            
            some_bucket = {
                principal  = "s3.amazonaws.com"
                source_arn = "arn:aws:s3:::bucket_name"
            }
        }

        track_versions     = true|false 
        # Indicates whether Lambda function versions should be created and published.
        # Versions are usually needed when using Lambda as target for App Load Balancer 
        # or a CloudFront distribution.
    }
```

## Layer Definition

Define Lambda Layer using the `layer` configuration block:

```terraform
  layer = {
    zip                 = "Path to ZIP file with the lambda layer"
    name                = "Name of Lambda Layer"
    compatible_runtimes = ["Array", "of", "Compatible", "Runtimes"]
  }
```

**NOTE.** So far the module supports only one lambda layer configuration.

## Logging Configuration

Define logging configuration using the **optional** `logs` configuration block:

```terraform
    logs = {
        log_retention_days = NUMBER_OF_DAYS_TO_RETAIN_LOGS
        kms_key_arn        = "(Optional) ARN of KMS Key for logs encryption"
    }
```
