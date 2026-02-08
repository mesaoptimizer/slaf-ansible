# Alloy Role

Deploys [Grafana Alloy](https://grafana.com/docs/alloy/) for metrics collection (to Mimir) and security-focused log collection (to Loki) across both **Debian/Ubuntu** (systemd) and **Alpine** (OpenRC) hosts.

## What Logs Are Collected

Log collection is enabled by default (`alloy_log_collection_enabled: true`) and targets **security-critical, low-volume** events only. Verbose application logs are intentionally excluded.

### Collected by Default

| Category                                        | Systemd (Debian)                                     | OpenRC (Alpine)                                       | Job Label |
| ----------------------------------------------- | ---------------------------------------------------- | ----------------------------------------------------- | --------- |
| SSH authentication (accept, reject, key events) | `ssh.service` journal                                | `sshd` in `/var/log/messages`                         | `ssh`     |
| sudo / su commands                              | `_COMM=sudo` journal match                           | `sudo`, `su` in `/var/log/messages`                   | `sudo`    |
| Kernel errors (panics, oops, hardware failures) | Journal `PRIORITY=0-3`                               | `kernel` in `/var/log/messages`                       | `system`  |
| Service crashes and fatal errors                | Journal `PRIORITY=0-3` (includes exit-code-non-zero) | `rc-service`, `openrc`, `init` in `/var/log/messages` | `system`  |
| Cron execution                                  | `cron.service` journal (via `alloy_journal_units`)   | `CRON` in `/var/log/messages`                         | `system`  |

### NOT Collected

- Application-level stdout/stderr (deploy custom pipelines via `alloy_extra_config_blocks`)
- Debug, info, and notice-level journal entries (priority 4-7)
- Docker / container runtime logs
- Kubernetes pod logs (use a dedicated k8s log pipeline)
- Mail, CUPS, desktop service logs
- Alloy's own logs (avoids feedback loops)

## Label Schema

All log streams use a consistent, low-cardinality label set:

| Label      | Source          | Values                                   | Description                                |
| ---------- | --------------- | ---------------------------------------- | ------------------------------------------ |
| `instance` | External label  | Hostname (`{{ inventory_hostname }}`)    | Which host emitted the log                 |
| `env`      | External label  | `production` (default)                   | Environment tag                            |
| `job`      | Set by pipeline | `ssh`, `sudo`, `system`, `proxmox`, etc. | The service category (bounded)             |
| `unit`     | Systemd only    | e.g. `ssh.service`, `cron.service`       | Systemd unit name                          |
| `program`  | Alpine only     | e.g. `sshd`, `sudo`, `kernel`            | Syslog program name (bounded by allowlist) |
| `level`    | Both            | `error`, `warn`, `info`                  | Log severity                               |

### Cardinality Guidelines

- **Target:** < 10 indexed labels per stream, < 200 unique stream combinations per host.
- **Labels must be bounded.** Never derive labels from unbounded values like IP addresses, usernames, request IDs, or file paths.
- **Free-text fields stay in the log line.** Query them with `|=` (exact match) or `|~` (regex) filters in LogQL — for example: `{job="ssh"} |~ "Accepted .+ for root"`.

## How to Expand Log Collection

### Add a systemd unit (Debian/Ubuntu)

Add the unit name to `alloy_journal_units` in `group_vars` or `host_vars`:

```yaml
alloy_journal_units:
  - cron.service
  - nginx.service # Add this
  - postgresql.service # And this
```

These are collected with `job="system"` and the `unit` label set to the unit name.

### Add a syslog program (Alpine/OpenRC)

Extend `alloy_syslog_match_regex` in `group_vars` or `host_vars`:

```yaml
# Default: "(sshd|sudo|su|CRON|kernel|rc-service|openrc|init)"
alloy_syslog_match_regex: "(sshd|sudo|su|CRON|kernel|rc-service|openrc|init|nginx|postgres)"
```

Only lines from matching programs are ingested. The `program` label is automatically set.

### Add a fully custom pipeline

Use `alloy_extra_config_blocks` for pipelines that don't fit the base pattern. The shared `loki.write "default"` endpoint is available for forwarding:

```yaml
alloy_extra_config_blocks:
  - |
    // Custom application log collection
    loki.source.file "myapp" {
      targets = [
        {__path__ = "/var/log/myapp/*.log", job = "myapp"},
      ]
      forward_to = [loki.write.default.receiver]
    }
```

> **Important:** When adding labels in custom pipelines, ensure they are bounded. A label like `request_id` or `user_ip` will cause cardinality explosion and degrade Loki performance.

## Role Variables

| Variable                       | Default                                                      | Description                                             |
| ------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------- |
| `alloy_mimir_endpoint`         | `http://mimir.home.arpa:9009`                                | Mimir remote write URL                                  |
| `alloy_loki_endpoint`          | `http://loki.home.arpa:3100`                                 | Loki push API URL                                       |
| `alloy_log_collection_enabled` | `true`                                                       | Enable/disable all log collection                       |
| `alloy_journal_units`          | `["cron.service"]`                                           | Extra systemd units to collect (SSH is always included) |
| `alloy_syslog_match_regex`     | `"(sshd\|sudo\|su\|CRON\|kernel\|rc-service\|openrc\|init)"` | Alpine syslog program allowlist                         |
| `alloy_scrape_interval`        | `60s`                                                        | Prometheus metrics scrape interval                      |
| `alloy_external_labels`        | `{env: "production"}`                                        | Labels applied to all metrics and logs                  |
| `alloy_extra_config_blocks`    | `[]`                                                         | Additional Alloy River config blocks                    |
| `alloy_http_port`              | `12345`                                                      | Alloy HTTP listen port                                  |
| `alloy_user` / `alloy_group`   | `alloy` / `alloy`                                            | Service user and group                                  |

## OS Support

| OS Family       | Init System | Log Source                                | Journal Access                                                            |
| --------------- | ----------- | ----------------------------------------- | ------------------------------------------------------------------------- |
| Debian / Ubuntu | systemd     | `loki.source.journal`                     | User added to `systemd-journal` group; `SupplementaryGroups` in unit file |
| Alpine          | OpenRC      | `loki.source.file` on `/var/log/messages` | User added to `adm` group for `/var/log/*` access                         |

## Writing Alert Rules

With the unified label schema, alert rules work across both OS families:

```yaml
# Works for all hosts regardless of init system
- alert: RootSSHLogin
  expr: count_over_time({job="ssh"} |~ "Accepted .+ for root" [5m]) > 0
```

For OS-specific queries:

- Systemd hosts: `{job="ssh", unit="ssh.service"}`
- Alpine hosts: `{job="ssh", program="sshd"}`
