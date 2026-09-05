# Pipeline Templates

Reusable CI/CD building blocks for application pipelines.

## Trivy SBOM Upload To Dependency-Track

This template generates a CycloneDX SBOM with Trivy and uploads it to Dependency-Track.

Use the composite action directly from an application pipeline:

```yaml
uses: africa-prudential/ap-infra/pipeline-templates/steps/trivy-dependency-track@main
```

You do not need to checkout this template repository. GitHub Actions fetches the action from `africa-prudential/ap-infra` automatically.

## GitOps Image Update For Argo CD

This template updates a Kubernetes Deployment image in the GitOps repository and
pushes the change to the branch watched by Argo CD.

Use this instead of `kubectl apply` from application pipelines:

```yaml
deploy-gitops:
  name: Update GitOps image tag
  runs-on: ubuntu-latest
  needs: build-and-push

  steps:
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Resolve ECR registry
      id: ecr
      run: |
        account_id="$(aws sts get-caller-identity --query Account --output text)"
        echo "registry=${account_id}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com" >> "$GITHUB_OUTPUT"

    - name: Update GitOps manifest
      uses: africa-prudential/ap-infra/pipeline-templates/steps/gitops-update-image@main
      with:
        gitops-repository: africa-prudential/greenpole-gitops
        gitops-ref: main
        gitops-token: ${{ secrets.GITOPS_REPO_TOKEN }}
        gitops-path: prod/services/sabi-vest/invearn2coreapi
        image-registry: ${{ steps.ecr.outputs.registry }}
        image-repository: ${{ env.ECR_REPOSITORY }}
        image-tag: ${{ env.IMAGE_TAG }}
        deployment-name: invearn2coreapi
        container-name: invearn2coreapi
```

The `gitops-path` can be either a single manifest file or a directory. If it is
a directory, the action searches all `.yaml` and `.yml` files under it.

The GitOps token must have contents read/write access to the GitOps repository.
For a fine-grained PAT, grant:

```text
Repository permissions -> Contents: Read and write
```

The action updates this field in matching Deployment manifests:

```yaml
spec:
  template:
    spec:
      containers:
        - name: invearn2coreapi
          image: 123456789012.dkr.ecr.eu-west-2.amazonaws.com/invearn/invearn2coreapi:<tag>
```

You can also pass the complete image directly:

```yaml
with:
  image-uri: 123456789012.dkr.ecr.eu-west-2.amazonaws.com/invearn/invearn2coreapi:${{ github.sha }}
```

If the application pipeline fails with:

```text
Unable to resolve action `africa-prudential/ap-infra`, repository not found
```

check these first:

1. The `ap-infra` repository has been pushed to GitHub with `pipeline-templates/steps/trivy-dependency-track/action.yml` on the referenced branch.
2. The application repository is allowed to use actions from `africa-prudential/ap-infra`.
3. If `ap-infra` is private, enable access in `ap-infra` under **Settings > Actions > General > Access**, or use the fallback checkout pattern below.

Private repository fallback:

```yaml
jobs:
  trivy-sbom:
    name: Trivy SBOM Upload
    runs-on: ubuntu-latest

    steps:
      - name: Checkout app
        uses: actions/checkout@v4

      - name: Checkout pipeline templates
        uses: actions/checkout@v4
        with:
          repository: africa-prudential/ap-infra
          ref: main
          path: ap-infra-templates
          token: ${{ secrets.PIPELINE_TEMPLATES_TOKEN }}

      - name: Generate and upload SBOM
        uses: ./ap-infra-templates/pipeline-templates/steps/trivy-dependency-track
        with:
          scan-type: fs
          scan-ref: .
          project-name: ${{ github.event.repository.name }}
          project-version: ${{ github.sha }}
          parent-name: greenpole
          parent-version: "1"
          dependency-track-url: https://dependency-track-api.mygreenpole.com
          dependency-track-api-key: ${{ secrets.DEPENDENCY_TRACK_API_KEY }}
```

