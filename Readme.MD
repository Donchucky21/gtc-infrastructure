Week 13 Project — Production EKS Deployment and Debugging

Project goal

Provision a production-style Amazon EKS platform and deploy a three-tier incident-management application with a custom domain, TLS, persistent storage, rolling releases, secure GitHub Actions access and an observability stack.

The project also demonstrates a structured troubleshooting process for identity, Terraform, Kubernetes storage, Secrets, database connectivity and failed rollouts.

Outcome

EKS cluster provisioned with Terraform in eu-west-2.

Two managed worker nodes running successfully.

Frontend and backend container images stored in Amazon ECR.

GitHub Actions authenticating to AWS through OIDC rather than stored AWS access keys.

Frontend, backend and PostgreSQL running in the incident-portal namespace.

PostgreSQL data stored on an encrypted EBS-backed persistent volume.

Public access through an AWS Application Load Balancer.

Route 53 DNS and ACM TLS enabled for https://incident.starttechapp.uk.

Images tagged with the immutable Git commit SHA.

Kubernetes rolling deployments verified successfully.

Prometheus, Grafana, Loki, Promtail, Tempo and OpenTelemetry running in the cluster.

Frontend, API and database health checks returning successful responses.

Repositories

Repository

Purpose

gtc-infrastructure

Terraform for EKS, networking, IAM, cluster add-ons and monitoring

incident-management-portal

Application source, Dockerfiles, Kubernetes manifests and the EKS CD workflow

Architecture

flowchart TD
    User[User] --> DNS[Route 53 and ACM]
    DNS --> ALB[Application Load Balancer]
    ALB --> Frontend[Frontend Deployment]
    Frontend --> Backend[Backend Deployment]
    Backend --> Database[PostgreSQL StatefulSet]
    Database --> EBS[EBS persistent volume]
    Actions[GitHub Actions with OIDC] --> ECR[Amazon ECR]
    Actions --> EKS[Amazon EKS]
    ECR --> EKS
    EKS --> Frontend
    EKS --> Backend

Technology used

Area

Technology

Infrastructure as Code

Terraform

Cloud platform

AWS

Container orchestration

Amazon EKS / Kubernetes

Container registry

Amazon ECR

CI/CD

GitHub Actions

AWS authentication

GitHub OIDC and IAM roles

Application deployment

Kubernetes manifests and Kustomize

Ingress

AWS Load Balancer Controller

DNS

Route 53 and ExternalDNS

TLS

AWS Certificate Manager

Database

PostgreSQL StatefulSet

Persistent storage

EBS CSI driver and GP3 StorageClass

Metrics

Prometheus and Grafana

Logs

Loki and Promtail

Traces

Tempo and OpenTelemetry Collector

Delivery model

Terraform manages the long-lived platform: VPC networking, EKS, node groups, IAM access, storage integration, ingress integration, DNS integration and observability components.

Application releases are kept outside Terraform state. GitHub Actions builds immutable images, pushes them to ECR and applies the Kubernetes manifests with Kustomize. This separation allows application releases and infrastructure changes to have independent lifecycles.

If an assessment requires application workloads to be created literally by Terraform, Kubernetes resources could instead be managed with kubernetes_manifest. This implementation intentionally uses Terraform for the platform and GitHub Actions/Kustomize for application delivery.

1. Prerequisites

The workstation or CI runner requires:

AWS CLI

Terraform

Docker

kubectl

Helm

Git and GitHub access

An AWS account with sufficient IAM permissions

A Route 53 public hosted zone for starttechapp.uk

An ACM certificate for incident.starttechapp.uk in eu-west-2

Confirm the active AWS identity before making changes:

aws sts get-caller-identity

2. Configure the EKS environment

The final EKS configuration used the following values:

environment         = "prod"
region              = "eu-west-2"
eks_cluster_version = "1.36"
max_nodes           = 4
min_nodes           = 1
desired_size        = 2
zone                = "starttechapp.uk"
vpc_cidr             = "10.16.0.0/16"

The resulting cluster name was:

chucky-infra-prod

The existing Route 53 hosted zone was verified before planning:

aws route53 list-hosted-zones \
  --query "HostedZones[*].[Name,Id]" \
  --output table

3. Configure remote Terraform state

