locals {
  create_topic = var.notification != null

  # Destination OCIDs grouped by service, counting the topic this module
  # creates. OCI accepts at most one destination per service on an alarm.
  topic_destination_count  = length([for d in var.destinations : d if startswith(d, "ocid1.onstopic.")]) + (local.create_topic ? 1 : 0)
  stream_destination_count = length([for d in var.destinations : d if startswith(d, "ocid1.stream.")])

  subscriptions = local.create_topic ? var.notification.subscriptions : {}
}

resource "oci_ons_notification_topic" "this" {
  count = local.create_topic ? 1 : 0

  compartment_id = coalesce(var.notification.compartment_id, var.compartment_id)
  name           = var.notification.topic_name
  description    = var.notification.description

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_ons_subscription" "this" {
  for_each = local.subscriptions

  compartment_id = coalesce(var.notification.compartment_id, var.compartment_id)
  topic_id       = oci_ons_notification_topic.this[0].id
  protocol       = each.value.protocol
  endpoint       = each.value.endpoint

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_monitoring_alarm" "this" {
  compartment_id                   = var.compartment_id
  display_name                     = var.display_name
  metric_compartment_id            = coalesce(var.metric_compartment_id, var.compartment_id)
  metric_compartment_id_in_subtree = var.metric_compartment_id_in_subtree
  namespace                        = var.namespace
  query                            = var.query
  severity                         = var.severity
  destinations                     = concat(var.destinations, oci_ons_notification_topic.this[*].id)
  pending_duration                 = var.pending_duration
  repeat_notification_duration     = var.repeat_notification_duration
  is_enabled                       = var.is_enabled
  body                             = var.body

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  lifecycle {
    precondition {
      condition     = length(var.destinations) > 0 || local.create_topic
      error_message = "The alarm needs somewhere to send notifications: pass at least one OCID in destinations, or set notification so the module creates a topic. An alarm with no destinations notifies nobody."
    }

    precondition {
      condition     = local.topic_destination_count <= 1 && local.stream_destination_count <= 1
      error_message = "OCI allows one destination per service on an alarm: at most one Notifications topic and one stream. When notification is set, the module's topic is the Notifications destination, so destinations must not contain another ocid1.onstopic OCID."
    }
  }
}
