# Amazon EKS Pod Identity Webhook (Truvity Fork)

[![CI](https://github.com/truvity/amazon-eks-pod-identity-webhook/actions/workflows/ci.yaml/badge.svg)](https://github.com/truvity/amazon-eks-pod-identity-webhook/actions/workflows/ci.yaml)
[![Release](https://github.com/truvity/amazon-eks-pod-identity-webhook/actions/workflows/release.yaml/badge.svg)](https://github.com/truvity/amazon-eks-pod-identity-webhook/actions/workflows/release.yaml)
[![Go Report Card](https://goreportcard.com/badge/github.com/aws/amazon-eks-pod-identity-webhook)](https://goreportcard.com/report/github.com/aws/amazon-eks-pod-identity-webhook)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Fork of [aws/amazon-eks-pod-identity-webhook](https://github.com/aws/amazon-eks-pod-identity-webhook) with Kubernetes 1.35+ compatibility.

## Why This Fork Exists

The upstream webhook uses `admission/v1beta1` for its mutating admission handler. Kubernetes 1.35 removed `v1beta1` admission API support entirely — only `v1` is served. On K8s 1.35+ clusters, the upstream webhook binary returns responses the API server cannot parse, causing silent failures (`failurePolicy: Ignore`).

EKS manages this internally with a patched control-plane version. No open-source fork had fixed this.

This fork fixes the webhook binary to use `admission/v1`.

## Changes From Upstream

**Based on:** upstream `master` (post-v0.6.16, includes k8s 1.36 deps, SA cache strip, pod-identity label)

**Webhook binary (`pkg/handler/handler.go`, `pkg/cache/debug/debug.go`):**
- Import `k8s.io/api/admission/v1` instead of `v1beta1`
- Import `admissionregistrationv1` instead of `v1beta1`
- Register `admissionv1` scheme for the deserializer
- Set `TypeMeta` (APIVersion + Kind) on `AdmissionReview` responses — required by K8s v1 API server

**Dependencies:**
- `k8s.io/client-go` v0.36.1 (supports Kubernetes 1.36, compatible with Talos 1.13)
- `go-jose/v4` bumped to v4.1.4 (CVE fix)
- `golang.org/x/crypto` removed (no longer needed)

**CI/CD:**
- GitHub Actions: build, test, govulncheck, Trivy scanning
- Release on tag: multi-arch image (amd64/arm64) to GHCR
- Dependabot with auto-merge for patch/minor updates
- All actions pinned to commit SHAs

**Removed from upstream:**
- AWS-specific build/test workflows (replaced with GHCR-based CI)
- Helm chart (deployed via separate mechanism)
- Makefile (use `go build` directly)

## Artifacts

| Artifact | Location |
|----------|----------|
| Container image | `ghcr.io/truvity/amazon-eks-pod-identity-webhook:<tag>` |
| Helm chart | `oci://ghcr.io/truvity/charts/amazon-eks-pod-identity-webhook:<version>` |
| Binary (linux/amd64) | GitHub Release tarball |
| Binary (linux/arm64) | GitHub Release tarball |

## Version Convention

Tags follow `v{upstream_version}-truvity.{patch}` (e.g., `v0.6.16-truvity.1`). The container image is released from the same tag.

## Development

```bash
devbox shell          # activate dev environment
just build            # build webhook binary
just test             # run unit tests
just lint             # run linter (golangci-lint)
just vuln             # govulncheck
just check            # build + test + lint + vuln (what CI runs)
just snapshot         # local GoReleaser snapshot (image + binary)
just helm-lint        # lint Helm chart
```

## Syncing With Upstream

```bash
git fetch upstream
git log --oneline v0.6.16..upstream/master  # check new commits
# Rebase or cherry-pick, re-apply v1beta1→v1 patch, run tests
```

## License

Apache License 2.0 — same as upstream.
