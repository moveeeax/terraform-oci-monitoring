output "id" {
  description = "OCID of the alarm."
  value       = oci_monitoring_alarm.this.id
}

output "display_name" {
  description = "Display name of the alarm."
  value       = oci_monitoring_alarm.this.display_name
}

output "is_enabled" {
  description = "Whether the alarm is enabled."
  value       = oci_monitoring_alarm.this.is_enabled
}

output "state" {
  description = "Lifecycle state of the alarm."
  value       = oci_monitoring_alarm.this.state
}

output "destinations" {
  description = "Destination OCIDs set on the alarm, including the topic created by the module."
  value       = oci_monitoring_alarm.this.destinations
}

output "topic_id" {
  description = "OCID of the Notifications topic created by the module, or null when notification is not set."
  value       = one(oci_ons_notification_topic.this[*].id)
}

output "subscription_ids" {
  description = "OCIDs of the topic subscriptions created by the module, keyed like notification.subscriptions."
  value       = { for k, s in oci_ons_subscription.this : k => s.id }
}