`PIPELINE_TEMPLATES_TOKEN` should be a fine-grained PAT or GitHub App token with read access to `africa-prudential/ap-infra`.

## Prerequisites

The application repository or organization must have this secret:

```text
DEPENDENCY_TRACK_API_KEY
```

The API key needs Dependency-Track permission to upload BOMs. If `auto-create` is enabled, it also needs permission to create projects.

Create the parent projects in Dependency-Track before uploading child projects:

```text
greenpole / version 1
sabivest / version 1
```

If you want separate parent versions per environment, create those versions in Dependency-Track and pass the matching value from the pipeline:

```text
greenpole / version develop
greenpole / version uat
greenpole / version prod
sabivest / version develop
sabivest / version uat
sabivest / version prod
```

Example:

```yaml
parent-name: sabivest
parent-version: develop
```

## Source Scan

```yaml
name: CI

on:
  push:
    branches:
      - main

jobs:
  trivy-sbom:
    name: Trivy SBOM Upload
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Generate and upload SBOM
        uses: africa-prudential/ap-infra/pipeline-templates/steps/trivy-dependency-track@main
        with:
          scan-type: fs
          scan-ref: .
          project-name: my-service
          project-version: ${{ github.sha }}
          parent-name: greenpole
          parent-version: "1"
          dependency-track-url: https://dependency-track-api.mygreenpole.com
          dependency-track-api-key: ${{ secrets.DEPENDENCY_TRACK_API_KEY }}
```

## Java And Maven Projects

For Java projects, prepare and cache Maven dependencies before running Trivy. Without this, Trivy may query Maven Central directly and fail with `429 Too Many Requests` on GitHub-hosted runners.

```yaml
jobs:
  trivy-sbom:
    name: Trivy SBOM Upload
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
          cache: maven

      - name: Resolve Maven dependencies
        run: mvn -B -DskipTests dependency:go-offline

      - name: Generate and upload SBOM
        uses: africa-prudential/ap-infra/pipeline-templates/steps/trivy-dependency-track@main
        with:
          scan-type: fs
          scan-ref: .
          project-name: ${{ github.event.repository.name }}
          project-version: ${{ github.sha }}
          parent-name: sabivest
          parent-version: develop
          dependency-track-url: https://dependency-track-api.mygreenpole.com
          dependency-track-api-key: ${{ secrets.DEPENDENCY_TRACK_API_KEY }}
```

## .NET And NuGet Projects

Trivy does not resolve NuGet dependencies directly from normal
`PackageReference` entries in `.csproj` files. Generate `packages.lock.json`
files before scanning so Trivy can include direct and transitive dependencies.

```yaml
jobs:
  trivy-sbom:
    name: Trivy SBOM Upload
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "8.0.x"

      - name: Restore dependencies and generate NuGet lock files
        run: dotnet restore --use-lock-file

      - name: Generate and upload SBOM
        uses: africa-prudential/ap-infra/pipeline-templates/steps/trivy-dependency-track@main
        with:
          scan-type: fs
          scan-ref: .
          project-name: ${{ github.event.repository.name }}
          project-version: ${{ github.sha }}
          parent-name: Sabivest
          parent-version: develop
          dependency-track-url: https://dependency-track-api.mygreenpole.com
          dependency-track-api-key: ${{ secrets.DEPENDENCY_TRACK_API_KEY }}
```

Prefer committing the generated `packages.lock.json` files and using locked
restore in CI:

```yaml
- name: Restore dependencies
  run: dotnet restore --locked-mode
```

## Node.js Projects Without A Lock File

Trivy needs a dependency lock file to resolve npm dependencies. If the
repository does not yet contain `package-lock.json`, generate one without
running lifecycle scripts before the scan:

