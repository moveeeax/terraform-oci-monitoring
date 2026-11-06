provider "oci" {}

module "alarm" {
  source = "../.."

  compartment_id = var.compartment_id
  display_name   = "example-high-cpu"
  namespace      = "oci_computeagent"
  query          = "CpuUtilization[1m].mean() > 80"
  severity       = "WARNING"
  body           = "CPU utilization has exceeded 80% for 5 minutes."

  # The module creates the topic and points the alarm at it. To use an
  # existing topic instead, drop this block and pass destinations = [topic_ocid].
  notification = {
    topic_name = "example-alerts"
    subscriptions = {
      oncall = {
        protocol = "EMAIL"
        endpoint = var.alert_email # the recipient must confirm the subscription
      }
    }
  }

  # Without this, OCI notifies once per state change only. Re-notify hourly for
  # as long as the alarm keeps firing.
  repeat_notification_duration = "PT1H"

  freeform_tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

variable "compartment_id" {
  description = "Compartment OCID to deploy the example alarm into."
  type        = string
}

variable "alert_email" {
  description = "Email address subscribed to the alarm's notification topic."
  type        = string
}

output "alarm_id" {
  value = module.alarm.id
}

output "topic_id" {
  value = module.alarm.topic_id
}
