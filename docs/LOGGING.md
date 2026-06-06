# Centralized Logging & Metrics with CloudWatch

How application and cluster logs/metrics are collected centrally, with no
per-node setup and no long-lived credentials.

```
  web/api pods ──stdout/stderr──┐
  kubelet / node                ├─▶ CloudWatch Agent + Fluent Bit (DaemonSet) ──▶ CloudWatch Logs
  control-plane components      ┘     (amazon-cloudwatch-observability addon)        + Container Insights metrics
                                                                                          │
                                                                            Dashboard "node3tier-overview" + alarms
```

## 1. What collects the logs

We use the managed **`amazon-cloudwatch-observability`** EKS add-on
(`modules/observability/main.tf`). Installing it deploys, in the
`amazon-cloudwatch` namespace:

- **Fluent Bit** as a DaemonSet — tails every container's stdout/stderr on each
  node and ships it to CloudWatch Logs.
- **CloudWatch Agent** — collects **Container Insights** metrics (node/pod CPU,
  memory, network, restarts).

Because it's a DaemonSet, it automatically covers **every node in all three
AZs** — no per-instance configuration.

## 2. How it authenticates (no keys)

The add-on's service account (`amazon-cloudwatch:cloudwatch-agent`) uses
**IRSA**: Terraform creates an IAM role
(`module.cw_observability_irsa`) attached to the AWS-managed
`CloudWatchAgentServerPolicy`, and trusts the cluster's OIDC provider. Pods get
short-lived STS credentials — nothing static is stored.

## 3. Where the logs land (log groups)

Fluent Bit creates these CloudWatch **log groups** (per cluster):

| Log group | Contents |
| --------- | -------- |
| `/aws/containerinsights/node3tier-eks/application` | **app container stdout/stderr** (web + api) |
| `/aws/containerinsights/node3tier-eks/dataplane` | kubelet, container runtime |
| `/aws/containerinsights/node3tier-eks/host` | node OS logs |
| `/aws/containerinsights/node3tier-eks/performance` | Container Insights performance events |

Application logs are centralized: every web/api pod just writes to stdout (12-
factor), and Fluent Bit does the rest. No app code changes, no sidecars.

## 4. Metrics, dashboard & alarms

The `observability` module also creates:

- A CloudWatch **dashboard** `node3tier-overview` with node CPU/memory, running
  pods in the `app` namespace, RDS CPU/connections, and ALB requests/5xx.
- An example **alarm** `node3tier-rds-cpu-high` (RDS CPU > 80% for 3 minutes).

Add SNS notification targets to the alarm for paging.

## 5. Viewing & querying

```bash
# Tail live application logs
aws logs tail /aws/containerinsights/node3tier-eks/application --follow --region us-east-2

# CloudWatch Logs Insights — error rate by pod (last hour)
aws logs start-query \
  --region us-east-2 \
  --log-group-name /aws/containerinsights/node3tier-eks/application \
  --start-time $(date -d '1 hour ago' +%s) --end-time $(date +%s) \
  --query-string 'fields @timestamp, kubernetes.pod_name, log
                  | filter log like /ERROR/
                  | stats count() by kubernetes.pod_name'
```

In the console: **CloudWatch → Container Insights** for the cluster map/metrics,
and **CloudWatch → Log groups** for searchable logs.

## 6. Retention & cost

By default the log groups have no expiry. For cost control, set a retention
policy (e.g. 30 days):

```bash
aws logs put-retention-policy --region us-east-2 \
  --log-group-name /aws/containerinsights/node3tier-eks/application \
  --retention-in-days 30
```

(You can also manage retention in Terraform with `aws_cloudwatch_log_group`
resources if you want it codified.)

## 7. Why this design

- **Centralized & node-agnostic:** one DaemonSet captures everything across all
  AZs; nodes can come and go (autoscaler) without losing logs.
- **Managed add-on:** AWS patches the agent; no custom Fluent Bit config to
  maintain.
- **Secure:** IRSA, least-privilege policy, no static keys.
- **Unified pane:** logs *and* metrics *and* alarms in one place (CloudWatch),
  correlated by cluster/namespace/pod.