```yaml
jobs:
  trivy-sbom:
    name: Trivy SBOM Upload
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: "20.x"

      - name: Generate lock file
        run: npm install --package-lock-only --ignore-scripts

      - name: Generate and upload SBOM
        uses: africa-prudential/ap-infra/pipeline-templates/steps/trivy-dependency-track@main
        with:
          scan-type: fs
          scan-ref: .
          project-name: ${{ github.event.repository.name }}
          project-version: ${{ github.sha }}
          parent-name: Sabivest
          parent-version: develop
          dependency-track-url: https://dependency-track-api.mygreenpole.com
          dependency-track-api-key: ${{ secrets.DEPENDENCY_TRACK_API_KEY }}
```

Prefer generating and committing `package-lock.json` during development. Once
it is committed, use `npm ci` in CI instead of generating a new dependency
resolution on every run.

## Sabivest Parent

```yaml
jobs:
  trivy-sbom:
    name: Trivy SBOM Upload
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Generate and upload SBOM
        uses: africa-prudential/ap-infra/pipeline-templates/steps/trivy-dependency-track@main
        with:
          scan-type: fs
          scan-ref: .
          project-name: ${{ github.event.repository.name }}
          project-version: ${{ github.sha }}
          parent-name: sabivest
          parent-version: "1"
          dependency-track-url: https://dependency-track-api.mygreenpole.com
          dependency-track-api-key: ${{ secrets.DEPENDENCY_TRACK_API_KEY }}
```

## Image Scan

```yaml
jobs:
  trivy-sbom:
    name: Trivy Image SBOM Upload
    runs-on: ubuntu-latest

    steps:
      - name: Generate and upload image SBOM
        uses: africa-prudential/ap-infra/pipeline-templates/steps/trivy-dependency-track@main
        with:
          scan-type: image
          scan-ref: ghcr.io/my-org/my-service:${{ github.sha }}
          project-name: my-service
          project-version: ${{ github.sha }}
          parent-name: greenpole
          parent-version: "1"
          dependency-track-url: https://dependency-track-api.mygreenpole.com
          dependency-track-api-key: ${{ secrets.DEPENDENCY_TRACK_API_KEY }}
```

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `scan-type` | No | `fs` | Trivy scan type. Use `fs` for source, `image` for container images. |
| `scan-ref` | No | `.` | Path, image reference, repository URL, or rootfs path to scan. |
| `project-name` | Yes | none | Dependency-Track child project name. |
| `project-version` | Yes | none | Dependency-Track child project version. |
| `parent-name` | No | empty | Dependency-Track parent project name, for example `greenpole` or `sabivest`. |
| `parent-version` | Required when `parent-name` is set | empty | Parent project version, for example `1`. |
| `dependency-track-url` | Yes | none | Dependency-Track API base URL. |
| `dependency-track-api-key` | Yes | none | API key used for BOM upload. |
| `bom-file` | No | `trivy-sbom.cdx.json` | Generated SBOM file path. |
| `cyclonedx-spec-version` | No | `1.6` | CycloneDX `specVersion` written before upload. Dependency-Track 5.0.0 rejects Trivy's current `1.7` output. |
| `upload-artifact` | No | `true` | Upload the generated SBOM as a GitHub Actions artifact. |
| `artifact-name` | No | `trivy-cyclonedx-sbom` | Artifact name for the generated SBOM. |
| `auto-create` | No | `true` | Auto-create the Dependency-Track child project if it does not exist. |
| `fail-on-upload-error` | No | `true` | Fail the pipeline if Dependency-Track upload fails. |

## Notes

The action uploads to:

```text
https://dependency-track-api.mygreenpole.com/api/v1/bom
```

Dependency-Track supports creating child projects during BOM upload with `parentName` and `parentVersion`.

Recent Trivy releases generate CycloneDX `specVersion: 1.7`. Dependency-Track 5.0.0 rejects that with `Unrecognized specVersion 1.7`, so the template defaults `cyclonedx-spec-version` to `1.6` before upload.

See `pipeline-templates/jobs/trivy-dependency-track.yml` for a standard job snippet.
