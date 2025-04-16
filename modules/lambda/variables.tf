variable "function" {
  type = object({
    name          = string
    description   = optional(string, "")
    zip           = string
    hash          = optional(string)
    handler       = string
    runtime       = string
    architectures = optional(list(string), ["x86_64"])
    memsize       = optional(string, "128")
    timeout       = optional(number, 900)

    ignore_code_changes  = optional(bool, false)
    reserved_concurrency = optional(number, -1)

    vpc_config = optional(list(object({
      subnet_ids      = list(string)
      security_groups = list(string)
    })), [])

    env                = optional(map(any))
    track_versions     = optional(bool)
    dead_letter_config = optional(string)
  })
  description = "(Required) All parameters needed to describe lambda function: name, zip archive with the code, VPC configuration, policies, invocation permissions, and such"
}

variable "role" {
  type = object({
    arn  = string
    id   = string
    name = string
  })
  description = "IAM role to be attached to the Lambda function"
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

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to be added to all resources created by this module"
}
