# Technical Q&A — Short Answers

Assessment optional section. Time budget: 20–30 minutes total.

---

## Q1 — Kubernetes Networking

**Scenario:**
- `http://www.demo.domain.tv/` → **Failure**
- `http://backend.demo.domain.tv/api/v1/health` → **Failure**
- `http://backend-domdomain-demo.backend.svc.cluster.local:4000/api/v1/health` → **Success**
- `http://frontend-domdomain-demo.frontend.svc.cluster.local:3000/` → **Success**

**Constraint:** Not DNS-related.

**Answer:**

The pattern reveals a **network policy** issue, not a DNS problem.

The two failures share a common trait: they reach external-looking hostnames (`www.demo.domain.tv`, `backend.demo.domain.tv`) which resolve to ingress or external load balancer IPs. The two successes use fully-qualified in-cluster service addresses (`*.svc.cluster.local`) — meaning pod-to-pod traffic within the cluster works fine.

The most likely cause is that **NetworkPolicy objects** are blocking egress from `pod-A` to anything outside the cluster namespace boundary. Specifically:

1. Kubernetes NetworkPolicies default to **allow-all** when no policy exists, but default to **deny** on any traffic dimension that has at least one policy applied. If a NetworkPolicy targets `pod-A`'s namespace and defines `egress` rules, all egress not explicitly listed is dropped.

2. Traffic to `*.svc.cluster.local` succeeds because the policy likely permits intra-cluster service traffic (or the DNS + service endpoints are reachable within the allowed CIDR).

3. Traffic to external hostnames fails because it must leave the cluster via the CNI and NAT — either blocked by egress NetworkPolicy or by node-level `iptables` rules set by the CNI plugin.

**How to verify without touching DNS:**

```bash
# Check which NetworkPolicies apply to pod-A's namespace
kubectl get networkpolicy -n demo

# Check pod-A's egress rules specifically
kubectl describe networkpolicy -n demo

# Test direct TCP connectivity from pod-A to the external IP
kubectl exec -it pod-A -n demo -- nc -zv <external-ip> 80
```

**Fix:** Add an explicit egress rule in the NetworkPolicy to allow traffic to the external IPs or CIDR ranges used by the ingress/load balancer:

```yaml
egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
          - 10.0.0.0/8
          - 172.16.0.0/12
          - 192.168.0.0/16
    ports:
      - port: 80
      - port: 443
```

---

## Q2 — Overlapping Networks in Multi-VPC

**What are overlapping networks?**

Overlapping networks occur when two or more VPCs (or on-premise networks connected via VPN/Direct Connect) use the same or overlapping CIDR ranges — for example, both using `10.0.0.0/16`. When you attempt to connect them via VPC Peering, Transit Gateway, or VPN, routing becomes ambiguous: the router cannot determine which network a packet destined for `10.0.1.5` belongs to.

**Most cost-effective resolution path:**

The cheapest approach is **re-IP one of the VPCs** before adding more connections. This avoids the ongoing cost of NAT boxes or proxy solutions. The process:

1. **Identify the least-connected VPC** — the one with fewer resources, peering connections, and services to migrate
2. **Create a new VPC** with a non-overlapping CIDR (e.g. `10.1.0.0/16` instead of `10.0.0.0/16`)
3. **Migrate resources** gradually using DNS cutover — launch new resources in the new VPC, update DNS records, drain old VPC
4. **Delete the old VPC** once drained

**Alternatives when re-IP is not feasible:**

| Option | Cost | Trade-off |
|--------|------|-----------|
| **Re-IP one VPC** | Low — one-time migration cost | Disruption during migration |
| **AWS PrivateLink** | ~$7/month per endpoint | Only works for service-to-service, not full VPC routing |
| **NAT/proxy in a shared VPC** | Instance cost + complexity | Adds a single point of failure; not scalable |
| **Transit Gateway with CIDR NAT** | ~$36/month + data processing | Works without re-IP but ongoing cost; supported natively |

