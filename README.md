# terraform-oci-monitoring

Terraform module that manages an [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/)
Monitoring alarm. It evaluates a Monitoring Query Language (MQL) expression over a metric
namespace and notifies one or more destinations (typically Notifications topics) when the
condition holds for the pending duration.

## Usage

```hcl
module "alarm" {
  source = "github.com/moveeeax/terraform-oci-monitoring?ref=v1.0.0"

  compartment_id = var.compartment_id
  display_name   = "prod-high-cpu"
  namespace      = "oci_computeagent"
  query          = "CpuUtilization[1m].mean() > 80"
  severity       = "CRITICAL"
  destinations   = [var.topic_id]

  # OCI notifies once per state change unless you ask it to repeat.
  repeat_notification_duration = "PT1H"

  freeform_tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Alarms that quietly notify nobody

Three OCI defaults produce an alarm that applies cleanly and then does nothing useful.
The module guards the first and exposes the other two:

- **No destination.** `destinations` is validated to be non-empty and to contain only
  OCIDs. An alarm with an empty or malformed destination list evaluates its query,
  changes state, and notifies nobody.
- **Parent-compartment scope.** Metrics live in the compartment that owns the resource.
  Pointing `metric_compartment_id` at a parent compartment while
  `metric_compartment_id_in_subtree` is `false` (the OCI default) evaluates zero data
  points, so the alarm never fires. Set it to `true` for parent-scoped alarms.
- **One-shot notification.** With `repeat_notification_duration` unset (the OCI default)
  a firing alarm notifies exactly once. If that notification is missed the incident stays
  open and silent. Set it on anything that pages a human.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| oci       | >= 5.0   |

## Inputs

| Name                               | Description                                                                            | Type           | Default     | Required |
|------------------------------------|----------------------------------------------------------------------------------------|----------------|-------------|:--------:|
| `compartment_id`                   | OCID of the compartment in which to create the alarm.                                  | `string`       | n/a         |   yes    |
| `display_name`                     | Human-readable name for the alarm.                                                     | `string`       | n/a         |   yes    |
| `metric_compartment_id`            | Compartment whose metrics are evaluated. Defaults to `compartment_id`.                 | `string`       | `null`      |    no    |
| `metric_compartment_id_in_subtree` | Also evaluate metrics in compartments nested under `metric_compartment_id`.            | `bool`         | `false`     |    no    |
| `namespace`                        | Metric namespace the alarm queries.                                                    | `string`       | n/a         |   yes    |
| `query`                            | MQL expression the alarm evaluates.                                                    | `string`       | n/a         |   yes    |
| `severity`                         | Severity (`CRITICAL`, `ERROR`, `WARNING`, `INFO`).                                     | `string`       | `"WARNING"` |    no    |
| `destinations`                     | Destination OCIDs (ONS topics) to notify. Must be non-empty and OCID-shaped.            | `list(string)` | n/a         |   yes    |
| `pending_duration`                 | ISO 8601 duration the condition must hold before firing. `PT1M`–`PT1H`.                | `string`       | `"PT5M"`    |    no    |
| `repeat_notification_duration`     | ISO 8601 interval for re-notifying while firing (`PT1M`–`P30D`). Null = notify once.    | `string`       | `null`      |    no    |
| `is_enabled`                       | Whether the alarm is enabled.                                                          | `bool`         | `true`      |    no    |
| `body`                             | Human-readable message in alarm notifications.                                         | `string`       | `null`      |    no    |
| `freeform_tags`                    | Free-form tags applied to the alarm.                                                   | `map(string)`  | `{}`        |    no    |
| `defined_tags`                     | Defined tags applied to the alarm, keyed `namespace.key`.                              | `map(string)`  | `{}`        |    no    |

## Outputs

| Name           | Description                        |
|----------------|------------------------------------|
| `id`           | OCID of the alarm.                 |
| `display_name` | Display name of the alarm.         |
| `is_enabled`   | Whether the alarm is enabled.      |
| `state`        | Lifecycle state of the alarm.      |

## Testing

```sh
terraform init -backend=false
terraform test
```

The suite in [`tests/`](tests) uses `mock_provider`, so it needs no OCI credentials and
makes no API calls. It requires Terraform (or OpenTofu) >= 1.7; the module itself still
only requires >= 1.5.

## License

[MIT](LICENSE)
