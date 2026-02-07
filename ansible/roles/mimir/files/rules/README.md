# Mimir Rules

This directory contains Prometheus-compatible alerting and recording rules that are deployed to Mimir via its ruler API.

## Directory Structure

```
rules/
├── alerts/          # Alerting rules (PromQL)
│   └── alerts_disk_space.yml
├── recording/       # Recording rules (pre-computed expressions)
│   └── recording_disk_space.yml
└── README.md
```

## File Format

Rule files **must** use the standard Prometheus rule group format with a top-level `groups:` key. This keeps them compatible with `mimirtool rules check` validation (run automatically via pre-commit).

At deploy time, the Ansible task strips the `groups:` wrapper and POSTs each group individually as a bare rule group to the Mimir ruler API.

### Alerting Rule Template

```yaml
---
# Brief description of what these alerts cover
# Validated by mimirtool in pre-commit

groups:
  - name: <descriptive_group_name>
    rules:
      - alert: <AlertName>
        expr: |
          <PromQL expression>
        for: 5m
        labels:
          severity: warning # or critical
        annotations:
          summary: "Short description on {{ $labels.instance }}"
          description: >-
            Longer explanation with {{ $labels.instance }}
            and {{ printf "%.1f" $value }}% detail.
```

### Recording Rule Template

```yaml
---
# Brief description of the recording rules
# Validated by mimirtool in pre-commit

groups:
  - name: <descriptive_group_name>
    interval: 1m # optional, defaults to global evaluation interval
    rules:
      - record: <namespace>:<metric_name>
        expr: |
          <PromQL expression>
```

## Naming Conventions

| Item                 | Convention              | Example                    |
| -------------------- | ----------------------- | -------------------------- |
| Alert rule file      | `alerts_<topic>.yml`    | `alerts_disk_space.yml`    |
| Recording rule file  | `recording_<topic>.yml` | `recording_disk_space.yml` |
| Alert group name     | `<topic>_alerts`        | `disk_space_alerts`        |
| Recording group name | `<topic>_recording`     | `disk_space_recording`     |
| Alert name           | `PascalCase`            | `DiskSpaceLowWarning`      |
| Recording metric     | `namespace:metric_name` | `node:disk_free_percent`   |

File names must be **unique across both `alerts/` and `recording/`** directories — the file basename (without `.yml`) is used as the ruler API namespace.

## Prometheus Template Expressions

Alerting rule annotations can use Go template expressions from the Prometheus alerting template language. These look like Jinja2 but are **not** processed by Ansible:

| Expression                   | Description                                |
| ---------------------------- | ------------------------------------------ |
| `{{ $labels.instance }}`     | Value of the `instance` label              |
| `{{ $labels.<name> }}`       | Value of any label                         |
| `{{ $value }}`               | The numeric value that triggered the alert |
| `{{ printf "%.1f" $value }}` | Formatted numeric value                    |

These expressions are safe to use in rule files. The deploy task parses the YAML via `from_yaml` (which treats `{{ }}` as literal strings) and re-serializes with `to_nice_yaml`, preserving them exactly.

## Validation

Rules are validated automatically on `git commit` via pre-commit hooks:

```
mimirtool rules check <file>
```

To validate manually:

```bash
mimirtool rules check ansible/roles/mimir/files/rules/alerts/alerts_disk_space.yml
```

## Deployment

Rules are pushed to the Mimir ruler API (`POST /prometheus/config/v1/rules/{namespace}`). They can be deployed in three ways:

```bash
# Deploy Mimir rules only
ansible-playbook ansible/playbooks/mimir-rules.yml

# Deploy all rules (Mimir + Loki)
ansible-playbook ansible/playbooks/deploy-rules.yml

# Full Mimir deploy (includes rules)
ansible-playbook ansible/playbooks/mimir.yml
```

## Adding a New Rule

1. Create the rule file in the appropriate subdirectory (`alerts/` or `recording/`)
2. Follow the naming conventions and templates above
3. Ensure the file has a unique basename across both directories
4. Commit — pre-commit will validate with `mimirtool`
5. Deploy via one of the playbook commands above
