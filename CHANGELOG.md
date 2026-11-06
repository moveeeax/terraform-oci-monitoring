# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `notification` input: creates an ONS topic (`oci_ons_notification_topic`) and its
  subscriptions (`oci_ons_subscription`; EMAIL, SLACK, PAGERDUTY, HTTPS,
  CUSTOM_HTTPS, ORACLE_FUNCTIONS, SMS) and appends the topic OCID to the alarm's
  destinations. Protocols and endpoint shapes are validated at plan time.
- Outputs `topic_id`, `subscription_ids` and `destinations`.

### Changed

- `destinations` is now optional (default `[]`). The "at least one destination"
  rule moved from the variable to a precondition on the alarm, which also counts
  the topic created by `notification`.
- The plan fails when the alarm would get more than one Notifications topic or
  more than one stream, which OCI rejects at apply.
- `freeform_tags` and `defined_tags` also apply to the created topic and
  subscriptions.

[Unreleased]: https://github.com/moveeeax/terraform-oci-monitoring/compare/v1.1.0...HEAD
