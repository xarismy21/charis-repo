# Technical Questions • Short Answers • Optional

Assessment optional section. Time budget: 20–30 minutes total.

---
*NOTE: I used AI as a thinking aid to help structure and articulate my answers. The technical understanding, decisions, and reasoning reflect my own knowledge — I reviewed, edited, and validated each answer based on my hands-on experience.*
---

## Q1 — K8s Networking

**From pod-A you see.
● http://www.demo.domain.tv/ → Failure
● http://backend.demo.domain.tv/api/v1/health → Failure
● http://backend-domdomain-demo.backend.svc.cluster.local:4000/api/v1/health → Success
● http://frontend-domdomain-demo.frontend.svc.cluster.local:3000/ → Success Why does this happen? Constraint. not DNS-related.**

**Answer:**

Internal cluster URLs work, external ones don't — that's a NetworkPolicy blocking egress. Pod-A can talk to other pods inside the cluster but can't reach anything that goes through the ingress or load balancer. Add an egress rule that allows traffic to external IPs on port 80/443.

## Q2 — Overlapping Networks
**What are overlapping networks, and the most cost-effective way to remove them in a multi-VPC??**

**Answer:**

Two VPCs using the same CIDR block (e.g. both on 10.0.0.0/16) — routing breaks because nobody knows where to send packets. Cheapest fix: re-IP the smaller VPC. Pick a new range, migrate resources, done. If you can't touch the IPs, use Transit Gateway with NAT translation — works but costs more and adds complexity.

---

## Q3 — Rollback • Production K8s
**Design a rollback strategy for production Kubernetes. how to balance speed, reliability, and data consistency.**

**Answer:**

Fast path: kubectl rollout undo — back in 2 minutes, no drama. If you're on Helm, helm rollback. The tricky part is the database — if a destructive migration already ran, you're restoring from a snapshot and accepting some data loss. That's why you always write additive-only migrations so the old app version can still run against the new schema.

---

## Q4 — Logging Architecture
**Why is sending logs directly from pods to the log server a bad idea. when does a log aggregator help, and when can it be skipped.**

**Answer:**

If your pod ships logs directly, it's also responsible for retries, backpressure, credentials — all that noise in your app code. When the log server hiccups, your app hiccups. A DaemonSet aggregator (Fluent Bit, Vector) sits on each node, reads logs from disk, and handles all of that separately. Skip it only for dev/test or when the platform already does it for you (like ECS with awslogs).

---

## Q5 — Autoscaling Strategy
**Why use Cluster Autoscaler if you have Karpenter. when is Karpenter not a good fit.**

**Answer:**

On AWS EKS, just use Karpenter — it's faster and smarter. Cluster Autoscaler still makes sense if you're not on AWS, if compliance locks you to managed node groups, or you're mid-migration. Karpenter is a bad fit for stateful workloads that hate being rescheduled, and for teams who aren't ready to deal with NodePool CRDs.

---

## Q6 — Certificates for Private Services
**How to get public TLS for internal-only services on private IPs like 10.0.27.99. give two methods and trade-offs.**

**Answer:**

Option 1 — DNS-01 challenge: Point a public DNS name at the private IP, then use cert-manager or certbot to get a Let's Encrypt cert via a DNS TXT record. No HTTP traffic ever hits the private IP. Works great, it's free, and it's fully automatable.

Option 2 — Internal CA: Spin up a private CA (Vault PKI or AWS Private CA), issue certs internally, push the root cert to every client. Works air-gapped but every client needs to trust it manually.
If browsers are involved, go DNS-01. If it's all internal machines you control, internal CA is cleaner.

**Which to choose:**
- If clients are internal-only machines you control → **Internal CA**
- If any client is a browser or external system → **DNS-01 with a public DNS name pointing to the private IP**


