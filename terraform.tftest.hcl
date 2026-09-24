mock_provider "aws" {
  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:123456789012:mock-topic"
    }
  }
}

run "invalid_subscription_protocol_is_rejected" {
  command = plan

  variables {
    subscriptions = [
      { protocol = "carrier-pigeon", endpoint = "ops@example.com" },
    ]
  }

  expect_failures = [var.subscriptions]
}

run "firehose_subscription_requires_a_role" {
  command = plan

  variables {
    subscriptions = [
      { protocol = "firehose", endpoint = "arn:aws:firehose:us-east-1:123456789012:deliverystream/logs" },
    ]
  }

  expect_failures = [var.subscriptions]
}

run "name_defaults_to_random_uuid" {
  command = apply

  assert {
    condition     = aws_sns_topic.resource.name == random_uuid.resource.id
    error_message = "Leaving name unset should fall back to the generated random_uuid."
  }
}

run "fifo_topic_appends_the_required_suffix" {
  command = plan

  variables {
    name       = "orders"
    fifo_topic = true
  }

  assert {
    condition     = aws_sns_topic.resource.name == "orders.fifo"
    error_message = "A FIFO topic's name must end in '.fifo', which the module should append rather than making every caller type it."
  }
}

run "fifo_suffix_is_not_doubled" {
  command = plan

  variables {
    name       = "orders.fifo"
    fifo_topic = true
  }

  assert {
    condition     = aws_sns_topic.resource.name == "orders.fifo"
    error_message = "A name already ending in '.fifo' should not have the suffix appended twice."
  }
}

run "standard_topic_gets_no_suffix" {
  command = plan

  variables {
    name = "alerts"
  }

  assert {
    condition     = aws_sns_topic.resource.name == "alerts"
    error_message = "A standard topic's name should be left exactly as supplied."
  }
}

run "no_subscriptions_by_default" {
  command = plan

  assert {
    condition     = length(aws_sns_topic_subscription.resource) == 0
    error_message = "Leaving subscriptions unset should create no subscription resources."
  }
}

run "subscriptions_create_one_resource_each" {
  command = apply

  variables {
    name = "alerts"
    subscriptions = [
      { protocol = "email", endpoint = "ops@example.com" },
      { protocol = "email", endpoint = "oncall@example.com" },
      { protocol = "lambda", endpoint = "arn:aws:lambda:us-east-1:123456789012:function:pager" },
    ]
  }

  assert {
    condition     = length(aws_sns_topic_subscription.resource) == 3
    error_message = "Each subscriptions entry should create one subscription resource."
  }

  assert {
    condition     = aws_sns_topic_subscription.resource["email:ops@example.com"].protocol == "email"
    error_message = "A subscription should be keyed by its protocol and endpoint, so adding one does not renumber the others."
  }
}

run "no_encryption_by_default" {
  command = plan

  assert {
    condition     = aws_sns_topic.resource.kms_master_key_id == null
    error_message = "The topic should be unencrypted by default rather than defaulting to AWS's own SNS key, which silently breaks CloudWatch alarm delivery."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    name         = "alerts"
    display_name = "Production alerts"

    subscriptions = [
      { protocol = "email", endpoint = "ops@example.com" },
    ]
  }
}

run "readme_fan_out_example" {
  command = plan

  variables {
    name = "alerts"

    subscriptions = [
      { protocol = "email", endpoint = "ops@example.com" },
      { protocol = "lambda", endpoint = "arn:aws:lambda:us-east-1:123456789012:function:pager" },
      { protocol = "sqs", endpoint = "arn:aws:sqs:us-east-1:123456789012:alert-archive", raw_message_delivery = true },
    ]
  }
}
