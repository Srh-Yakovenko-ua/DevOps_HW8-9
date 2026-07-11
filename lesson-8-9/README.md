# Lesson 8-9. Full CI/CD for Dealsbe: Jenkins + Terraform + ECR + Helm + Argo CD

This project builds a complete, hands-off CI/CD pipeline for the **Dealsbe**
Django application on Amazon EKS. The cluster, the registry, Jenkins
and Argo CD are all provisioned with **Terraform + Helm**. Here is how a change
reaches production:

1. **Jenkins** builds the Docker image with **Kaniko** (a Kubernetes agent).
2. The image is pushed to **Amazon ECR** with an immutable tag.
3. The pipeline bumps `image.tag` in the Helm chart's `values.yaml` and pushes to Git.
4. **Argo CD** notices the change in Git and **auto-syncs** the cluster (GitOps).

No `kubectl` or `helm` is ever run by hand to deploy the app after the first
apply: a code change flows to production through Git alone.

The whole project is **account-agnostic**. Plug in any AWS credentials and set one
variable (your Git repo URL); the state bucket is named after the account id, and
the ECR host, account id, IAM/IRSA roles and image repository are all resolved at
runtime.

## Table of contents

1. [Architecture & CI/CD flow](#architecture--cicd-flow)
2. [Project structure](#project-structure)
3. [How grading maps to this repo](#how-grading-maps-to-this-repo)
4. [Prerequisites](#prerequisites)
5. [Configuration](#configuration)
6. [Deploy step by step](#deploy-step-by-step)
7. [Verify the Jenkins job](#verify-the-jenkins-job)
8. [Verify the result in Argo CD](#verify-the-result-in-argo-cd)
9. [End-to-end demo (change → pipeline → sync)](#end-to-end-demo-change--pipeline--sync)
10. [Teardown (mind the order!)](#teardown-mind-the-order)
11. [How the pieces fit (design notes)](#how-the-pieces-fit-design-notes)
12. [Local validation](#local-validation)
13. [Troubleshooting](#troubleshooting)

## Architecture & CI/CD flow

```
                 git push (app code)
   Developer ─────────────────────────────▶  GitHub repo  ◀───────────────┐
                                              (main branch)                │
                                                   │                       │
                                          poll / webhook                   │ 4. git push
                                                   ▼                       │  values.yaml
   ┌──────────────────────── Amazon EKS cluster ───────────────────────────────────┐
   │                                                                                │
   │   ns: jenkins                          ns: argocd                              │
   │  ┌───────────────────┐               ┌───────────────────┐                     │
   │  │  Jenkins controller│  1. spins up │   Argo CD server   │                     │
   │  │  (Helm + JCasC)    │──────────────│   watches Git @    │                     │
   │  └─────────┬─────────┘   ephemeral   │   charts/django-app│                     │
   │            │ Kubernetes agent pod    └─────────┬─────────┘                     │
   │            ▼                                    │ 5. detects new tag,           │
   │  ┌───────────────────┐                          │    helm upgrade (auto-sync)   │
   │  │  kaniko │  tools   │                          ▼                              │
   │  │  (build)│(git+yq)  │              ns: dealsbe                                │
   │  └────┬────┴────┬─────┘             ┌───────────────────┐                       │
   │       │2. push  │4. bump values     │  Dealsbe pods     │  ◀── ELB (public URL) │
   │       │  image  │  & push to Git    │  Deployment+HPA   │                       │
   │       ▼         └───────────────▶   │  Service (LB)     │                       │
   │  ┌───────────┐  (IRSA, no keys)     └───────────────────┘                       │
   │  │Amazon ECR │◀── 2. docker push                                                │
   │  └───────────┘                                                                  │
   └────────────────────────────────────────────────────────────────────────────────┘

   State backend:  S3 (versioned, encrypted) + DynamoDB lock table
   Auth:           EKS OIDC → IRSA (EBS CSI driver, Jenkins Kaniko → ECR)
```

**The loop, numbered:** ① Jenkins launches an ephemeral agent → ② Kaniko builds
and pushes `dealsbe:<sha>-<build>` to ECR (auth via IRSA) → ③/④ the pipeline sets
`image.tag` in `charts/django-app/values.yaml` and pushes to `main` → ⑤ Argo CD
sees the commit and rolls the Deployment. Jenkins never touches the app directly;
Git is the single source of truth.

## Project structure

```
lesson-8-9/
├── main.tf                 # Wires all modules (infra + jenkins + argo_cd)
├── platform.tf             # gp3 default StorageClass + metrics-server
├── provider.tf             # aws + kubernetes + helm (exec auth to EKS)
├── backend.tf              # S3 + DynamoDB remote state
├── versions.tf             # Terraform + provider version pins
├── variables.tf            # All inputs (git repo + token are the only required)
├── locals.tf               # Tags, AZs, account-derived names, in-repo paths
├── outputs.tf              # ECR URL, Jenkins/Argo CD URLs & passwords (as commands)
├── Makefile                # bootstrap, phased apply, access helpers, safe destroy
├── Jenkinsfile             # The pipeline (generic; account values come from JCasC)
├── terraform.tfvars.example
│
├── modules/
│   ├── s3-backend/         # S3 bucket + DynamoDB table for state
│   ├── vpc/                # VPC, public/private subnets, IGW, NAT, EKS subnet tags
│   ├── ecr/                # ECR repository + policy + lifecycle
│   ├── eks/                # EKS cluster, IAM, node group, add-ons
│   │   ├── eks.tf          #   control plane + node group + core add-ons
│   │   ├── iam.tf          #   control-plane and node IAM roles
│   │   ├── oidc.tf         #   IAM OIDC provider (enables IRSA)
│   │   ├── aws_ebs_csi_driver.tf  # EBS CSI add-on + IRSA (PVCs for Jenkins)
│   │   └── ...
│   ├── jenkins/            # Helm-installed Jenkins, configured as code
│   │   ├── jenkins.tf      #   namespace, agent IRSA role (ECR push), GH secret, release
│   │   ├── values.yaml     #   JCasC: k8s cloud, GitHub cred, pipeline env, seed job
│   │   ├── providers.tf    #   required_providers (aws/helm/kubernetes)
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── argo_cd/            # Helm-installed Argo CD + the Dealsbe Application
│       ├── argo_cd.tf      #   namespace, argo-cd release, app-of-apps release
│       ├── values.yaml     #   server LoadBalancer, insecure (behind LB)
│       ├── providers.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── charts/         #   app-of-apps Helm chart
│           ├── Chart.yaml
│           ├── values.yaml #     application + repository settings (set by Terraform)
│           └── templates/
│               ├── application.yaml   # Argo CD Application (auto-sync)
│               └── repository.yaml    # optional private-repo credential
│
├── charts/
│   └── django-app/         # The Dealsbe Helm chart (Deployment, Service, ConfigMap, HPA)
│       ├── Chart.yaml
│       ├── values.yaml     # image.tag is the field Jenkins bumps; Argo injects repo
│       └── templates/
│
├── app/                    # Dealsbe application (Django), the Docker build context
└── scripts/
    └── push-to-ecr.sh      # Manual/first image push (seed :latest)
```

## How grading maps to this repo

| Criterion (points)                                             | Where                                                          |
|----------------------------------------------------------------|----------------------------------------------------------------|
| Jenkins install via Terraform + Helm (20)                      | `modules/jenkins/` (`helm_release`, JCasC `values.yaml`)       |
| Working Jenkins pipeline: build, push, update Git (30)         | `Jenkinsfile` + `modules/jenkins/values.yaml` (seed job, IRSA) |
| Argo CD install via Terraform + Helm (20)                      | `modules/argo_cd/argo_cd.tf`, `values.yaml`                    |
| Argo Application with full Helm-chart sync (20)                | `modules/argo_cd/charts/templates/application.yaml`            |
| README with description, commands and CI/CD diagram (10)       | this file                                                      |

Supporting infra reused from lessons 5 to 7: `modules/{s3-backend,vpc,ecr,eks}`,
`charts/django-app`, `app/`.

## Prerequisites

| Tool      | Version | Purpose                                   |
|-----------|---------|-------------------------------------------|
| Terraform | >= 1.5  | Provision everything                      |
| AWS CLI   | >= 2.x  | Credentials, ECR login, kubeconfig, token |
| kubectl   | >= 1.28 | Talk to the cluster                       |
| Helm      | >= 3.x  | Chart tooling / local validation          |
| Docker    | >= 20.x | Seed the first image (optional)           |

```bash
aws configure                # access key, secret, default region (e.g. us-west-2)
aws sts get-caller-identity   # sanity check
```

You also need:

* A **GitHub repository** holding this project (the branch you submit is
  `lesson-8-9`; the live CI/CD loop runs on `main`).
* A **GitHub Personal Access Token** with `repo` scope (Contents: read/write) so
  Jenkins can push the values bump.

## Configuration

Copy the example tfvars and fill it in (it is gitignored):

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
git_repo_url     = "https://github.com/<you>/DevOps_HW8-9.git"
repo_path_prefix = "lesson-8-9"   # "" if the project is the repo root
gitops_branch    = "main"
github_username  = "<you>"
repo_private     = false          # true for a private repo
```

Keep the token **out of the file** and export it instead:

```bash
export TF_VAR_github_token=ghp_xxxxxxxxxxxxxxxxxxxx
```

Everything else (region, node sizes, chart versions, namespaces) has a default
and can be overridden in `terraform.tfvars` or on the CLI.

> **Note on `repo_path_prefix`.** This repo keeps the project in a `lesson-8-9/`
> subdirectory (so the repo root is `DevOps_HW8-9/`). The default `lesson-8-9`
> makes Jenkins and Argo CD look at `lesson-8-9/Jenkinsfile`,
> `lesson-8-9/charts/django-app`, etc. If you instead make **this folder** the
> repo root, set `repo_path_prefix = ""`.

## Deploy step by step

The Kubernetes/Helm providers authenticate to a cluster that this same code
creates, so the cluster must exist before Jenkins/Argo CD can be installed. The
`Makefile` does this in three phases (all idempotent):

```bash
make bootstrap
# = make backend   (phase 1: S3+DynamoDB state backend, then migrate state)
#   make infra     (phase 2: VPC + ECR + EKS + OIDC + EBS CSI  ~15 min)
#   make platform  (phase 3: StorageClass, metrics-server, Jenkins, Argo CD)
```

Raw Terraform equivalent (for reference):

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
# phase 1
terraform init -backend=false
terraform apply -target=module.s3_backend -auto-approve
terraform init -migrate-state -force-copy \
  -backend-config="bucket=lesson-8-9-tfstate-$ACCOUNT" -backend-config="region=us-west-2"
# phase 2
terraform apply -target=module.vpc -target=module.ecr -target=module.eks -auto-approve
# phase 3
terraform apply -auto-approve
```

Point kubectl at the cluster and (optionally) seed the first image so the very
first Argo CD sync has something to pull:

```bash
make kubeconfig
make seed-image     # builds app/ and pushes :latest to ECR (needs Docker)
```

> Seeding is optional. Without it the app pods sit in `ImagePullBackOff` until
> the first Jenkins build publishes a tag. Everything else still comes up.

Useful outputs:

```bash
terraform output                       # all commands below are printed here too
make jenkins-url        make jenkins-password
make argocd-url         make argocd-password
make app-url            make status
```

## Verify the Jenkins job

```bash
make jenkins-url        # open the printed URL
make jenkins-password   # log in as 'admin'
```

* The pipeline job **`dealsbe-cicd`** already exists. It was created on startup
  by JCasC (no manual job setup).
* Click **Build Now** (or wait for the SCM poll). Watch the stages:
  `Checkout → Prepare → Build & Push (Kaniko → ECR) → Bump Helm values & push`.
* Confirm the image landed in ECR:

  ```bash
  aws ecr describe-images --repository-name lesson-8-9-ecr \
    --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags'
  ```
* Confirm the Git commit: a new `ci: bump dealsbe image tag to <sha>-<n> [skip ci]`
  commit on `main`, touching `charts/django-app/values.yaml`.

## Verify the result in Argo CD

```bash
make argocd-url         # open the printed URL
make argocd-password    # log in as 'admin'
```

* The **`dealsbe`** Application is present and, after a sync, shows
  **Synced / Healthy**.
* From the CLI:

  ```bash
  make argocd-app
  # NAME      SYNC STATUS   HEALTH STATUS
  # dealsbe   Synced        Healthy
  ```
* Open the app:

  ```bash
  make app-url            # http://<elb-hostname>/
  ```

  The page shows the pod name and DB status; `/healthz/` returns `{"status":"ok"}`.

## End-to-end demo (change → pipeline → sync)

1. Make a visible change in the app (e.g. edit the tagline in
   `app/config/urls.py`) and push to `main`.
2. Jenkins picks it up (poll or **Build Now**): Kaniko builds a new tag, pushes
   to ECR, bumps `image.tag`, and pushes the commit.
3. Argo CD detects the new tag within ~3 min and rolls the Deployment
   automatically. Refresh `make app-url` and the change is live. The "Served by
   pod" line shows a fresh pod. **No manual deploy step.**

## Teardown (mind the order!)

Unused cloud resources cost money, so always destroy after grading. LoadBalancers
must go **before** the VPC, and the S3/DynamoDB backend goes **last** (it stores
the very state being destroyed). The Makefile does all of this in order:

```bash
make destroy
# 1. deletes the Argo CD Application so it prunes the app's LoadBalancer
# 2. terraform destroy of jenkins + argo_cd + metrics-server + StorageClass + eks + vpc + ecr
# 3. moves state local, then destroys the S3 bucket + DynamoDB lock table
```

If anything is left behind, check for orphaned ELBs
(`aws elb describe-load-balancers`, `aws elbv2 describe-load-balancers`) before
deleting the VPC.

> ⚠️ Because `terraform destroy` also removes the S3 bucket and DynamoDB table
> that hold the state, a **fresh deploy afterwards must start from
> `make bootstrap`** again (phase 1 recreates the backend).

## How the pieces fit (design notes)

* **IRSA everywhere, zero static keys.** The EKS OIDC provider (`modules/eks/oidc.tf`)
  lets service accounts assume IAM roles. The EBS CSI driver and the Jenkins
  build agent (`jenkins-agent` SA) both use IRSA. Kaniko pushes to ECR with a
  web-identity token, no Docker credentials on disk.
* **Generic Jenkinsfile.** Every account/cluster value (`ECR_REPO`, `AWS_REGION`,
  `GIT_REPO_URL`, `VALUES_PATH`, …) is injected as a global env var by JCasC, so
  the committed `Jenkinsfile` has nothing account-specific in it.
* **Chart values carry only the tag.** Argo CD injects `image.repository` (the
  account-specific ECR URL) as a Helm parameter, so the tracked `values.yaml`
  only needs `image.tag`, which is the one field the pipeline changes. This keeps
  the GitOps diff minimal and the repo account-agnostic.
* **Loop protection.** The GitOps commit is tagged `[skip ci]` and the pipeline
  skips builds triggered by its own commit, so SCM polling never loops.
* **Persistence.** Jenkins keeps `JENKINS_HOME` on a gp3 EBS volume (default
  StorageClass created in `platform.tf`, backed by the EBS CSI driver).

## Local validation

No AWS account needed for these:

```bash
make fmt            # terraform fmt -recursive
make validate       # terraform init -backend=false && terraform validate
helm lint charts/django-app
helm lint modules/argo_cd/charts
helm template dealsbe charts/django-app --set image.repository=EXAMPLE --set image.tag=v1
```

## Troubleshooting

| Symptom                                        | Fix                                                                                          |
|------------------------------------------------|----------------------------------------------------------------------------------------------|
| `Kubernetes cluster unreachable` on first apply| Run the phased `make bootstrap` (cluster must exist before Jenkins/Argo CD install).         |
| Jenkins pod `Pending`                          | EBS CSI/StorageClass not ready. Run `kubectl -n kube-system get pods | grep ebs`, then re-run `make platform`. |
| Pipeline push fails `403`                      | `TF_VAR_github_token` missing/insufficient scope (needs Contents: read/write).               |
| Kaniko `denied: not authorized`               | Agent IRSA not applied. Check the `jenkins-agent` SA annotation and re-run `make platform`.  |
| Argo CD app `OutOfSync` / `ImagePullBackOff`   | Seed the first image (`make seed-image`) or run the pipeline once.                            |
| `error: unable to recognize Application`       | Argo CD CRDs not installed yet. The app-of-apps release depends on the argo-cd release, so re-apply. |
| App pods up but HPA `<unknown>`                | metrics-server still starting. Run `kubectl -n kube-system rollout status deploy/metrics-server`.|
