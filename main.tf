resource "oci_monitoring_alarm" "this" {
  compartment_id                   = var.compartment_id
  display_name                     = var.display_name
  metric_compartment_id            = coalesce(var.metric_compartment_id, var.compartment_id)
  metric_compartment_id_in_subtree = var.metric_compartment_id_in_subtree
  namespace                        = var.namespace
  query                            = var.query
  severity                         = var.severity
  destinations                     = var.destinations
  pending_duration                 = var.pending_duration
  repeat_notification_duration     = var.repeat_notification_duration
  is_enabled                       = var.is_enabled
  body                             = var.body

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
