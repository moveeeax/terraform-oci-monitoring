variable "compartment_id" {
  description = "OCID of the compartment in which to create the alarm."
  type        = string
}

variable "display_name" {
  description = "Human-readable name for the alarm."
  type        = string
}

variable "metric_compartment_id" {
  description = "OCID of the compartment whose metrics the alarm evaluates. Defaults to compartment_id."
  type        = string
  default     = null
}

variable "metric_compartment_id_in_subtree" {
  description = <<-EOT
    Whether to evaluate metrics from compartments nested under metric_compartment_id.
    Metrics are emitted into the compartment that owns the resource, so an alarm scoped
    to a parent compartment with this left false evaluates no data at all and never fires.
    Set to true when metric_compartment_id is a parent of the monitored resources.
  EOT
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Metric namespace the alarm queries (e.g. oci_computeagent)."
  type        = string
}

variable "query" {
  description = "Monitoring Query Language (MQL) expression the alarm evaluates."
  type        = string
}

variable "severity" {
  description = "Severity of the alarm."
  type        = string
  default     = "WARNING"

  validation {
    condition     = contains(["CRITICAL", "ERROR", "WARNING", "INFO"], var.severity)
    error_message = "severity must be CRITICAL, ERROR, WARNING, or INFO."
  }
}

variable "destinations" {
  description = <<-EOT
    List of destination OCIDs (ONS topics or streams) to notify when the alarm fires.
    OCI allows one destination per service. May be left empty when notification is
    set, since the topic the module creates is added to the alarm's destinations.
  EOT
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for d in var.destinations : can(regex("^ocid1\\.[a-z0-9]+\\.", d))])
    error_message = "Every destination must be an OCID (e.g. ocid1.onstopic.oc1..aaaa). Empty or malformed entries produce an alarm that notifies nobody."
  }
}

variable "notification" {
  description = <<-EOT
    Optional Notifications (ONS) topic to create for the alarm, with its
    subscriptions. The topic OCID is appended to destinations. topic_name must be
    unique in the tenancy. compartment_id defaults to the alarm's compartment.
    subscriptions is keyed by any stable name; protocol is one of CUSTOM_HTTPS,
    EMAIL, HTTPS, ORACLE_FUNCTIONS, PAGERDUTY, SLACK or SMS, and endpoint is the
    matching email address, URL, function OCID or phone number. EMAIL
    subscriptions stay pending until the recipient confirms them.
  EOT
  type = object({
    topic_name     = string
    description    = optional(string)
    compartment_id = optional(string)
    subscriptions = optional(map(object({
      protocol = string
      endpoint = string
    })), {})
  })
  default = null

  validation {
    condition     = var.notification == null || try(trimspace(var.notification.topic_name) != "", false)
    error_message = "notification.topic_name must be a non-empty string."
  }

  validation {
    condition     = var.notification == null || try(var.notification.compartment_id == null || can(regex("^ocid1\\.(compartment|tenancy)\\.", var.notification.compartment_id)), false)
    error_message = "notification.compartment_id must be a compartment OCID (or the tenancy OCID for the root compartment), or null."
  }

  validation {
    condition = var.notification == null || alltrue([
      for s in try(values(var.notification.subscriptions), []) :
      contains(["CUSTOM_HTTPS", "EMAIL", "HTTPS", "ORACLE_FUNCTIONS", "PAGERDUTY", "SLACK", "SMS"], s.protocol)
    ])
    error_message = "Each subscription protocol must be CUSTOM_HTTPS, EMAIL, HTTPS, ORACLE_FUNCTIONS, PAGERDUTY, SLACK or SMS."
  }

  validation {
    condition = var.notification == null || alltrue([
      for s in try(values(var.notification.subscriptions), []) :
      try(trimspace(s.endpoint) != "" && (
        s.protocol == "EMAIL" ? can(regex("^[^@\\s]+@[^@\\s]+$", s.endpoint)) :
        contains(["CUSTOM_HTTPS", "HTTPS", "PAGERDUTY", "SLACK"], s.protocol) ? can(regex("^https?://", s.endpoint)) && length(s.endpoint) <= 512 :
        s.protocol == "ORACLE_FUNCTIONS" ? startswith(s.endpoint, "ocid1.fnfunc.") :
        true
      ), false)
    ])
    error_message = "Each subscription endpoint must match its protocol: an email address for EMAIL, an http(s):// URL of at most 512 characters for CUSTOM_HTTPS, HTTPS, PAGERDUTY and SLACK, a function OCID (ocid1.fnfunc.) for ORACLE_FUNCTIONS, and a non-empty value for SMS."
  }
}

variable "pending_duration" {
  description = "How long the condition must hold before firing, as an ISO 8601 duration. OCI accepts PT1M through PT1H."
  type        = string
  default     = "PT5M"

  validation {
    condition     = can(regex("^PT([1-9]|[1-5][0-9])M$", var.pending_duration)) || var.pending_duration == "PT1H"
    error_message = "pending_duration must be an ISO 8601 duration between PT1M and PT1H (e.g. PT5M)."
  }
}

variable "repeat_notification_duration" {
  description = <<-EOT
    How often to re-send notifications while the alarm stays in the firing state, as an
    ISO 8601 duration (PT1M through P30D). Left null, OCI notifies once per state change
    only: a missed first notification means an actively firing alarm goes unnoticed.
    Set this for alarms that page a human.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.repeat_notification_duration == null || can(regex("^(PT[1-9][0-9]*[MH]|P[1-9][0-9]*D)$", tostring(var.repeat_notification_duration)))
    error_message = "repeat_notification_duration must be an ISO 8601 duration such as PT30M, PT4H, or P1D."
  }
}

variable "is_enabled" {
  description = "Whether the alarm is enabled."
  type        = bool
  default     = true
}

variable "body" {
  description = "Human-readable message included in alarm notifications."
  type        = string
  default     = null
}

variable "freeform_tags" {
  description = "Free-form tags applied to the alarm and, when notification is set, to the topic and its subscriptions."
  type        = map(string)
  default     = {}
}

variable "defined_tags" {
  description = "Defined tags applied to the alarm and, when notification is set, to the topic and its subscriptions, keyed as \"namespace.key\"."
  type        = map(string)
  default     = {}
}
