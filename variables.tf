variable "name" {
  default     = null
  description = "Name of the topic. A FIFO topic's name must end in '.fifo', which this module appends automatically when fifo_topic is set. If null, a unique name is generated."
}

variable "display_name" {
  default     = null
  description = "Human-readable name shown as the sender of SMS and email notifications. Without it, those arrive from the raw topic name."
}

variable "fifo_topic" {
  default     = false
  description = "Whether the topic preserves message ordering and deduplicates. A FIFO topic only delivers to SQS FIFO queues — it cannot deliver to email, SMS, HTTP, or Lambda, which rules it out for alarm notifications."
}

variable "content_based_deduplication" {
  default     = null
  description = "Whether a FIFO topic derives each message's deduplication ID from its body rather than requiring the publisher to supply one. Only meaningful when fifo_topic is true."
}

variable "fifo_throughput_scope" {
  default     = null
  description = "Throughput quota scope for a FIFO topic ('Topic' or 'MessageGroup'). 'MessageGroup' raises throughput by applying the quota per group. Only meaningful when fifo_topic is true."
}

variable "kms_master_key_id" {
  default     = null
  description = "KMS key encrypting messages at rest. Leave null for an unencrypted topic, or supply a customer managed key from terraform-aws-kms-key. Do NOT use AWS's own 'alias/aws/sns' key on a topic receiving CloudWatch alarms — CloudWatch cannot decrypt with it, the key policy cannot be edited, and alarm notifications silently fail to deliver. See this module's README for the key policy statement a customer managed key needs."
}

variable "policy" {
  default     = null
  description = "JSON access policy controlling who may publish to and subscribe to the topic. If null, AWS's own default policy applies, allowing only the owning account."
}

variable "delivery_policy" {
  default     = null
  description = "JSON policy controlling retry behavior for HTTP and HTTPS endpoints. If null, AWS's own default retry policy applies."
}

variable "signature_version" {
  default     = null
  description = "Signature version used to sign notifications: 1 (SHA1) or 2 (SHA256). If null, AWS's own default applies."
}

variable "tracing_config" {
  default     = null
  description = "Whether X-Ray tracing passes through the topic ('Active' or 'PassThrough'). If null, tracing is disabled."
}

variable "archive_policy" {
  default     = null
  description = "JSON policy retaining published messages for replay, for a FIFO topic. Billed per gigabyte-month stored. If null, no archive is kept."
}

variable "subscriptions" {
  default     = []
  description = "Endpoints receiving this topic's messages. protocol is 'email', 'email-json', 'sms', 'sqs', 'lambda', 'application', 'https', 'http', or 'firehose'; endpoint is the address, queue ARN, or function ARN. An 'email' subscription stays pending until the recipient clicks a confirmation link AWS sends — Terraform reports it as created regardless, so a topic can look wired up while delivering nothing."
  type = list(object({
    protocol              = string
    endpoint              = string
    raw_message_delivery  = optional(bool)
    filter_policy         = optional(string)
    filter_policy_scope   = optional(string)
    delivery_policy       = optional(string)
    redrive_policy        = optional(string)
    subscription_role_arn = optional(string)
  }))

  validation {
    condition = alltrue([
      for s in var.subscriptions :
      contains(["email", "email-json", "sms", "sqs", "lambda", "application", "https", "http", "firehose"], s.protocol)
    ])
    error_message = "A subscription's protocol must be one of 'email', 'email-json', 'sms', 'sqs', 'lambda', 'application', 'https', 'http', or 'firehose'."
  }

  validation {
    condition = alltrue([
      for s in var.subscriptions :
      s.protocol != "firehose" || s.subscription_role_arn != null
    ])
    error_message = "A 'firehose' subscription requires subscription_role_arn, the role permitting SNS to write to the delivery stream."
  }
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the topic."
}
