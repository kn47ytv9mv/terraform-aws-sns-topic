# terraform-aws-sns-topic

Terraform module for an SNS topic and its subscriptions — the fan-out
point that turns an event into a notification someone actually
receives.

## Cost

SNS bills per million requests, with email and most protocols free
beyond that. SMS is billed per message at rates that vary sharply by
destination country. Message archiving bills per gigabyte-month. See
AWS's [SNS pricing](https://aws.amazon.com/sns/pricing/) page for
current rates.

## Design

Subscriptions are bundled into this module rather than split out. They
are homogeneous protocol-and-endpoint pairs, nothing outside references
one specifically, and a topic with no subscribers delivers nothing — so
they are never useful apart. Same bundling reasoning as
[`terraform-aws-efs`](https://github.com/kn47ytv9mv/terraform-aws-efs)
and its mount targets. Each subscription is keyed by
`protocol:endpoint`, so adding one does not renumber and recreate the
others.

**An `email` subscription stays pending until the recipient clicks a
confirmation link AWS sends them.** Terraform reports the subscription
as created either way, so a topic can look fully wired up in state
while delivering nothing. Check the `subscription_arns` output — a
pending one reads `pending confirmation` instead of an ARN.

### Encryption and CloudWatch alarms

`kms_master_key_id` defaults to null — an unencrypted topic. This is
deliberate, and the reason matters:

**Do not set it to AWS's own `alias/aws/sns` key on a topic that
receives CloudWatch alarms.** That key's policy does not grant
CloudWatch `kms:Decrypt` and `kms:GenerateDataKey*`, and because AWS
manages the key the policy cannot be edited. Alarm notifications then
fail with *"CloudWatch Alarms does not have authorization to access the
SNS topic encryption key"* — a failure that shows up as silence,
exactly when you least want it. This is documented by AWS in
[Configure a CloudWatch alarm with an encrypted SNS topic](https://repost.aws/knowledge-center/cloudwatch-configure-alarm-sns).

To encrypt such a topic, use a customer managed key from
[`terraform-aws-kms-key`](https://github.com/kn47ytv9mv/terraform-aws-kms-key)
whose policy includes:

```json
{
  "Sid": "Allow_CloudWatch_for_CMK",
  "Effect": "Allow",
  "Principal": { "Service": ["cloudwatch.amazonaws.com"] },
  "Action": ["kms:Decrypt", "kms:GenerateDataKey*"],
  "Resource": "*"
}
```

A FIFO topic cannot deliver to email, SMS, HTTP, or Lambda — only to
SQS FIFO queues — which rules it out for alarm notifications entirely.

## Usage

```hcl
module "alerts" {
  source = "kn47ytv9mv/sns-topic/aws"

  name         = "alerts"
  display_name = "Production alerts"

  subscriptions = [
    { protocol = "email", endpoint = "ops@example.com" },
  ]
}
```

Or directly from this repository, fanning out to several destinations:

```hcl
module "alerts" {
  source = "github.com/kn47ytv9mv/terraform-aws-sns-topic"

  name = "alerts"

  subscriptions = [
    { protocol = "email", endpoint = "ops@example.com" },
    { protocol = "lambda", endpoint = module.pager.arn },
    { protocol = "sqs", endpoint = "arn:aws:sqs:us-east-1:123456789012:alert-archive", raw_message_delivery = true },
  ]
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | Name of the topic. A FIFO topic's `.fifo` suffix is appended automatically. If null, a unique name is generated. | `null` | no |
| display_name | Human-readable sender name for SMS and email notifications. | `null` | no |
| fifo_topic | Whether the topic preserves ordering and deduplicates. A FIFO topic cannot deliver to email, SMS, HTTP, or Lambda. | `false` | no |
| content_based_deduplication | Whether a FIFO topic derives deduplication IDs from message bodies. | `null` | no |
| fifo_throughput_scope | Throughput quota scope for a FIFO topic (`'Topic'` or `'MessageGroup'`). | `null` | no |
| kms_master_key_id | KMS key encrypting messages at rest. Never use `'alias/aws/sns'` on a topic receiving CloudWatch alarms — see Design. | `null` | no |
| policy | JSON access policy controlling publish and subscribe rights. | `null` | no |
| delivery_policy | JSON retry policy for HTTP and HTTPS endpoints. | `null` | no |
| signature_version | Signature version used to sign notifications: 1 or 2. | `null` | no |
| tracing_config | Whether X-Ray tracing passes through the topic (`'Active'` or `'PassThrough'`). | `null` | no |
| archive_policy | JSON policy retaining published messages for replay, for a FIFO topic. | `null` | no |
| subscriptions | Endpoints receiving this topic's messages. An `email` subscription stays pending until confirmed by the recipient. | `[]` | no |
| tags | A map of tags to assign to the topic. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| arn | The ARN of the topic. Feed this into `terraform-aws-cloudwatch-metric-alarm`'s `alarm_actions`. |
| id | The ID of the topic, which is its ARN. |
| name | The name of the topic, including the `.fifo` suffix when set. |
| subscription_arns | Map of `protocol:endpoint` to that subscription's ARN. A pending email subscription reads `pending confirmation`. |

## License

MIT — see [LICENSE.md](LICENSE.md).
