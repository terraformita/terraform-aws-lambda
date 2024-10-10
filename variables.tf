variable "stage" {
  type        = string
  description = "Name of the target environment (stage) where the Lambda function is deployed"
}

variable "function" {
  type = object({
    name          = string
    zip           = string
    hash          = optional(string)
    handler       = string
    runtime       = string
    architectures = optional(list(string), ["x86_64"])
    memsize       = optional(string, "128")
    timeout       = optional(string, "900")
    role          = optional(map(any))
    policy        = optional(string)

    ignore_code_changes = optional(bool, false)

    vpc_config = optional(object({
      subnet_ids      = list(string)
      security_groups = list(string)
    }))

    env                = optional(map(any))
    policies           = optional(map(any))
    policy_attachments = optional(list(string))
    permissions        = optional(map(any))
    s3_permissions     = optional(map(any))
    track_versions     = optional(bool)
  })
  description = "(Required) All parameters needed to describe lambda function: name, zip archive with the code, VPC configuration, policies, invocation permissions, and such"
}

variable "layer" {
  type = object({
    zip                      = string
    hash                     = optional(string)
    compatible_runtimes      = optional(list(string))
    compatible_architectures = optional(list(string), ["x86_64"])
  })

  default     = null
  description = "Lambda layer definition. Currently ONLY ONE layer definition per lambda function is supported"
}

variable "layers" {
  type = map(object({
    zip                      = string
    hash                     = optional(string)
    compatible_runtimes      = optional(list(string))
    compatible_architectures = optional(list(string), ["x86_64"])
  }))
  default     = {}
  description = "List of Lambda layers to be attached to the function"
}

variable "logs" {
  type = object({
    log_retention_days = number
    kms_key_arn        = optional(string)
  })

  default = {
    log_retention_days = 7
    kms_key_arn        = null
  }

  description = "(Optional) Lambda logging configuration for CloudWatch logs: log retention days (defaults to 7) and (optional) KMS key ARN for log encryption"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to be added to all resources created by this module"
}
