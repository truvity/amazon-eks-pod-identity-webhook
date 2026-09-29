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

**Webhook binary (`pkg/handler/handler.go`, `pkg/cache/debug/debug.go`):**
- Import `k8s.io/api/admission/v1` instead of `v1beta1`
- Import `admissionregistrationv1` instead of `v1beta1`
- Register `admissionv1` scheme for the deserializer
- Set `TypeMeta` (APIVersion + Kind) on `AdmissionReview` responses — required by K8s v1 API server

**Dependencies:**
- `k8s.io/client-go`, `k8s.io/api`, `k8s.io/apimachinery` tracked on the `v0.36.x` line (the Kubernetes 1.36 family; client-go's skew policy also covers apiserver 1.35 and 1.37)
- `go-jose/v4` bumped to v4.1.4 (CVE fix)

**Build:**
- Dockerfile removed — container image built with GoReleaser + ko (`distroless/static:nonroot`)
- Multi-arch (amd64/arm64) image pushed to GHCR

**CI/CD:**
- GitHub Actions call the shared `truvity/ci-workflows`, which fans the Justfile recipes (`build`, `test`, `lint`, `chart-lint`) out as parallel jobs; `vuln` runs separately in `security.yaml` so a new CVE advisory can't turn a pull request red
- Release on tag: GoReleaser (ko image + binary archives) + Helm chart push to GHCR OCI
- Self-hosted Renovate, extending the shared `truvity/ci-workflows` preset, with automerge for non-major updates
- Security workflow: govulncheck + Trivy (weekly + push/PR)
- All actions pinned to commit SHAs

**Removed from upstream:**
- `Dockerfile` (replaced by GoReleaser + ko)
- `Makefile` (replaced by Justfile)
- AWS-specific build/test workflows (replaced with GHCR-based CI)
- Dependabot (replaced by Renovate)

## Artifacts

| Artifact | Location |
|----------|----------|
| Container image | `ghcr.io/truvity/amazon-eks-pod-identity-webhook/webhook:<tag>` |
| Helm chart | `oci://ghcr.io/truvity/charts/amazon-eks-pod-identity-webhook:<version>` |
| Binary (linux/amd64) | GitHub Release tarball |
| Binary (linux/arm64) | GitHub Release tarball |

## Version Convention

Tags are plain semver (`vX.Y.Z`, e.g. `v1.0.7`) and no longer encode the upstream version they were built from — that scheme (`v{upstream_version}-truvity.{patch}`) was retired at `v1.0.0` (2026-08-27) when the fork adopted the estate-wide release shape (`charts/` layout, shared workflows). `hack/UPSTREAM_VERSION` tracks the upstream release a sync last merged; it is not reflected in the tag. The container image and Helm chart are released from the same tag.

## Development

```bash
devbox shell          # activate dev environment
just build            # build webhook binary
just test             # run unit tests
just lint             # run linter (golangci-lint)
just vuln             # govulncheck (not part of check — see CI/CD above)
just check            # build + test + lint + chart-lint (what CI's required context runs)
just snapshot         # local GoReleaser snapshot (image + binary)
just chart-lint       # lint + render the Helm chart
```

## Syncing With Upstream

```bash
git remote add upstream https://github.com/aws/amazon-eks-pod-identity-webhook.git  # once
git fetch upstream
git log --oneline $(git merge-base origin/master upstream/master)..upstream/master  # new commits
git merge upstream/master                          # merge, never rebase — the fork's patches stay additive
just check                                         # verify build + test + lint + chart-lint
```

## Consumers

- **A second, non-AWS estate** — deploys the Helm chart (`ghcr.io/truvity/charts/amazon-eks-pod-identity-webhook`) as the `pod-identity-webhook` Argo CD Application, to give IRSA-style AWS credentials to any pod on Talos, the way EKS gives it natively.

## Neighbours

- **[truvity/policy](https://github.com/truvity/policy)** — the component contract this repository is held to (chart layout, versioning, CI recipes) lives at `docs/contracts/component.md`.
- **[truvity/ci-workflows](https://github.com/truvity/ci-workflows)** — the only external workflow this repository pins; it runs `check`, `release-public`, `auto-release` and `security` here.

## Fork status

- **Upstream sync:** last merged `aws/amazon-eks-pod-identity-webhook@master` through commit [`81bcb64`](https://github.com/aws/amazon-eks-pod-identity-webhook/commit/81bcb64a91e08b9de60c9d8f9df299f57075b09f) (Go 1.26.7 bump) on 2026-09-29. Upstream's latest tagged release remains `v0.6.17`; the single commit past it is a toolchain bump the fork had already matched independently.
- **Kubernetes 1.36 compatibility (checked 2026-09-29):** resolved, and has been since `v0.6.16-truvity.1` (2026-05-22). The webhook's admission handler was migrated from the removed `admission/v1beta1` review payload to `admission/v1` (see "Why This Fork Exists" above), and `k8s.io/client-go`/`k8s.io/api`/`k8s.io/apimachinery` are tracked on the `v0.36.x` line, the Kubernetes 1.36 family — client-go's own skew policy additionally covers apiserver 1.35 and 1.37. `admissionregistration.k8s.io/v1` (the `MutatingWebhookConfiguration` API this chart ships) has been stable since Kubernetes 1.16 and nothing in the Kubernetes 1.36 changelog removes or changes it, `certificates.k8s.io`, or the admission review path. No further code change was needed for 1.36. A second, non-AWS estate runs this chart against a live Kubernetes 1.36.4 cluster with no reported incompatibility.

## License

Apache License 2.0 — same as upstream.
