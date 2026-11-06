# Requires Terraform >= 1.7 (or OpenTofu >= 1.7) for `mock_provider`.
# The module's own required_version stays at >= 1.5 — this is a test-only requirement.

mock_provider "oci" {}

variables {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaacompartment"
  display_name   = "test-high-cpu"
  namespace      = "oci_computeagent"
  query          = "CpuUtilization[1m].mean() > 80"
  destinations   = ["ocid1.onstopic.oc1..aaaaaaaatopic"]
}

run "alarm_is_enabled_by_default" {
  assert {
    condition     = oci_monitoring_alarm.this.is_enabled == true
    error_message = "An alarm created with module defaults must be enabled, otherwise it never evaluates."
  }
}

run "destinations_reach_the_alarm" {
  assert {
    condition     = length(oci_monitoring_alarm.this.destinations) > 0
    error_message = "The alarm must carry at least one destination, otherwise it fires into the void."
  }

  assert {
    condition     = contains(oci_monitoring_alarm.this.destinations, "ocid1.onstopic.oc1..aaaaaaaatopic")
    error_message = "var.destinations must be passed through to the alarm unchanged."
  }
}

run "defaults_are_sane" {
  assert {
    condition     = oci_monitoring_alarm.this.metric_compartment_id == var.compartment_id
    error_message = "metric_compartment_id must fall back to compartment_id when unset."
  }

  assert {
    condition     = oci_monitoring_alarm.this.metric_compartment_id_in_subtree == false
    error_message = "metric_compartment_id_in_subtree must default to false, matching the OCI API default."
  }

  assert {
    condition     = oci_monitoring_alarm.this.pending_duration == "PT5M"
    error_message = "pending_duration must default to PT5M."
  }

  assert {
    condition     = oci_monitoring_alarm.this.severity == "WARNING"
    error_message = "severity must default to WARNING."
  }
}

run "optional_notification_settings_pass_through" {
  variables {
    metric_compartment_id            = "ocid1.compartment.oc1..aaaaaaaaparent"
    metric_compartment_id_in_subtree = true
    repeat_notification_duration     = "PT30M"
    severity                         = "CRITICAL"
    pending_duration                 = "PT1H"
  }

  assert {
    condition     = oci_monitoring_alarm.this.metric_compartment_id == "ocid1.compartment.oc1..aaaaaaaaparent"
    error_message = "An explicit metric_compartment_id must win over compartment_id."
  }

  assert {
    condition     = oci_monitoring_alarm.this.metric_compartment_id_in_subtree == true
    error_message = "metric_compartment_id_in_subtree must be forwarded to the alarm."
  }

  assert {
    condition     = oci_monitoring_alarm.this.repeat_notification_duration == "PT30M"
    error_message = "repeat_notification_duration must be forwarded to the alarm."
  }

  assert {
    condition     = oci_monitoring_alarm.this.pending_duration == "PT1H"
    error_message = "PT1H is the documented maximum pending_duration and must be accepted."
  }
}

# With no notification topic either, the alarm would notify nobody; the
# precondition on the alarm catches it (destinations may be empty only when the
# module creates the topic).
run "rejects_empty_destinations" {
  command = plan

  variables {
    destinations = []
  }

  expect_failures = [oci_monitoring_alarm.this]
}

run "rejects_non_ocid_destination" {
  command = plan

  variables {
    destinations = ["ocid1.onstopic.oc1..aaaaaaaatopic", ""]
  }

  expect_failures = [var.destinations]
}

run "rejects_invalid_severity" {
  command = plan

  variables {
    severity = "SEV1"
  }

  expect_failures = [var.severity]
}

run "rejects_unitless_pending_duration" {
  command = plan

  variables {
    pending_duration = "5m"
  }

  expect_failures = [var.pending_duration]
}

run "rejects_out_of_range_pending_duration" {
  command = plan

  variables {
    pending_duration = "PT90M"
  }

  expect_failures = [var.pending_duration]
}

run "rejects_invalid_repeat_notification_duration" {
  command = plan

  variables {
    repeat_notification_duration = "30 minutes"
  }

  expect_failures = [var.repeat_notification_duration]
}

run "no_topic_by_default" {
  command = plan

  assert {
    condition     = length(oci_ons_notification_topic.this) == 0 && length(oci_ons_subscription.this) == 0
    error_message = "No topic or subscription may be created unless notification is set."
  }

  assert {
    condition     = output.topic_id == null
    error_message = "topic_id must be null when the module creates no topic."
  }

  assert {
    condition     = oci_monitoring_alarm.this.destinations == tolist(["ocid1.onstopic.oc1..aaaaaaaatopic"])
    error_message = "Without notification, the alarm destinations must be exactly var.destinations."
  }
}