For a multi-VPC estate with >5 VPCs, **AWS Transit Gateway with VPC CIDR translation** (NAT on TGW) is the most operationally scalable option even though it costs more. For small setups (2–3 VPCs), re-IP is almost always the right answer.

---

## Q3 — Rollback Strategy for Production Kubernetes

**Goal:** balance speed, reliability, and data consistency.

**Recommended strategy: layered rollback with automated first response**

### Layer 1 — Deployment-level rollback (fastest, < 2 minutes)

Kubernetes rolling updates preserve the previous ReplicaSet. A single command reverts the workload:

```bash
kubectl rollout undo deployment/my-app -n production
# Reverts to the previous ReplicaSet immediately
```

Use this for: bad code, performance regression, configuration error. No data concerns because the application is stateless or the data layer has not changed.

### Layer 2 — Helm revision rollback (when using Helm)

```bash
helm rollback my-app 5 -n production
# Reverts to revision 5 including ConfigMaps, Services, and any Helm-managed resources
```

### Layer 3 — Database migration awareness

Speed and data consistency are in direct tension here. The safest pattern is **expand-contract migrations**:

1. Migrations are **additive only** (never rename or drop columns in one release)
2. The new version runs with both old and new schema simultaneously
3. Once all instances are updated, a follow-up release removes the old column

This allows rollback without data loss: the old application version can still read from the new schema.

**If a destructive migration already ran:**
- Restore from the most recent RDS snapshot (automated backup)
- Accept data loss up to the snapshot timestamp (RPO depends on backup frequency)
- This is why point-in-time recovery (PITR) is critical — minimises the data loss window

### Guardrails

- **PodDisruptionBudgets:** ensure at least 1 replica is always available during rollout/rollback
- **Readiness probes:** prevent routing to pods that are not yet healthy
- **Deployment circuit breaker** (in ArgoCD or Flux): automatically trigger rollback if error rate exceeds threshold after deploy
- **`maxUnavailable: 0`** in rolling update strategy for zero-downtime rollback

---

## Q4 — Logging Architecture: Why Not Log Directly from Pods?

**Why sending logs directly from pods to a log server is a bad idea:**

1. **Tight coupling:** if the log server is slow or down, every pod blocks on log writes, introducing latency and potentially crashing the application
2. **No buffering:** a sudden spike in log volume can overwhelm the log server; without a buffer in between, logs are dropped
3. **Ephemeral pods:** when a pod crashes, any buffered logs in the container are lost unless there is a separate process collecting them
4. **Credential management at scale:** each pod would need credentials to write to the log server — managing rotation across hundreds of pods is operationally complex
5. **Resource contention:** every pod adding network I/O for logging competes with application traffic on the same NIC

**When a log aggregator (sidecar or DaemonSet) helps:**

A log aggregator (Fluentd, Fluent Bit, Vector) runs as a DaemonSet — one per node — and reads log files from `/var/log/containers/`. It:
- Decouples log shipping from application pods
- Buffers locally during backend outages
- Batches and compresses before forwarding
- Adds metadata (node name, pod labels, namespace) centrally
- Handles backpressure without affecting the application

Use a DaemonSet aggregator for **any cluster with more than 5 pods or where log reliability matters**.

**When you can skip the aggregator:**

- Very small setups (1–2 pods, dev/test only)
- When the platform handles log collection natively (e.g. AWS ECS with `awslogs` driver writes directly to CloudWatch without a sidecar — AWS manages the buffering and retry)
- When logs are not a compliance or debugging requirement

---

## Q5 — Autoscaling: Cluster Autoscaler vs Karpenter

**Why use Cluster Autoscaler if you have Karpenter?**

In most new AWS EKS deployments you would **not** run both simultaneously on the same node group. Karpenter supersedes Cluster Autoscaler for node provisioning on AWS. However, there are specific situations where Cluster Autoscaler is still appropriate:

