# DATA 789 · HW4 — "Scale It" (Kubernetes)

You already **built** the TrustBank fraud service in Project 2. HW4 is **scale it**: you
take the *working* service and make it production-ready on Kubernetes — highly available,
autoscaling, and updatable with zero downtime. You do **not** rebuild the app.

The fraud service is provided as a **pre-built image you pull**:
`ghcr.io/rfsalas/trustbank-fraud:v1` — no Dockerfile, no build.

> Keep it tight — the graded core is a clean Kubernetes deploy plus one
> zero-downtime update, shown with evidence (manifests + `kubectl` screenshots +
> a 2-minute rolling-update demo).

---

## What's in this folder

```
hw4/
├─ config.env                     # image ref, port, paths, REDIS_HOST (scripts read this)
├─ k8s/
│  ├─ deployment.yaml             # 3 replicas · limits · probes · zero-drop rolling
│  ├─ service.yaml                # LoadBalancer → the API
│  ├─ redis.yaml                  # Redis feature store (the API reads it on /predict)
│  ├─ hpa.yaml                    # CPU autoscaler (needs metrics-server)
│  ├─ configmap.yaml              # optional app config (off by default)
│  └─ blue-green/                 # instant-cutover alternative to the rolling update
├─ scripts/
│  ├─ local_up.sh                 # one-shot Minikube bring-up (pulls the image + Redis)
│  ├─ smoke_test.sh               # POST a real transaction to /predict
│  ├─ rolling_update_demo.sh      # the 2-min zero-drop demo
│  ├─ bluegreen_switch.sh         # flip blue↔green
│  └─ sample_transaction.json     # a real /predict body
├─ deploy_azure.sh / teardown_azure.sh   # the required Azure step
├─ aks_bonus.sh                   # bonus: same manifests on real AKS
├─ .devcontainer/                 # ready env: kubectl + az + minikube
├─ .github/workflows/autograde.yml# auto-checks your manifests on every push
├─ GITHUB-QUICKSTART.md           # how to submit via GitHub (no command line)
├─ AZURE-QUICKSTART.md            # Azure for Students: sign up, stay free, tear down
├─ HW4-rubric-checklist.md        # exactly what's graded
└─ README-hw4.md                  # you are here
```

## How the pieces fit

- The **API** answers `GET /health` (used by the probes — **no Redis needed**, so pods
  go Ready) and `POST /predict` (scores a transaction; **reads customer features from Redis**).
- `k8s/redis.yaml` runs a small Redis reachable at the DNS name `redis`, and the API is
  told `REDIS_HOST=redis`. **No data seeding** — an unknown customer falls back to the
  API's built-in rule-based scorer, so `/predict` still returns a valid result.

---

## Path A · Full marks — local Kubernetes

Prereqs: Docker Desktop + Minikube, **or** open the repo in the `.devcontainer` /
Codespaces (kubectl + minikube preinstalled).

```bash
./scripts/local_up.sh                          # applies Redis + API + Service + HPA, waits for ready
kubectl get pods,svc,hpa -o wide               # ← screenshot: 3/3 ready, HPA with a real target

# route to the service (simplest — no LoadBalancer/tunnel needed):
kubectl port-forward svc/trustbank-fraud 8080:80
# second terminal — a real prediction:
./scripts/smoke_test.sh http://localhost:8080  # ← screenshot: 200 + fraud decision

# zero-downtime update:
./scripts/rolling_update_demo.sh http://localhost:8080 ghcr.io/rfsalas/trustbank-fraud:v2
#   → "dropped: 0"  ← screenshot

# blue-green (the contrast): see k8s/blue-green/README.md
kubectl apply -f k8s/blue-green/ && ./scripts/bluegreen_switch.sh green
```

**HPA note:** needs `minikube addons enable metrics-server` (local_up.sh does this); give
it a minute or `kubectl get hpa` shows `<unknown>`.

## Path B · Required — Azure Container Apps

**New to Azure? Read [`AZURE-QUICKSTART.md`](AZURE-QUICKSTART.md) first** — sign-up, staying at ~$0, and one-click teardown.

Easiest in **Azure Cloud Shell** (already signed in). This ships the API to real cloud and
gives a public URL. It runs the API alone (no Redis) — `/predict` still returns a valid
score (an unknown customer falls back to the built-in scorer), so you verify the real
cloud endpoint here.

```bash
./deploy_azure.sh                               # imports the image → Container Apps → public URL
curl https://<fqdn>/health                      # → {"status":"ok"}
./scripts/smoke_test.sh https://<fqdn>          # POST /predict → a fraud decision  ← screenshot
./teardown_azure.sh                             # ← DO THIS THE SAME DAY
```

Auth is AAD / managed-identity (no keys); region `centralus`.

## Path C · Bonus — real AKS

```bash
./aks_bonus.sh             # 1 node, applies k8s/ (incl. Redis); pulls the public image
# screenshot pods/svc/hpa + the LoadBalancer EXTERNAL-IP, then delete the resource group.
```

Azure-for-Students has a low vCPU quota — if node creation fails on quota, that's expected;
AKS is bonus, so fall back to Minikube or the Container Apps floor.

---

## Cost hygiene (non-negotiable)

- Scale-to-zero on Container Apps; 1 small node on AKS.
- Deploy → capture evidence → `az group delete` the **same day**.
- Set a spending cap + cost alert. You're graded from **evidence**, not live resources.

## What to submit

See `HW4-rubric-checklist.md`. In short: your `k8s/` manifests; screenshots of
`kubectl get pods,svc,hpa` (3/3 ready, a real HPA target) and a 200 from `/predict`; the
rolling-update demo showing **0 dropped requests**; the Azure floor `/predict` 200 +
teardown proof; (bonus) AKS.
