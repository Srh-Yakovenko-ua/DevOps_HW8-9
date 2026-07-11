# Makefile for the lesson-8-9 CI/CD project (Terraform + Helm + Jenkins + Argo CD).
# Run `make help` to see the available targets.
#
# The project is account agnostic: the state bucket name is derived from the
# current AWS account id, so anyone can plug in their own credentials and deploy
# into their own account without editing a single file.
#
# CI/CD inputs (git_repo_url, github_username, github_token, ...) come from a
# terraform.tfvars file (copy terraform.tfvars.example) or TF_VAR_* env vars.

# Override on the command line, for example: make apply REGION=eu-central-1
PROJECT   ?= lesson-8-9
REGION    ?= us-west-2
CLUSTER   ?= $(PROJECT)-eks
RELEASE   ?= dealsbe
CHART     ?= charts/django-app

# Namespaces
JENKINS_NS ?= jenkins
ARGOCD_NS  ?= argocd
APP_NS     ?= dealsbe
APP        ?= dealsbe

# The state bucket name is unique per account. The account id is resolved at
# recipe run time because it needs live AWS credentials.
BACKEND_CONFIG = -backend-config="bucket=$(PROJECT)-tfstate-$$(aws sts get-caller-identity --query Account --output text)" -backend-config="region=$(REGION)"
TF_VARS        = -var="aws_region=$(REGION)" -var="project=$(PROJECT)"

.DEFAULT_GOAL := help
.PHONY: help fmt validate init backend infra platform bootstrap plan apply destroy clean \
        kubeconfig seed-image \
        jenkins-url jenkins-password argocd-url argocd-password app-url \
        argocd-app status

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Terraform lifecycle
# ---------------------------------------------------------------------------
fmt: ## Format all Terraform files
	terraform fmt -recursive

validate: ## Validate the configuration without touching AWS
	terraform init -backend=false
	terraform validate

init: ## Initialize Terraform against the remote backend
	terraform init $(BACKEND_CONFIG)

backend: ## Phase 1 (first run only): create the S3/DynamoDB backend and migrate state into it
	terraform init -backend=false
	terraform apply -target=module.s3_backend -auto-approve $(TF_VARS)
	terraform init -migrate-state -force-copy $(BACKEND_CONFIG)

infra: ## Phase 2: create the network + registry + cluster (VPC, ECR, EKS, OIDC, EBS CSI)
	terraform apply -auto-approve $(TF_VARS) \
		-target=module.vpc -target=module.ecr -target=module.eks

platform: ## Phase 3: install the platform + CI/CD (StorageClass, metrics-server, Jenkins, Argo CD)
	terraform apply -auto-approve $(TF_VARS)

bootstrap: backend infra platform ## First-run: backend -> infra -> platform, end to end
	@echo ">> Bootstrap complete. Run 'make kubeconfig' then 'make status'."

plan: ## Show the execution plan (after bootstrap)
	terraform plan $(TF_VARS)

apply: ## Create/update everything in one shot (after the cluster exists)
	terraform apply $(TF_VARS)

# ---------------------------------------------------------------------------
# Kubernetes / image
# ---------------------------------------------------------------------------
kubeconfig: ## Point kubectl at the cluster
	aws eks update-kubeconfig --name $(CLUSTER) --region $(REGION)

seed-image: ## Build & push the initial :latest image so Argo CD has something to pull
	./scripts/push-to-ecr.sh $(REGION) $(PROJECT)-ecr latest

# ---------------------------------------------------------------------------
# Access helpers
# ---------------------------------------------------------------------------
jenkins-url: ## Print the Jenkins UI URL
	@echo "http://$$(kubectl -n $(JENKINS_NS) get svc jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/"

jenkins-password: ## Print the Jenkins admin password
	@kubectl -n $(JENKINS_NS) get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d; echo

argocd-url: ## Print the Argo CD UI URL
	@echo "http://$$(kubectl -n $(ARGOCD_NS) get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/"

argocd-password: ## Print the Argo CD initial admin password (user: admin)
	@kubectl -n $(ARGOCD_NS) get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

app-url: ## Print the Dealsbe app URL (once Argo CD has synced it)
	@echo "http://$$(kubectl -n $(APP_NS) get svc $(APP) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/"

argocd-app: ## Show the Argo CD Application sync/health status
	kubectl -n $(ARGOCD_NS) get application $(APP) -o wide

status: ## Show pods across jenkins, argocd and the app namespace
	@echo "== jenkins ==";  kubectl -n $(JENKINS_NS) get pods,svc
	@echo "== argocd ==";   kubectl -n $(ARGOCD_NS) get pods,svc
	@echo "== $(APP_NS) =="; kubectl -n $(APP_NS) get pods,svc,hpa

# ---------------------------------------------------------------------------
# Teardown  (mind the order: LoadBalancers before the VPC, backend last)
# ---------------------------------------------------------------------------
destroy: ## Destroy everything safely (prunes the app LB, then infra, then the backend)
	@echo ">> 1/3 Letting Argo CD prune the app (removes its LoadBalancer)..."
	-kubectl -n $(ARGOCD_NS) delete application $(APP) --ignore-not-found --wait --timeout=180s
	@echo ">> 2/3 Destroying platform + infrastructure (keeping the S3 backend)..."
	terraform destroy -auto-approve $(TF_VARS) \
		-target=module.jenkins -target=module.argo_cd \
		-target=helm_release.metrics_server -target=kubernetes_storage_class.gp3 \
		-target=module.eks -target=module.vpc -target=module.ecr
	@echo ">> 3/3 Destroying the S3/DynamoDB backend (state moved local first)..."
	terraform state pull > terraform.tfstate
	terraform init -reconfigure -backend=false -input=false
	terraform destroy -auto-approve $(TF_VARS)
	rm -f terraform.tfstate terraform.tfstate.backup

clean: ## Remove local Terraform working files
	rm -rf .terraform terraform.tfstate terraform.tfstate.backup
