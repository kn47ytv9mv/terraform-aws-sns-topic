locals {
  base_name = coalesce(var.name, random_uuid.resource.id)
  name      = var.fifo_topic && !endswith(local.base_name, ".fifo") ? "${local.base_name}.fifo" : local.base_name
}

resource "random_uuid" "resource" {}

resource "aws_sns_topic" "resource" {
  name         = local.name
  display_name = var.display_name

  fifo_topic                  = var.fifo_topic
  content_based_deduplication = var.content_based_deduplication
  fifo_throughput_scope       = var.fifo_throughput_scope
  archive_policy              = var.archive_policy

  kms_master_key_id = var.kms_master_key_id
  policy            = var.policy
  delivery_policy   = var.delivery_policy
  signature_version = var.signature_version
  tracing_config    = var.tracing_config

  tags = var.tags
}

resource "aws_sns_topic_subscription" "resource" {
  for_each = { for s in var.subscriptions : "${s.protocol}:${s.endpoint}" => s }

  topic_arn = aws_sns_topic.resource.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  raw_message_delivery  = each.value.raw_message_delivery
  filter_policy         = each.value.filter_policy
  filter_policy_scope   = each.value.filter_policy_scope
  delivery_policy       = each.value.delivery_policy
  redrive_policy        = each.value.redrive_policy
  subscription_role_arn = each.value.subscription_role_arn
}

output "arn" {
  description = "The ARN of the topic. Feed this into terraform-aws-cloudwatch-metric-alarm's alarm_actions."
  value       = aws_sns_topic.resource.arn
}

output "id" {
  description = "The ID of the topic, which is its ARN."
  value       = aws_sns_topic.resource.id
}

output "name" {
  description = "The name of the topic, including the '.fifo' suffix when fifo_topic is set."
  value       = aws_sns_topic.resource.name
}

output "subscription_arns" {
  description = "Map of 'protocol:endpoint' to that subscription's ARN. An email subscription's ARN stays 'pending confirmation' until the recipient confirms."
  value       = { for k, s in aws_sns_topic_subscription.resource : k => s.arn }
}