run "creates_topic_and_subscriptions" {
  command = apply

  variables {
    destinations = []
    notification = {
      topic_name  = "prod-alerts"
      description = "Production alarms"
      subscriptions = {
        oncall = { protocol = "EMAIL", endpoint = "oncall@example.com" }
        slack  = { protocol = "SLACK", endpoint = "https://hooks.slack.com/services/T000/B000/XXXX" }
        pager  = { protocol = "PAGERDUTY", endpoint = "https://events.pagerduty.com/integration/abc123/enqueue" }
      }
    }
    freeform_tags = { Environment = "test" }
  }

  assert {
    condition     = oci_ons_notification_topic.this[0].name == "prod-alerts" && oci_ons_notification_topic.this[0].compartment_id == var.compartment_id
    error_message = "The topic must be created with topic_name in the alarm's compartment."
  }

  assert {
    condition     = oci_ons_notification_topic.this[0].freeform_tags["Environment"] == "test"
    error_message = "freeform_tags must be applied to the topic."
  }

  assert {
    condition     = length(oci_ons_subscription.this) == 3
    error_message = "One subscription per notification.subscriptions entry must be created."
  }

  assert {
    condition     = oci_ons_subscription.this["oncall"].protocol == "EMAIL" && oci_ons_subscription.this["oncall"].endpoint == "oncall@example.com"
    error_message = "Subscription protocol and endpoint must be passed through."
  }

  assert {
    condition     = alltrue([for s in oci_ons_subscription.this : s.topic_id == oci_ons_notification_topic.this[0].id])
    error_message = "Every subscription must attach to the created topic."
  }

  assert {
    condition     = oci_monitoring_alarm.this.destinations == tolist([oci_ons_notification_topic.this[0].id])
    error_message = "The created topic must be the alarm's destination."
  }

  assert {
    condition     = output.topic_id == oci_ons_notification_topic.this[0].id && length(output.subscription_ids) == 3
    error_message = "topic_id and subscription_ids outputs must expose the created resources."
  }
}

run "topic_is_appended_to_a_stream_destination" {
  command = apply

  variables {
    destinations = ["ocid1.stream.oc1..aaaaaaaastream"]
    notification = {
      topic_name     = "prod-alerts"
      compartment_id = "ocid1.compartment.oc1..aaaaaaaaalerts"
    }
  }

  assert {
    condition     = oci_monitoring_alarm.this.destinations == tolist(["ocid1.stream.oc1..aaaaaaaastream", oci_ons_notification_topic.this[0].id])
    error_message = "The created topic must be appended after the caller's destinations."
  }

  assert {
    condition     = oci_ons_notification_topic.this[0].compartment_id == "ocid1.compartment.oc1..aaaaaaaaalerts"
    error_message = "notification.compartment_id must override the topic compartment."
  }

  assert {
    condition     = length(oci_ons_subscription.this) == 0
    error_message = "A topic without subscriptions must be allowed."
  }
}

run "rejects_second_topic_with_notification" {
  command = plan

  variables {
    notification = { topic_name = "prod-alerts" }
  }

  expect_failures = [oci_monitoring_alarm.this]
}

run "rejects_two_topic_destinations" {
  command = plan

  variables {
    destinations = ["ocid1.onstopic.oc1..aaaaaaaaone", "ocid1.onstopic.oc1..aaaaaaaatwo"]
  }

  expect_failures = [oci_monitoring_alarm.this]
}

run "rejects_unknown_subscription_protocol" {
  command = plan

  variables {
    destinations = []
    notification = {
      topic_name    = "prod-alerts"
      subscriptions = { teams = { protocol = "TEAMS", endpoint = "https://example.com/hook" } }
    }
  }

  expect_failures = [var.notification]
}

run "rejects_email_endpoint_that_is_not_an_address" {
  command = plan

  variables {
    destinations = []
    notification = {
      topic_name    = "prod-alerts"
      subscriptions = { oncall = { protocol = "EMAIL", endpoint = "oncall" } }
    }
  }

  expect_failures = [var.notification]
}

run "rejects_slack_endpoint_that_is_not_a_url" {
  command = plan

  variables {
    destinations = []
    notification = {
      topic_name    = "prod-alerts"
      subscriptions = { slack = { protocol = "SLACK", endpoint = "#alerts" } }
    }
  }

  expect_failures = [var.notification]
}

run "rejects_empty_topic_name" {
  command = plan

  variables {
    destinations = []
    notification = { topic_name = "" }
  }

  expect_failures = [var.notification]
}