Terraform state was stored remotely in S3 with encryption and state locking enabled. The backend keeps the shared state away from local machines and prevents concurrent workflows from modifying it at the same time.

Example structure:

terraform {
  backend "s3" {
    bucket       = "<terraform-state-bucket>"
    key          = "<eks-state-key>"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }
}

The bucket and key should be unique to the AWS account and environment. They should not be copied blindly from another account.

4. Configure GitHub Actions OIDC

An IAM OIDC provider was configured for:

token.actions.githubusercontent.com

The audience was restricted to:

sts.amazonaws.com

Two IAM roles were used:

Role

Purpose

gtc-terraform-github-actions

Terraform plan/apply from the infrastructure repository

chucky-infra-prod-github-app-deployer

Push images to ECR and deploy the application to EKS

The final trust relationship should restrict access to the correct owner, repository and branch. Example:

{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:Donchucky21/incident-management-portal:ref:refs/heads/main"
    }
  }
}

The workflow requires:

permissions:
  id-token: write
  contents: read

The role ARN was stored in the application repository as the GitHub Actions Secret AWS_ROLE_TO_ASSUME.

5. Validate and deploy the Terraform platform

Run formatting and validation before creating a plan:

terraform fmt -recursive
terraform -chdir=workspaces/eks init
terraform -chdir=workspaces/eks validate
terraform -chdir=workspaces/eks plan

Infrastructure changes followed this workflow:

Create a feature branch.

Modify Terraform modules or environment values.

Run terraform fmt and terraform validate.

Push the branch and open a pull request.

Review the Terraform plan.

Merge the approved change.

Allow the protected GitHub Actions workflow to apply it.

After the EKS apply completed, configure local cluster access:

aws eks update-kubeconfig \
  --region eu-west-2 \
  --name chucky-infra-prod

Verify the nodes:

kubectl get nodes -o wide

6. EKS access and pod identity

EKS access entries were used to give approved IAM users and roles Kubernetes access. This avoids relying only on the legacy aws-auth ConfigMap.

Cluster add-ons that call AWS APIs should use IRSA or EKS Pod Identity with least-privilege IAM policies. Typical examples are:

AWS Load Balancer Controller

ExternalDNS

EBS CSI driver

The application frontend, backend and PostgreSQL pods do not require AWS credentials. GitHub OIDC is separate: it gives the CI/CD workflow temporary AWS credentials and does not place AWS credentials inside application pods.

7. Build and store the application images

Two ECR repositories were used:

incident-portal-frontend
incident-portal-backend

They can be confirmed with:

aws ecr describe-repositories \
  --region eu-west-2 \
  --query "repositories[*].repositoryName" \
  --output table

The CD workflow builds both images and tags them with ${GITHUB_SHA}. Commit-SHA tags are immutable, traceable and make rollbacks safer than deploying only a mutable latest tag.

8. Kubernetes application resources

The application repository contains a kubernetes/ directory with:

Manifest

Purpose

namespace.yaml

Creates the incident-portal namespace

storage-class.yaml

Defines the EBS GP3 StorageClass

postgres.yaml

ConfigMap, Service, PVC and PostgreSQL StatefulSet

backend.yaml

Backend Deployment and Service

frontend.yaml

Frontend Deployment, Service and NGINX configuration

ingress.yaml

ALB ingress, domain and TLS configuration

kustomization.yaml

Renders all application resources together

The manifests were validated with:

kubectl kustomize kubernetes >/dev/null
kubectl apply --dry-run=client --validate=strict -k kubernetes

The second command is important because kubectl kustomize renders YAML but does not fully validate Kubernetes API fields.

9. PostgreSQL persistence

PostgreSQL runs as a StatefulSet and mounts the postgres-data PVC. The final PVC configuration includes the correct StorageClass:

spec:
  storageClassName: incident-portal-gp3
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi

The pod volume refers only to the claim:

volumes:
  - name: postgres-data
    persistentVolumeClaim:
      claimName: postgres-data

The final result was verified with:

kubectl get statefulset,pvc -n incident-portal

The PVC must show Bound before PostgreSQL can start successfully.

10. Manage database credentials

The database password is not committed to Git. It is stored as the GitHub Actions repository Secret:

POSTGRES_PASSWORD

During deployment, the workflow creates or updates the Kubernetes Secret:

