# DATA 789 · HW4 Rubric — observable checklist (100 pts)

P2-style: every item is a **check you can see**, not a vague outcome. Grade from
submitted **evidence** (manifests + `kubectl` screenshots + the demo output/recording).
No live cluster required at grading time.

> Weight: HW4 = **5%** of the course grade. Full marks are reachable **locally**;
> the Azure floor is a required checkbox; AKS is bonus.

---

## A. Kubernetes deployment — graded core (60 pts)

| ✔ | Check (observable) | Evidence | Pts |
|---|--------------------|----------|-----|
| ☐ | `kubectl get deploy trustbank-fraud` shows **3/3 READY** | screenshot | 10 |
| ☐ | Container has **both** resource **requests and limits** (cpu + memory) | `deployment.yaml` | 10 |
| ☐ | **Readiness** probe configured; pods only receive traffic when ready | `deployment.yaml` + `kubectl describe pod` | 8 |
| ☐ | **Liveness** probe configured | `deployment.yaml` | 7 |
| ☐ | **Service** is `type: LoadBalancer` and `/predict` is reachable through it | `service.yaml` + `smoke_test.sh` 200 | 10 |
| ☐ | **HPA** targets the Deployment, sets min/max, shows a real CPU `TARGETS` value (metrics-server working) | `hpa.yaml` + `kubectl get hpa` | 15 |

## B. Zero-downtime update — graded core (25 pts)

| ✔ | Check (observable) | Evidence | Pts |
|---|--------------------|----------|-----|
| ☐ | Deployment uses a **rolling strategy** with `maxUnavailable: 0` (or blue-green equivalent) | `deployment.yaml` | 8 |
| ☐ | **Rolling-update demo**: image swap under a live request loop with **0 dropped requests** | `rolling_update_demo.sh` output / 2-min recording | 12 |
| ☐ | Can articulate **rolling vs. blue-green** (mechanism, cutover, rollback) | 2–3 sentences or the blue-green demo | 5 |

## C. Azure Container Apps — FLOOR, required (15 pts)

| ✔ | Check (observable) | Evidence | Pts |
|---|--------------------|----------|-----|
| ☐ | Image pushed to **ACR** and running on **Container Apps** | portal screenshot | 5 |
| ☐ | **Public `/predict` URL returns 200** | `smoke_test.sh` against the FQDN | 7 |
| ☐ | **Teardown** performed same day (cost hygiene) | `az group exists` → false, or portal | 3 |

## Bonus (up to +10 pts)

| ✔ | Check | Evidence | Pts |
|---|-------|----------|-----|
| ☐ | Same manifests running on **real AKS**; pods/svc/hpa healthy with a LoadBalancer **EXTERNAL-IP** | `kubectl get pods,svc,hpa -o wide` | +8 |
| ☐ | AKS torn down same day | portal / CLI | +2 |

---

### Grading notes
- **Probes hit `/health`** (the provided image exposes it; no Redis needed to pass a probe).
  The kit also deploys a small Redis (`k8s/redis.yaml`) so `/predict` returns a real score —
  students apply it with `kubectl apply -f k8s/`.
- **`<unknown>` HPA targets** = metrics-server not enabled → the HPA check fails; the
  rest can still pass.
- **Dropped requests > 0** in the rolling demo usually means readiness isn't gating
  traffic or `maxUnavailable` isn't 0 — deduct the 12-pt demo item, keep partials.
- Accept **local (Minikube/kind) full marks**; Azure floor is its own 15 pts; do **not**
  require live cloud resources at grading — screenshots/CLI/recording are the evidence.