1. **Non-AWS cloud providers:** Karpenter is AWS-native. On GKE or AKS, Cluster Autoscaler is still the standard tool.
2. **Managed node groups with strict compliance requirements:** some organisations require nodes to come from a pre-approved, fixed AMI list — Cluster Autoscaler works with managed node groups while Karpenter uses its own provisioning.
3. **Gradual migration:** running Cluster Autoscaler for existing node groups while piloting Karpenter on a new NodePool is a common migration pattern.

**When is Karpenter not a good fit?**

| Situation | Why Karpenter Struggles |
|-----------|------------------------|
| **Spot interruption-sensitive workloads** | Karpenter consolidates nodes aggressively — fine most of the time, but can cause more frequent pod rescheduling than desired for stateful workloads |
| **Strict node compliance / golden AMI** | Karpenter provisions nodes dynamically; if security policy requires nodes from a specific, pre-scanned AMI managed by a different team, the workflow is more complex |
| **Non-EKS Kubernetes** | Karpenter has limited support outside of EKS (GKE Autopilot and Azure are separate implementations) |
| **Teams unfamiliar with NodePool CRDs** | The NodePool/EC2NodeClass API is powerful but has a learning curve; smaller teams may find Cluster Autoscaler's managed node group model simpler to operate |

**Rule of thumb:** Use Karpenter for new EKS clusters. Use Cluster Autoscaler when the cloud provider is not AWS or when organisational constraints require managed node groups.

---

## Q6 — Public TLS Certificates for Internal-Only Services

**Problem:** how to get a valid, publicly trusted TLS certificate for a service that only has a private IP (e.g. `10.0.27.99`) and no public DNS record.

**Method 1 — DNS-01 ACME Challenge (recommended)**

Let's Encrypt and other CAs support the DNS-01 challenge, which proves domain ownership by creating a `TXT` record in DNS — not by serving HTTP on a public IP.

**How it works:**
1. Register a DNS name (e.g. `internal-api.yourdomain.com`) in a public DNS zone (Route 53, Cloudflare)
2. Point it to the private IP `10.0.27.99` (the record is public but the IP is private)
3. Use `certbot` or `cert-manager` with DNS-01 challenge:
   - The CA asks you to create `_acme-challenge.internal-api.yourdomain.com TXT "abc123"`
   - You create the record via DNS provider API (Route 53, Cloudflare)
   - CA verifies it and issues the certificate
4. No HTTP traffic ever goes to `10.0.27.99` — the challenge is purely in DNS

**Trade-offs:**
- ✓ Works for private IPs with no internet exposure
- ✓ Can automate with cert-manager in Kubernetes
- ✓ Certificates are free (Let's Encrypt) or cheap
- ✗ Requires access to a public DNS zone and API credentials for DNS provider
- ✗ Certificate renewal automation must be maintained

**Method 2 — Internal CA + Certificate pinning or trust injection**

Deploy an internal PKI (e.g. AWS Private CA, HashiCorp Vault PKI, or a self-hosted CA) and issue certificates from it for internal services.

**How it works:**
1. Create an internal CA
2. Issue a certificate for `10.0.27.99` or `internal-api.corp` from the internal CA
3. Push the CA's root certificate to all clients that need to trust it (via MDM, Ansible, Puppet, Group Policy)

**Trade-offs:**
- ✓ No public DNS needed; works fully air-gapped
- ✓ Full control over validity periods and revocation
- ✗ Every client must explicitly trust the internal CA root — adds operational overhead
- ✗ Browsers and external tools will not trust it without manual configuration
- ✗ AWS Private CA costs ~$400/month for an active CA

**Which to choose:**
- If clients are internal-only machines you control → **Internal CA**
- If any client is a browser or external system → **DNS-01 with a public DNS name pointing to the private IP**
