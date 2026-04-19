# Amazon EKS Pod Identity Webhook (Truvity Fork)

Fork of [aws/amazon-eks-pod-identity-webhook](https://github.com/aws/amazon-eks-pod-identity-webhook) with Kubernetes 1.35+ compatibility.

## Why This Fork Exists

The upstream webhook uses `admission/v1beta1` for its mutating admission handler. Kubernetes 1.35 removed `v1beta1` admission API support entirely — only `v1` is served. On K8s 1.35+ clusters, the upstream webhook binary returns responses the API server cannot parse, causing silent failures (`failurePolicy: Ignore`).

EKS manages this internally with a patched control-plane version. No open-source fork had fixed this. The [jkroepke Helm chart](https://github.com/jkroepke/helm-charts/tree/main/charts/amazon-eks-pod-identity-webhook) also hardcodes `admissionReviewVersions: ["v1beta1"]` in its MutatingWebhookConfiguration template.

This fork fixes both the webhook binary and the Helm chart.

## Changes From Upstream

**Webhook binary (`pkg/handler/handler.go`):**
- Import `k8s.io/api/admission/v1` instead of `v1beta1`
- Import `admissionregistrationv1` instead of `v1beta1`
- Register `admissionv1` scheme for the deserializer
- Set `TypeMeta` (APIVersion + Kind) on `AdmissionReview` responses — required by K8s v1 API server

**Helm chart (`chart/`):**
- Forked from jkroepke chart v2.6.2
- `admissionReviewVersions: ["v1"]` in `mutatingwebhook.yaml`
- Default image points to `ghcr.io/truvity/amazon-eks-pod-identity-webhook`

**CI/CD:**
- GitHub Actions: build, test, govulncheck, Trivy scanning, Helm lint
- Release on tag: multi-arch image (amd64/arm64) + OCI Helm chart to GHCR
- Dependabot with auto-merge for patch/minor updates
- All actions pinned to commit SHAs

## Artifacts

| Artifact | Location |
|----------|----------|
| Container image | `ghcr.io/truvity/amazon-eks-pod-identity-webhook:<tag>` |
| Helm chart (OCI) | `oci://ghcr.io/truvity/amazon-eks-pod-identity-webhook` |

## Installation on Self-Hosted AWS Kubernetes 1.35+

### Prerequisites

- Kubernetes 1.35+ cluster (Talos, kubeadm, or any self-hosted distribution)
- cert-manager installed (for webhook TLS certificates)
- OIDC provider configured for IRSA ([setup guide](https://github.com/aws/amazon-eks-pod-identity-webhook/blob/master/SELF_HOSTED_SETUP.md))
- JWKS published to a public S3 bucket

### Install via Helm (OCI)

```bash
# Add the chart from GHCR OCI registry
helm install pod-identity-webhook \
  oci://ghcr.io/truvity/amazon-eks-pod-identity-webhook \
  --namespace kube-system \
  --set config.defaultAwsRegion=eu-central-1 \
  --set config.tokenAudience=sts.amazonaws.com \
  --set config.stsRegionalEndpoint=true \
  --set pki.certManager.enabled=true \
  --set replicaCount=2
```

### Install via Helm (values file)

```yaml
# pod-identity-webhook-values.yaml
image:
  registry: ghcr.io
  repository: truvity/amazon-eks-pod-identity-webhook
  tag: "v0.5.7-truvity.5"  # or latest release tag

config:
  defaultAwsRegion: eu-central-1
  tokenAudience: sts.amazonaws.com
  stsRegionalEndpoint: true
  ports:
    webhook: 443

pki:
  certManager:
    enabled: true

replicaCount: 2
```

```bash
helm install pod-identity-webhook \
  oci://ghcr.io/truvity/amazon-eks-pod-identity-webhook \
  --namespace kube-system \
  -f pod-identity-webhook-values.yaml
```

### Verify

```bash
# Check admissionReviewVersions is v1
kubectl get mutatingwebhookconfiguration pod-identity-webhook \
  -o jsonpath='{.webhooks[0].admissionReviewVersions}'
# Expected: ["v1"]

# Check the image
kubectl -n kube-system get deploy pod-identity-webhook \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: ghcr.io/truvity/amazon-eks-pod-identity-webhook:<tag>

# Test IRSA injection (create a pod with an annotated ServiceAccount)
kubectl -n <namespace> get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.volumes[*].name}{"\n"}{end}' \
  | grep aws-iam-token
```

## Version Convention

Tags follow `v{upstream_version}-truvity.{patch}` (e.g., `v0.5.7-truvity.5`). The upstream version tracks the base commit from `aws/amazon-eks-pod-identity-webhook`. The truvity patch number increments with each release from this fork.

## Development

```bash
# Prerequisites: devbox (https://www.jetify.com/devbox)
# devbox provides Go, ko, govulncheck

# Build
go build ./...

# Test
go test ./...

# Vulnerability scan
govulncheck ./...

# Lint chart
helm lint chart/

# Build image locally
make ghcr-build TAG=dev

# Build and push image
make ghcr-push TAG=v0.5.7-truvity.5
```

## License

Apache License 2.0 — same as upstream.