kubectl create secret generic postgres-credentials \
  --namespace incident-portal \
  --from-literal=database-name=incident_db \
  --from-literal=database-user=incident_user \
  --from-literal=database-password="$POSTGRES_PASSWORD" \
  --from-literal=database-url="postgresql://incident_user:${POSTGRES_PASSWORD}@postgres:5432/incident_db" \
  --dry-run=client -o yaml | kubectl apply -f -

Secret values must never be printed in logs or stored in screenshots. Key names and byte counts can be checked safely with:

kubectl describe secret postgres-credentials -n incident-portal

11. Support RDS and in-cluster PostgreSQL

The ECS deployment uses RDS with SSL, while the PostgreSQL container inside EKS does not provide SSL by default. The backend therefore makes SSL configurable:

const useSsl = process.env.DB_SSL !== "false";

const pool = new Pool({
  connectionString: cleanDatabaseUrl(process.env.DATABASE_URL),
  ssl: useSsl ? { rejectUnauthorized: false } : false,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

The EKS backend sets:

- name: DB_SSL
  value: "false"

If DB_SSL is absent, SSL remains enabled, preserving the existing ECS/RDS behaviour.

12. Continuous deployment workflow

The application CD workflow performs these stages:

Check out the repository.

Assume the application deployer role through GitHub OIDC.

Authenticate Docker to Amazon ECR.

Build the backend and frontend images.

Tag both images with the Git commit SHA.

Push both images to ECR.

Update kubeconfig for chucky-infra-prod.

Create or update the PostgreSQL Kubernetes Secret.

Replace the IMAGE_TAG placeholders with ${GITHUB_SHA}.

Apply the resources with kubectl apply -k kubernetes.

Wait for the PostgreSQL StatefulSet and application Deployments.

Print the deployed pods, Services and Ingress.

The rollout checks are:

kubectl rollout status statefulset/postgres \
  --namespace incident-portal \
  --timeout=5m

kubectl rollout status deployment/backend \
  --namespace incident-portal \
  --timeout=5m

kubectl rollout status deployment/frontend \
  --namespace incident-portal \
  --timeout=5m

Kubernetes Deployments use a rolling update, allowing the replacement pod to become Ready before the old replica is removed.

13. Ingress, DNS and TLS

The AWS Load Balancer Controller creates an Application Load Balancer from ingress.yaml.

Traffic flow:

incident.starttechapp.uk
        ↓
Route 53 alias record
        ↓
AWS Application Load Balancer with ACM certificate
        ↓
Frontend Service
        ↓
Backend Service for API requests

The ACM certificate must be ISSUED and located in the same region as the ALB (eu-west-2). ExternalDNS manages the Route 53 record from the Ingress hostname annotation.

Verify the Ingress:

kubectl get ingress -n incident-portal
kubectl describe ingress incident-portal -n incident-portal

14. Observability

The monitoring namespace contains:

Prometheus Operator

Prometheus

Grafana

kube-state-metrics

node-exporter

Loki

Promtail

Tempo

OpenTelemetry Collector

Verify the monitoring workloads:

kubectl get pods -n monitoring -o wide

The platform is installed and healthy. Application-specific dashboards, alerts, ServiceMonitors and trace instrumentation are recommended follow-up improvements.

15. Verification

Verify all application resources:

kubectl get pods,services,ingress -n incident-portal
kubectl get pvc -n incident-portal

Expected state:

backend      1/1 Running
frontend     1/1 Running
postgres-0   1/1 Running
postgres-data PVC Bound

Test the public frontend:

curl -I https://incident.starttechapp.uk

Test the backend and database:

curl https://incident.starttechapp.uk/api/health/db

Finally, create a ticket in the web interface and refresh the page. The ticket should remain visible, proving that the full request path and database writes are working.

Troubleshooting record

1. Wrong Route 53 zone

Symptom: The Terraform configuration referenced a domain that did not exist in the personal AWS account.

Diagnosis:

aws route53 list-hosted-zones \
  --query "HostedZones[*].[Name,Id]" \
  --output table

Resolution: Updated the environment value to the existing hosted zone, starttechapp.uk.

Lesson: Discover account-specific resources before reusing Terraform written for another AWS account.

2. GitHub OIDC role assumption failed

Symptom:

Not authorized to perform sts:AssumeRoleWithWebIdentity

Diagnosis: The token audience was correct, but the trust policy subject did not match the repository and branch running the workflow.

Resolution: Updated the IAM role trust relationship to use the correct repository owner, repository and branch. The final trust was restricted to the deployment source rather than allowing every repository.

Lesson: For OIDC errors, compare the token aud and sub claims directly with the IAM trust-policy conditions.

3. Terraform formatting check failed

Symptom: GitHub Actions failed at terraform fmt -check and identified workspaces/eks/backend.tf.

Resolution:

terraform fmt -recursive workspaces/eks modules/eks modules/route53_zone

The formatted file was committed and the pipeline was rerun.

Lesson: Run the same formatting command locally that CI runs remotely.

4. EKS access needed for administrators and CI/CD

Symptom: The cluster existed, but a principal required explicit Kubernetes access.

Resolution: Added approved IAM principal ARNs to the Terraform-managed EKS access entries and verified kubeconfig access.

Lesson: AWS IAM permission to call EKS and Kubernetes RBAC access inside the cluster are related but separate controls.

5. OpenTelemetry deployment failed

Symptom: The monitoring deployment failed because an old OpenTelemetry configuration used a legacy metrics address field.

Problematic configuration:

metrics:
  address: 0.0.0.0:8888

Resolution: Removed the legacy setting and allowed the current chart/collector configuration to supply the supported telemetry reader.

Lesson: Helm chart and application version upgrades can invalidate older configuration keys even when the YAML itself is valid.

6. CD workflow waited indefinitely for the backend

Symptom: The backend remained at Init:0/1 because its init container was waiting for PostgreSQL. No PostgreSQL pod had been created.

Diagnosis:

kubectl get pods -n incident-portal
kubectl get statefulset,pvc -n incident-portal

The PVC was Pending, and the StatefulSet was missing from the applied resources.

Lesson: When an init container is waiting, inspect the dependency rather than repeatedly restarting the application pod.

7. PVC had no StorageClass and the StatefulSet volume was invalid

Symptom: postgres-data remained Pending. The storageClassName was placed incorrectly inside the pod volume definition instead of the PVC.

Resolution: Moved storageClassName: incident-portal-gp3 into the PVC spec and removed it from persistentVolumeClaim under the StatefulSet volume.

The old PVC could not be updated because its storage class is immutable. It was safe to remove because it was still Pending, had never been bound and contained no data:

kubectl delete pvc postgres-data -n incident-portal

The corrected deployment created a new PVC that became Bound.

Lesson: A syntactically valid manifest can still contain invalid Kubernetes API fields. Use strict dry-run validation.

8. PostgreSQL entered CrashLoopBackOff

Symptom:

Database is uninitialized and superuser password is not specified.

Diagnosis:

kubectl logs postgres-0 -n incident-portal --previous
kubectl describe secret postgres-credentials -n incident-portal

The Secret showed:

database-password: 0 bytes

Resolution: Added/updated POSTGRES_PASSWORD as a repository Secret in the application repository and reran the CD workflow.

Lesson: A Kubernetes Secret can exist while containing an empty value. Validate Secret presence and non-zero key size without exposing its contents.

9. Pods did not automatically reload the updated Secret

Symptom: The Kubernetes Secret was corrected, but existing pods still used the environment variables loaded when they were created.

Resolution: Restarted the StatefulSet and backend Deployment:

kubectl rollout restart statefulset/postgres deployment/backend \
  -n incident-portal

Lesson: Environment variables sourced from Secrets are not refreshed in already-running containers. The pod must be recreated.

10. Backend database health check failed because of SSL

Symptom:

Database initialization failed: The server does not support SSL connections

Diagnosis: backend/db.js always forced SSL for the previous ECS/RDS deployment, even though the Kubernetes manifest already set DB_SSL=false.

Resolution: Changed the code to read the DB_SSL environment variable:

const useSsl = process.env.DB_SSL !== "false";
ssl: useSsl ? { rejectUnauthorized: false } : false;

This disabled SSL only for the in-cluster PostgreSQL database while keeping SSL enabled by default for RDS.

Lesson: Environment-specific behaviour must be controlled explicitly rather than hard-coded.

11. Rollout waited for an old backend replica to terminate

Symptom: GitHub Actions reported that one old backend replica was pending termination.

Resolution: Once the new backend passed its database readiness check, Kubernetes completed the rolling update and terminated the old replica automatically.

Lesson: A stuck rolling update is often a readiness problem in the replacement pod. Inspect its logs and probe results before forcing deletion.

12. Node runtime deprecation warning

Symptom: GitHub Actions printed a Node 20 deprecation warning during post-job cleanup.

Result: This was a warning, not a deployment failure. The workflow completed successfully using the runner's newer runtime.

Follow-up: Keep third-party GitHub Actions pinned to supported major versions.

Interview-style debugging playbook

Pod is Pending

kubectl get pod <pod-name> -n incident-portal -o wide
kubectl describe pod <pod-name> -n incident-portal
kubectl get pvc -n incident-portal
kubectl describe pvc <pvc-name> -n incident-portal
kubectl get events -n incident-portal --sort-by=.metadata.creationTimestamp

Check scheduling constraints, insufficient resources, unbound PVCs, StorageClasses, taints and node affinity.

Pod is in CrashLoopBackOff

kubectl logs <pod-name> -n incident-portal
kubectl logs <pod-name> -n incident-portal --previous
kubectl describe pod <pod-name> -n incident-portal

The --previous flag is important because it retrieves the logs from the last crashed container instance.

Pod is stuck in an init container

kubectl get pod <pod-name> -n incident-portal
kubectl logs <pod-name> -n incident-portal -c <init-container-name>
kubectl describe pod <pod-name> -n incident-portal

Identify the dependency being checked by the init container and verify that dependency directly.

Deployment rollout is stuck

kubectl rollout status deployment/backend -n incident-portal
kubectl get pods -n incident-portal
kubectl describe deployment backend -n incident-portal
kubectl logs -n incident-portal deployment/backend --tail=100

If a known-good revision is available, inspect and roll back:

kubectl rollout history deployment/backend -n incident-portal
kubectl rollout undo deployment/backend -n incident-portal

OIDC authentication fails

Check:

The GitHub workflow has id-token: write.

The OIDC provider URL is correct.

The token audience is sts.amazonaws.com.

The trust policy repository owner and name match exactly.

The trust-policy branch or environment matches the workflow trigger.

The role ARN stored in GitHub points to the correct AWS account and role.

Ingress is not reachable

kubectl get ingress -n incident-portal
kubectl describe ingress incident-portal -n incident-portal
kubectl get pods -n kube-system
aws acm list-certificates --region eu-west-2
aws route53 list-resource-record-sets --hosted-zone-id <ZONE_ID>

Check the ALB controller, Ingress annotations, target health, security groups, certificate region/status and DNS record.

Evidence checklist

Create an evidence/ directory in the project repository and use the filenames below. Each screenshot should show the command or console page, the successful result and enough context to identify the environment.

Do not capture AWS access keys, GitHub Secret values, Kubernetes Secret contents, Terraform state contents, kubeconfig tokens or other credentials.

File

Evidence to capture

Suggested command or page

01-project-brief.png

Week 13 brief and deliverables

Project portal

02-terraform-plan.png

Successful reviewed EKS plan

GitHub Actions Terraform plan job

03-terraform-apply.png

Successful infrastructure apply

GitHub Actions Terraform apply job

04-eks-active.png

Cluster name, status and version

AWS EKS console

05-nodes-ready.png

Both worker nodes Ready

kubectl get nodes -o wide

06-oidc-role.png

OIDC provider and restricted role trust

IAM console; redact account ID if desired

07-ecr-images.png

Frontend/backend SHA image tags

ECR console

08-cd-success.png

Successful application workflow

GitHub Actions EKS deployment job

09-application-pods.png

All three workloads 1/1 Running

kubectl get pods -n incident-portal -o wide

10-services-ingress.png

Services and ALB address

kubectl get svc,ingress -n incident-portal

11-pvc-bound.png

EBS-backed claim is Bound

kubectl get pvc -n incident-portal

12-acm-issued.png

Certificate status ISSUED

ACM console in eu-west-2

13-route53-record.png

Application DNS record

Route 53 hosted zone

14-https-response.png

Successful HTTPS response

curl -I https://incident.starttechapp.uk

15-database-health.png

Healthy database response

curl https://incident.starttechapp.uk/api/health/db

16-application-ui.png

Application loaded over HTTPS

Browser with address bar visible

17-ticket-created.png

Ticket visible after refresh

Application UI

18-monitoring-pods.png

Monitoring workloads Running

kubectl get pods -n monitoring -o wide

19-grafana-dashboard.png

EKS metrics dashboard

Grafana

20-rolling-deployment.png

Successful rollout

GitHub Actions rollout step or kubectl rollout status

Debugging evidence

These screenshots demonstrate troubleshooting rather than only the final result:

File

Before state

Resolution evidence

debug-01-oidc-error.png

AssumeRoleWithWebIdentity denied

Successful AWS credentials step

debug-02-fmt-error.png

Terraform formatting failure

Successful formatting check

debug-03-pvc-pending.png

postgres-data Pending

PVC Bound with incident-portal-gp3

debug-04-postgres-password.png

PostgreSQL password error

Secret key has non-zero byte count and pod Running

debug-05-backend-ssl.png

Server does not support SSL

Backend 1/1 Running and DB health successful

debug-06-final-workloads.png

Failed/stuck rollout

All workloads Running and workflow successful

Suggested directory layout:

evidence/
├── 01-project-brief.png
├── 02-terraform-plan.png
├── 03-terraform-apply.png
├── 04-eks-active.png
├── 05-nodes-ready.png
├── 06-oidc-role.png
├── 07-ecr-images.png
├── 08-cd-success.png
├── 09-application-pods.png
├── 10-services-ingress.png
├── 11-pvc-bound.png
├── 12-acm-issued.png
├── 13-route53-record.png
├── 14-https-response.png
├── 15-database-health.png
├── 16-application-ui.png
├── 17-ticket-created.png
├── 18-monitoring-pods.png
├── 19-grafana-dashboard.png
├── 20-rolling-deployment.png
└── debugging/
    ├── debug-01-oidc-error.png
    ├── debug-02-fmt-error.png
    ├── debug-03-pvc-pending.png
    ├── debug-04-postgres-password.png
    ├── debug-05-backend-ssl.png
    └── debug-06-final-workloads.png

After saving the screenshots, add selected evidence to this README using:

![Successful EKS CD workflow](evidence/08-cd-success.png)
![Application workloads running](evidence/09-application-pods.png)
![Application available over HTTPS](evidence/16-application-ui.png)

Recommended screenshot technique

Maximise the terminal or browser window.

Include the command and complete output in the same screenshot.

Keep the cluster name, namespace or AWS region visible where possible.

Use consistent filenames from the checklist.

Crop unrelated desktop content.

Redact identifiers only when necessary, but always hide credentials and Secret values.

Capture both the failure and the successful fix for debugging scenarios.

Remaining production improvements

The project meets the deployment objective, but the following improvements would strengthen a real production implementation:

Add automated PostgreSQL backups or move the production database to RDS.

Add application-specific Prometheus metrics, Grafana dashboards and alerts.

Add alerts for unavailable pods, failed rollouts, high CPU/memory and endpoint failures.

Add a workflow guard that fails immediately if POSTGRES_PASSWORD is empty.

Trigger controlled pod restarts when environment-variable Secrets change.

Add NetworkPolicies and review pod security settings.

Configure Horizontal Pod Autoscalers for stateless services.

Add PodDisruptionBudgets for application availability during maintenance.

Add automated failure diagnostics to the workflow.

Introduce Argo CD if GitOps reconciliation is required.

Add scheduled cost reviews and AWS Budgets alerts.

Cost considerations

The main running costs are:

EKS control plane

EC2 worker nodes

NAT Gateway and data processing

Application Load Balancer

EBS volumes

Route 53 hosted zone and queries

CloudWatch logs and metrics

Monitor these resources and destroy the environment when it is no longer required. Note that a StorageClass with Retain may leave the EBS volume behind after Kubernetes resources are deleted, so retained volumes must be reviewed separately before expecting charges to stop.

Final result

The project successfully provisioned an EKS platform through Terraform and deployed a three-tier application through a secure GitHub Actions CD pipeline. It provides HTTPS access through a custom domain, immutable image tags, rolling releases, persistent database storage and a working observability platform.

The debugging work demonstrated a repeatable process: inspect actual state, read pod logs and events, validate identity claims, correct the smallest faulty configuration, redeploy through version control and verify the result with health checks.