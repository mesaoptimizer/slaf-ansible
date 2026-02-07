# Loki Rules

This directory contains LogQL alerting rules that are deployed to Loki via its ruler API.

## Directory Structure

```
rules/
├── alerts/          # Alerting rules (LogQL)
│   └── ssh_root.yml
└── README.md
```

## File Format

Rule files **must** use the standard Prometheus rule group format with a top-level `groups:` key. This keeps them compatible with `lokitool rules check` validation (run automatically via pre-commit).

At deploy time, the Ansible task strips the `groups:` wrapper and POSTs each group individually as a bare rule group to the Loki ruler API.

### Alerting Rule Template

```yaml
---
# Brief description of what these alerts cover
# Validated by lokitool in pre-commit

groups:
  - name: <descriptive_group_name>
    rules:
      - alert: <AlertName>
        expr: |
          <LogQL expression>
        for: 0s
        labels:
          severity: warning # or critical
        annotations:
          summary: "Short description on {{ $labels.host }}"
          description: >-
            Longer explanation with {{ $labels.host }}.
```

## Naming Conventions

| Item             | Convention       | Example        |
| ---------------- | ---------------- | -------------- |
| Alert rule file  | `<topic>.yml`    | `ssh_root.yml` |
| Alert group name | `<topic>_alerts` | `ssh_alerts`   |
| Alert name       | `PascalCase`     | `RootSSHLogin` |

File names must be unique — the file basename (without `.yml`) is used as the ruler API namespace.

## Prometheus Template Expressions

Alert annotations can use Go template expressions. These look like Jinja2 but are **not** processed by Ansible:

| Expression             | Description                                |
| ---------------------- | ------------------------------------------ |
| `{{ $labels.host }}`   | Value of the `host` label                  |
| `{{ $labels.<name> }}` | Value of any label                         |
| `{{ $value }}`         | The numeric value that triggered the alert |

## Validation

Rules are validated automatically on `git commit` via pre-commit hooks:

```
lokitool rules check <file>
```

To validate manually:

```bash
lokitool rules check ansible/roles/loki/files/rules/alerts/ssh_root.yml
```

## Deployment

Rules are pushed to the Loki ruler API (`POST /loki/api/v1/rules/{namespace}`). They can be deployed in three ways:

```bash
# Deploy Loki rules only
ansible-playbook ansible/playbooks/loki-rules.yml

# Deploy all rules (Mimir + Loki)
ansible-playbook ansible/playbooks/deploy-rules.yml

# Full Loki deploy (includes rules)
ansible-playbook ansible/playbooks/loki.yml
```

## Adding a New Rule

1. Create the rule file in `alerts/`
2. Follow the naming conventions and template above
3. Ensure the file has a unique basename
4. Commit — pre-commit will validate with `lokitool`
5. Deploy via one of the playbook commands above
