# Backstage Golden Path Starter

This directory is a starter content repository for Backstage catalog imports and golden-path templates.

Use it as the seed for the Git repository watched by Backstage and Argo CD. The Terraform module can import existing repositories by adding their `catalog-info.yaml` URLs to `backstage_catalog_locations`.

Suggested first import:

```hcl
backstage_catalog_locations = [
  {
    type   = "url"
    target = "https://github.com/<org>/<repo>/blob/main/catalog-info.yaml"
  }
]
```

For private GitHub repositories, the Backstage module uses the same GitHub PAT passed to Terraform for Argo CD.
