<div align="center">

```
 ██████╗██╗     ██████╗██████╗     ███████╗███╗   ██╗████████╗
██╔════╝██║    ██╔════╝██╔══██╗    ██╔════╝████╗  ██║╚══██╔══╝
██║     ██║    ██║     ██║  ██║    █████╗  ██╔██╗ ██║   ██║
██║     ██║    ██║     ██║  ██║    ██╔══╝  ██║╚██╗██║   ██║
╚██████╗██║    ╚██████╗██████╔╝    ███████╗██║ ╚████║   ██║
 ╚═════╝╚═╝     ╚═════╝╚═════╝    ╚══════╝╚═╝  ╚═══╝   ╚═╝
        Enterprise CI/CD Pipeline — Azure DevOps Edition
```

**Multi-Branch · PR Auto-Trigger · 6-Environment Promotion · Zero-Downtime Helm Deploys**

[![CI Status](https://img.shields.io/badge/CI-Passing-22c55e?style=flat-square&logo=azurepipelines&logoColor=white)](https://dev.azure.com)
[![Security](https://img.shields.io/badge/Security-Trivy%20Scanned-0ea5e9?style=flat-square&logo=aquasecurity&logoColor=white)](https://trivy.dev/)
[![Code Quality](https://img.shields.io/badge/Quality-SonarQube-f97316?style=flat-square&logo=sonarqube&logoColor=white)](https://sonarqube.org/)
[![Docker](https://img.shields.io/badge/Images-Distroless-0369a1?style=flat-square&logo=docker&logoColor=white)](https://github.com/GoogleContainerTools/distroless)
[![Helm](https://img.shields.io/badge/Deploy-Helm%20v3-0f172a?style=flat-square&logo=helm&logoColor=white)](https://helm.sh/)
[![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes-326ce5?style=flat-square&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Azure DevOps](https://img.shields.io/badge/Platform-Azure%20DevOps-0078D7?style=flat-square&logo=azuredevops&logoColor=white)](https://azure.microsoft.com/en-us/products/devops)
[![License: MIT](https://img.shields.io/badge/License-MIT-22c55e?style=flat-square)](LICENSE)

<br/>

> **Enterprise-grade CI/CD on Azure DevOps.**  
> PR auto-triggers, SonarQube gates, Trivy CVE scanning, distroless Docker, Helm rollouts,  
> dual-approval gates before prod — and Slack tells your team everything.

<br/>

[⚡ Pipeline Flow](#-pipeline-flow) · [🌍 Environments](#-environments) · [🔀 Branch Strategy](#-branch-strategy) · [🔧 Setup](#-setup) · [📋 Runbook](#-runbook)

</div>

---

## 🗺️ The Big Picture

This pipeline covers **6 environments** — `dev`, `uat`, `pre-prod`, `prod`, `dr` — with full promotion gates, security scanning at every layer, code quality enforcement, and human approval before anything touches production or DR.

Every PR auto-triggers its own isolated pipeline and gets a preview URL posted as a PR comment. Every deploy sends a Slack notification. Every rollback is one command. Production requires dual approval. DR requires SRE sign-off.

---

## 📁 Repository Structure

```
cicd-enterprise/
│
├── 📂 .azure/
│   └── pipelines/
│       ├── pr-pipeline.yml           # PR auto-trigger (lint, test, preview env)
│       ├── dev-pipeline.yml          # feature/*, fix/* → dev deploy
│       ├── uat-pipeline.yml          # release/* → UAT deploy + integration tests
│       ├── preprod-pipeline.yml      # pre-prod branch → pre-prod + load tests
│       ├── prod-pipeline.yml         # main → PROD deploy (dual approval + canary)
│       ├── dr-pipeline.yml           # post-prod → DR deploy (SRE approval)
│       ├── hotfix-pipeline.yml       # hotfix/* → fast-track prod (2h approval)
│       └── pr-cleanup-pipeline.yml   # PR closed → delete ephemeral namespace
│
├── 📂 docker/
│   ├── Dockerfile.distroless         # Production distroless image (nonroot)
│   └── Dockerfile.debug              # Debug image — NOT for prod
│
├── 📂 helm/
│   ├── Chart.yaml
│   ├── values.yaml                   # Base values
│   └── values/
│       ├── values-dev.yaml
│       ├── values-uat.yaml
│       ├── values-preprod.yaml
│       ├── values-prod.yaml          # 5 replicas, HPA, zero-downtime rolling
│       └── values-dr.yaml            # 3 replicas, drMode=true
│
├── 📂 envs/
│   ├── dev.env · uat.env · pre-prod.env · prod.env · dr.env
│
├── 📂 trivy/
│   ├── trivy-config.yaml             # Scan config (CRITICAL+HIGH = FAIL)
│   └── ignore.yaml                   # CVE exceptions (expiry dates required)
│
├── 📂 scripts/
│   ├── notify.sh                     # Slack notification sender
│   ├── smoke-test.sh                 # Post-deploy health verification
│   ├── rollback.sh                   # One-command Helm rollback
│   └── cleanup-pr-env.sh             # Delete ephemeral PR namespaces
│
├── 📂 tests/
│   ├── unit/ · integration/ · smoke/ · load/   # k6 load tests (pre-prod only)
│
└── README.md
```

---

## 🌍 Environments

| Env | Purpose | Trigger | Approval | Namespace |
|-----|---------|---------|----------|-----------|
| `dev` | Feature development & integration | Push to `feature/*`, `fix/*`, `develop` | ❌ Auto | `cicd-dev` |
| `uat` | User acceptance testing | Push to `release/*` | ❌ Auto | `cicd-uat` |
| `pre-prod` | Production-mirror staging | Push to `pre-prod` | ✅ Tech Lead (24h) | `cicd-preprod` |
| `prod` | Live production traffic | Push to `main` | ✅ Tech Lead + Manager (48h) | `cicd-prod` |
| `dr` | Disaster recovery standby | Queued after prod | ✅ SRE On-call (12h) | `cicd-dr` |
| `PR preview` | Ephemeral per-PR preview | PR opened / updated | ❌ Auto | `pr-{number}` |

---

## ⚡ Pipeline Flow

```
COMMIT / PR OPEN
      │
      ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│   BUILD &   │──▶│  SONARQUBE  │──▶│    TRIVY    │──▶│   DOCKER    │
│  UNIT TEST  │   │ QUALITY GATE│   │  CVE SCAN   │   │  DISTROLESS │
│             │   │             │   │             │   │  BUILD+SCAN │
│ Coverage≥80%│   │ No BLOCKERs │   │ CRITICAL=❌ │   │   + PUSH    │
│ JUnit/JaCoCo│   │ No CRITICALs│   │ HIGH=❌     │   │  3 tags     │
└─────────────┘   └─────────────┘   └─────────────┘   └──────┬──────┘
                                                              │
              ┌───────────────────────────────────────────────┘
              │
              ▼
    ┌──────────────────┐
    │    DEV DEPLOY    │ ← Auto on feature/*, fix/*, develop
    │  Helm upgrade    │
    │  Smoke tests     │
    │  Slack: ✅ Dev   │
    └────────┬─────────┘
             │ (release/* branch)
             ▼
    ┌──────────────────┐
    │    UAT DEPLOY    │ ← Auto on release/*
    │  Integration tests│
    │  API contract test│
    │  Slack: ✅ UAT   │
    └────────┬─────────┘
             │ (pre-prod branch)
             ▼
    ┌──────────────────┐
    │ PRE-PROD DEPLOY  │
    │ 🔐 Tech Lead     │ ← 24h approval window
    │  k6 Load tests   │
    │  Regression suite│
    └────────┬─────────┘
             │ (main branch)
             ▼
    ┌──────────────────┐
    │   PROD DEPLOY    │
    │ 🔐🔐 Tech Lead   │ ← 48h dual approval
    │   + Eng Manager  │
    │  Canary 10%→100% │
    │  Auto rollback   │
    └────────┬─────────┘
             │ (queued automatically)
             ▼
    ┌──────────────────┐
    │    DR DEPLOY     │
    │ 🔐 SRE On-call  │ ← 12h approval
    │  Failover verify │
    └──────────────────┘
```

### PR Auto-Trigger Flow

When any PR is opened or updated against `develop`, `release/*`, `pre-prod`, or `main`:

```
PR Opened / Updated
       │
       ▼
  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────────────────┐
  │  Lint &  │──▶│  Unit    │──▶│ SonarQube│──▶│  Ephemeral Preview   │
  │  Compile │   │  Tests   │   │ PR Gate  │   │  https://pr-42.dev.  │
  └──────────┘   └──────────┘   └──────────┘   │  k8s.company.com     │
                                                │  (posted to PR)      │
                                                └──────────────────────┘
                                                PR Merged → auto-deleted
```

---

## 🔀 Branch Strategy

```
main ────────────────────────────────────────────────────── PROD + DR
  │
  └── pre-prod ──────────────────────────────────────── PRE-PROD
        │
        └── release/v1.2.0 ────────────────────────── UAT
              │
              └── develop ───────────────────────── DEV (integration)
                    │
                    ├── feature/JIRA-101-login ─── DEV
                    ├── feature/JIRA-204-payment ── DEV
                    └── fix/JIRA-309-auth-expiry ── DEV
                    
hotfix/* ──────────────────────────────────────────── PROD (fast-track)
```

| Branch Pattern | Pipeline | Auto-Deploy To | Approval |
|---------------|----------|----------------|----------|
| `feature/*` | dev-pipeline | dev | None |
| `fix/*` | dev-pipeline | dev | None |
| `develop` | dev-pipeline | dev | None |
| `release/*` | uat-pipeline | uat | None |
| `pre-prod` | preprod-pipeline | pre-prod | Tech Lead (24h) |
| `main` | prod-pipeline | prod → dr | Tech Lead + Mgr (48h) |
| `hotfix/*` | hotfix-pipeline | prod | SRE + Tech Lead (2h) |

---

## 🔧 Setup

### Prerequisites

```
kubectl     >= 1.28
helm        >= 3.13
docker      >= 24.0
Azure DevOps (any tier — parallel jobs required for multi-stage)
SonarQube   >= 9.x (or SonarCloud)
Trivy       >= 0.48 (installed by pipeline — no pre-install needed)
```

### Step 1 — Create Azure DevOps Variable Groups

Go to **Pipelines → Library → + Variable group** and create:

**`cicd-global-secrets`** (mark all as secret):
```
REGISTRY_URL              = myregistry.azurecr.io
REGISTRY_SERVICE_CONNECTION = <ADO service connection name>
SONAR_HOST_URL            = https://sonar.company.com
SONAR_TOKEN               = <sonarqube token>
SLACK_WEBHOOK_URL         = https://hooks.slack.com/services/...
AZURE_DEVOPS_PAT          = <pat with build read/write>
DR_PIPELINE_ID            = <pipeline ID of dr-pipeline>
PACT_BROKER_URL           = https://pact.company.com
```

**`cicd-dev-secrets`**, **`cicd-uat-secrets`**, **`cicd-preprod-secrets`**, **`cicd-prod-secrets`**, **`cicd-dr-secrets`** — one per environment with env-specific secrets (DB URLs, etc.).

### Step 2 — Create ADO Service Connections

Go to **Project Settings → Service connections** and add:

- **`SonarQube-Connection`** — SonarQube/SonarCloud service connection
- **`<REGISTRY_SERVICE_CONNECTION>`** — Docker Registry (Azure Container Registry recommended)
- **`KUBECONFIG_DEV_CONNECTION`** — Kubernetes service connection for dev cluster
- **`KUBECONFIG_UAT_CONNECTION`** — Kubernetes service connection for UAT cluster
- **`KUBECONFIG_PREPROD_CONNECTION`** — Kubernetes service connection for pre-prod cluster
- **`KUBECONFIG_PROD_CONNECTION`** — Kubernetes service connection for prod cluster
- **`KUBECONFIG_DR_CONNECTION`** — Kubernetes service connection for DR cluster

### Step 3 — Configure Environments with Approval Gates

Go to **Pipelines → Environments** and create each environment, then add approval checks:

| Environment | Approvers | Timeout | Self-approve |
|-------------|-----------|---------|--------------|
| `dev` | None | — | — |
| `uat` | None | — | — |
| `pre-prod` | `tech-lead-team` | 1440 min (24h) | Allowed |
| `production` | `tech-lead-team` + `engineering-managers` | 2880 min (48h) | **Blocked** |
| `hotfix` | `sre-oncall-team` + `tech-lead-team` | 120 min (2h) | Allowed |
| `dr` | `sre-oncall-team` | 720 min (12h) | Allowed |

> **For Production:** Enable "Prevent self-approval" so the person who triggers the pipeline cannot approve it.

### Step 4 — Register Pipelines in Azure DevOps

Go to **Pipelines → New Pipeline → Azure Repos Git → Existing YAML file** for each:

| Pipeline Name | YAML Path |
|---------------|-----------|
| PR Pipeline | `.azure/pipelines/pr-pipeline.yml` |
| Dev Pipeline | `.azure/pipelines/dev-pipeline.yml` |
| UAT Pipeline | `.azure/pipelines/uat-pipeline.yml` |
| Pre-Prod Pipeline | `.azure/pipelines/preprod-pipeline.yml` |
| Prod Pipeline | `.azure/pipelines/prod-pipeline.yml` |
| DR Pipeline | `.azure/pipelines/dr-pipeline.yml` |
| Hotfix Pipeline | `.azure/pipelines/hotfix-pipeline.yml` |
| PR Cleanup | `.azure/pipelines/pr-cleanup-pipeline.yml` |

### Step 5 — Configure PR Cleanup Trigger

The PR cleanup pipeline runs when a PR is closed. Wire it up via:

**Project Settings → Service Hooks → + Subscription:**
- Service: `Azure Pipelines`
- Trigger: `Pull request updated` → Status = `Completed`
- Action: `Run a pipeline` → select `PR Cleanup`

### Step 6 — Configure SonarQube

```properties
# sonar/sonar-project.properties
sonar.projectKey=my-service
sonar.projectName=My Service
sonar.sources=src/main
sonar.tests=src/test
sonar.java.binaries=target/classes
sonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
```

In SonarQube UI, set the Quality Gate:
- Coverage on New Code ≥ 80%
- New Blocker Issues = 0 → **FAIL**
- New Critical Issues = 0 → **FAIL**
- New Major Issues < 10 → Warning

### Step 7 — First Deploy

```bash
git clone https://github.com/yourorg/cicd-enterprise.git
cd cicd-enterprise

# Push a feature branch → triggers dev pipeline automatically
git checkout -b feature/JIRA-001-initial-setup
git push origin feature/JIRA-001-initial-setup

# Open a PR → preview URL posted as PR comment
# Preview: https://pr-1.dev.k8s.company.com

# Merge develop → dev integration deploy
# Create release branch → UAT deploy
git checkout -b release/v1.0.0
git push origin release/v1.0.0

# Merge release → pre-prod → Tech Lead approves
# Merge pre-prod → main → Dual approval → Prod + DR
```

---

## 🔐 Approval Gates — Reference

### Pre-Prod (Single, 24h)

When the pre-prod pipeline reaches the approval stage, this Slack message fires to `#deployments`:

```
🔔 Approval Required — PRE-PROD Deploy
─────────────────────────────────────────
App:      my-service
Version:  v2.4.1 (a3f9c12)
By:       john.doe
Expires:  24 hours
─────────────────────────────────────────
[Approve in Azure DevOps]
```

### Production (Dual, 48h)

Both Tech Lead **and** Engineering Manager must approve independently. Self-approval is blocked.

```
🔔 Approval Required — PRODUCTION Deploy
─────────────────────────────────────────
App:      my-service
Version:  v2.4.1 (a3f9c12)
Approvers: @tech-leads @eng-managers (both required)
Expires:  48 hours
─────────────────────────────────────────
[Approve in Azure DevOps]
```

**Escalation:** At +4h a reminder DM is sent. At +24h an email escalates to Engineering Director. At +48h the pipeline expires and must be re-triggered.

### Hotfix (Expedited, 2h)

SRE + Tech Lead are paged simultaneously. The 2h window is intentionally short — if no approval arrives, the incident escalation process takes over.

---

## 🔒 Security

- **Distroless images** — no shell, no package manager in prod containers
- **Non-root containers** — all pods run as `uid: 65532`
- **Read-only root filesystem** — `readOnlyRootFilesystem: true`
- **No privilege escalation** — `allowPrivilegeEscalation: false`
- **All capabilities dropped** — `capabilities.drop: ["ALL"]`
- **Trivy scans** — filesystem, image layers, Helm/K8s manifests, secrets
- **SonarQube OWASP** — Top 10 security hotspot tracking per branch
- **CVE exceptions** — `trivy/ignore.yaml` entries must include a JIRA ticket and expiry date

### Adding a CVE Exception

```yaml
# trivy/ignore.yaml
vulnerabilities:
  - id: CVE-2024-12345
    paths:
      - "some/path/**"
    statement: "Not exploitable in our runtime — see JIRA-999"
    expires: "2024-06-01"
```

---

## 🔄 Rollback

### Automatic

Helm's `--atomic` flag rolls back automatically if pods fail to become healthy. Slack fires a `❌ Deploy FAILED — auto-rolled back` alert immediately.

### Manual

```bash
# Roll back to previous release
bash scripts/rollback.sh --env prod

# Roll back to specific Helm revision
bash scripts/rollback.sh --env prod --revision 14

# Check rollback history
helm history my-service -n cicd-prod
```

---

## 🔔 Slack Notification Routing

| Event | Channel | Ping |
|-------|---------|------|
| Dev deploy success/fail | `#deployments-dev` | None |
| UAT deploy success/fail | `#deployments-uat` | None |
| Pre-prod approval needed | `#deployments` | `@tech-leads` |
| Prod approval needed | `#deployments` | `@tech-leads @eng-managers` |
| DR approval needed | `#sre-ops` | `@sre-oncall` |
| Prod deploy success | `#deployments` | None |
| Prod deploy failure | `#incidents` | `@sre-oncall @tech-leads` |
| CVE / Quality gate fail | `#security-alerts` | `@security-team` |
| Hotfix deployed | `#incidents` | None |

---

## 📊 Pipeline KPIs

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Pipeline success rate | > 95% | < 90% |
| Mean pipeline duration | < 12 min | > 20 min |
| Mean time to production | < 2 days | > 5 days |
| Approval wait time (prod) | < 4 hours | > 24 hours |
| Rollback frequency | < 2/month | > 5/month |
| CVE block rate | < 5% | > 15% |
| Coverage gate fail rate | < 10% | > 20% |

---

## 🤝 Contributing

```bash
# Branch naming convention
feature/JIRA-XXX-short-description
fix/JIRA-XXX-short-description
hotfix/JIRA-XXX-short-description

# PR checklist (auto-enforced by pipeline)
[ ] Unit tests pass locally
[ ] Coverage >= 80%
[ ] No SonarQube BLOCKER or CRITICAL issues
[ ] No Trivy CRITICAL CVEs
[ ] Helm values updated if new config added
[ ] envs/*.env updated if new env var added
[ ] CHANGELOG.md updated for user-facing changes
```

---

## 📖 Additional Documentation

| Doc | Description |
|-----|-------------|
| [RUNBOOK.md](docs/RUNBOOK.md) | On-call pipeline incident runbook |
| [APPROVAL-PROCESS.md](docs/APPROVAL-PROCESS.md) | Approval gate policies and escalation paths |
| [BRANCHING.md](docs/BRANCHING.md) | Branching and merge strategy detail |
| [ADDING-NEW-SERVICE.md](docs/ADDING-NEW-SERVICE.md) | Onboarding a new microservice |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common pipeline failures and fixes |
| [SECURITY.md](docs/SECURITY.md) | CVE handling, image signing, secrets policy |

---

## 📜 License

MIT License — see [LICENSE](LICENSE)

---

<div align="center">

**Ship faster. Break nothing. Sleep better.**

⭐ Star this if it saved your team time · 🐛 [Report Issue](../../issues) · 💡 [Request Feature](../../issues)

</div>
