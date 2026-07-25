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

run "rejects_empty_destinations" {
  command = plan

  variables {
    destinations = []
  }

  expect_failures = [var.destinations]
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
