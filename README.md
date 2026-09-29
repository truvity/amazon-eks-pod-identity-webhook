# Amazon EKS Pod Identity Webhook (Truvity Fork)

[![CI](https://github.com/truvity/amazon-eks-pod-identity-webhook/actions/workflows/ci.yaml/badge.svg)](https://github.com/truvity/amazon-eks-pod-identity-webhook/actions/workflows/ci.yaml)
[![Release](https://github.com/truvity/amazon-eks-pod-identity-webhook/actions/workflows/release.yaml/badge.svg)](https://github.com/truvity/amazon-eks-pod-identity-webhook/actions/workflows/release.yaml)
[![Go Report Card](https://goreportcard.com/badge/github.com/aws/amazon-eks-pod-identity-webhook)](https://goreportcard.com/report/github.com/aws/amazon-eks-pod-identity-webhook)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Fork of [aws/amazon-eks-pod-identity-webhook](https://github.com/aws/amazon-eks-pod-identity-webhook) with Kubernetes 1.35+ compatibility.

| Artifact | Location |
|----------|----------|
| Container image | `ghcr.io/truvity/amazon-eks-pod-identity-webhook/webhook:<tag>` |
| Helm chart | `oci://ghcr.io/truvity/charts/amazon-eks-pod-identity-webhook:<version>` |
| Binary (linux/amd64) | GitHub Release tarball |
| Binary (linux/arm64) | GitHub Release tarball |

## Who it is for

Anyone running Kubernetes 1.35 or later — on EKS or elsewhere — who wants a
Pod to get short-lived AWS credentials without a node-wide IAM role, and
whose cluster only serves the `admission/v1` API (1.35 removed
`admission/v1beta1`, which is what stops upstream's own binary working
here; see "Why This Fork Exists" below). `cert-manager` should already be
running, since the default `pki.certManager.enabled: true` path asks it
for the webhook's serving certificate — or supply `pki.existingSecret`
and skip that dependency.

It deliberately does not install an identity provider: the webhook only
mutates a Pod to add a projected token volume and points it at whatever
audience `config.tokenAudience` names. Trusting that token — an OIDC
provider, an STS-compatible broker on a non-AWS cluster — is the
platform's problem, never this chart's.

## The model

Three things, and how they relate:

- A **`MutatingWebhookConfiguration`** intercepts every Pod create (and,
  optionally, update) and asks this webhook whether to patch it.
- The webhook reads the Pod's **ServiceAccount annotation**
  (`eks.amazonaws.com/role-arn` by default — the prefix is
  `config.annotationPrefix`) and, when present, injects a projected
  service-account-token volume plus `AWS_ROLE_ARN` /
  `AWS_WEB_IDENTITY_TOKEN_FILE` environment variables into every
  container in the Pod.
- The workload never sees long-lived credentials: it reads the projected
  **token** from `config.tokenMountPath` and exchanges it itself, against
  whatever endpoint honours the `config.tokenAudience` it was issued
  for — the same shape as EKS Pod Identity / IRSA, portable to any
  Kubernetes 1.35+ cluster.

## Why This Fork Exists

The upstream webhook uses `admission/v1beta1` for its mutating admission handler. Kubernetes 1.35 removed `v1beta1` admission API support entirely — only `v1` is served. On K8s 1.35+ clusters, the upstream webhook binary returns responses the API server cannot parse, causing silent failures (`failurePolicy: Ignore`).

EKS manages this internally with a patched control-plane version. No open-source fork had fixed this.

This fork fixes the webhook binary to use `admission/v1`.

## Install and a worked example

`config.defaultAwsRegion` has no default (component contract rule C13:
estate facts are inputs, never defaults) — every install must set it
explicitly, or the chart refuses to render:

```bash
helm install webhook oci://ghcr.io/truvity/charts/amazon-eks-pod-identity-webhook \
  --version 2.0.0 --set config.defaultAwsRegion=eu-example-1
```

A values file with neutral placeholders that renders as written — a
region name (`eu-example-1`), the STS audience the token is minted for,
and pointing the webhook at a `ClusterIssuer` cert-manager already has
(the chart's own default provisions a self-signed one; this shows the
"bring your own issuer" path):

```yaml
# webhook-values.yaml
config:
  defaultAwsRegion: eu-example-1
  tokenAudience: sts.amazonaws.com
pki:
  certManager:
    existingIssuer:
      enabled: true
      kind: ClusterIssuer
      name: selfsigned
```

```bash
helm install webhook oci://ghcr.io/truvity/charts/amazon-eks-pod-identity-webhook \
  --version 2.0.0 --values webhook-values.yaml
```

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

## Version Convention

Tags are plain semver (`vX.Y.Z`, e.g. `v1.0.7`) and no longer encode the upstream version they were built from — that scheme (`v{upstream_version}-truvity.{patch}`) was retired at `v1.0.0` (2026-08-27) when the fork adopted the estate-wide release shape (`charts/` layout, shared workflows). `hack/UPSTREAM_VERSION` tracks the upstream release a sync last merged; it is not reflected in the tag. The container image and Helm chart are released from the same tag.

## Consumers

- **A second, non-AWS estate** — deploys the Helm chart (`ghcr.io/truvity/charts/amazon-eks-pod-identity-webhook`) as the `pod-identity-webhook` Argo CD Application, to give IRSA-style AWS credentials to any pod on Talos, the way EKS gives it natively.

## Neighbours

- **[truvity/policy](https://github.com/truvity/policy)** — the component contract this repository is held to (chart layout, versioning, CI recipes) lives at `docs/contracts/component.md`.
- **[truvity/ci-workflows](https://github.com/truvity/ci-workflows)** — the only external workflow this repository pins; it runs `check`, `release-public`, `auto-release` and `security` here.

## Documentation

- [CHANGELOG.md](CHANGELOG.md) — one heading per tag.
- [charts/amazon-eks-pod-identity-webhook/README.md](charts/amazon-eks-pod-identity-webhook/README.md) — the full values reference, generated from `values.yaml`'s comments.
- [SELF_HOSTED_SETUP.md](SELF_HOSTED_SETUP.md) — the projected-token signing keypair a self-managed (non-EKS) cluster needs, upstream's own setup guide.
- [CONTRIBUTING.md](CONTRIBUTING.md) — how to file an issue or a pull request.

## The rule that makes this repository public

This repository is public, so nothing it commits or renders may name a
Truvity particular — an account ID, a real cluster hostname, an internal
domain. `hack/leak-canary.sh` enforces this mechanically: it scans every
tracked file for those shapes, and `just check` runs it before anything
is considered green (component contract
[C4](https://github.com/truvity/policy/blob/master/docs/contracts/component.md#c4-the-leak-canary-is-in-the-gate)).
This repository's own subject matter — AWS ARNs, Kubernetes
`ServiceAccount`-token mount paths — is not itself the shape the canary
bans; its header names each place that mechanism is allowed to look like
one, and why.

## Status

- **Upstream sync:** last merged `aws/amazon-eks-pod-identity-webhook@master` through commit [`81bcb64`](https://github.com/aws/amazon-eks-pod-identity-webhook/commit/81bcb64a91e08b9de60c9d8f9df299f57075b09f) (Go 1.26.7 bump) on 2026-09-29. Upstream's latest tagged release remains `v0.6.17`; the single commit past it is a toolchain bump the fork had already matched independently.
- **Kubernetes 1.36 compatibility (checked 2026-09-29):** resolved, and has been since `v0.6.16-truvity.1` (2026-05-22). The webhook's admission handler was migrated from the removed `admission/v1beta1` review payload to `admission/v1` (see "Why This Fork Exists" above), and `k8s.io/client-go`/`k8s.io/api`/`k8s.io/apimachinery` are tracked on the `v0.36.x` line, the Kubernetes 1.36 family — client-go's own skew policy additionally covers apiserver 1.35 and 1.37. `admissionregistration.k8s.io/v1` (the `MutatingWebhookConfiguration` API this chart ships) has been stable since Kubernetes 1.16 and nothing in the Kubernetes 1.36 changelog removes or changes it, `certificates.k8s.io`, or the admission review path. No further code change was needed for 1.36. A second, non-AWS estate runs this chart against a live Kubernetes 1.36.4 cluster with no reported incompatibility.
- **Chart conformance:** golden renders live under `tests/golden/amazon-eks-pod-identity-webhook/`, and `tests/invalid/amazon-eks-pod-identity-webhook/` proves `values.schema.json` refuses an unknown key; `just chart-lint` checks both on every change.

## Development

```bash
devbox shell          # activate dev environment
just build            # build webhook binary
just test             # run unit tests
just lint             # run linter (golangci-lint)
just vuln             # govulncheck (not part of check — see CI/CD above)
just chart-lint       # lint the chart, diff it against its golden, prove tests/invalid/ is refused
just golden           # regenerate tests/golden/amazon-eks-pod-identity-webhook/ after a template change
just leak-canary      # scan tracked files for particulars
just check            # build + test + lint + chart-lint + leak-canary (what CI's required context runs)
just snapshot         # local GoReleaser snapshot (image + binary)
```

## Syncing With Upstream

```bash
git remote add upstream https://github.com/aws/amazon-eks-pod-identity-webhook.git  # once
git fetch upstream
git log --oneline $(git merge-base origin/master upstream/master)..upstream/master  # new commits
git merge upstream/master                          # merge, never rebase — the fork's patches stay additive
just check                                         # verify build + test + lint + chart-lint + leak-canary
```

## Releasing

Automated release is armed (`vars.AUTO_RELEASE=true`): once renovate's
automerged bumps move `master` past the latest tag, the shared workflow
cuts the next patch on its Monday cron — or immediately, when the merged
pull request carries renovate's `security` label. Every first release,
minor and major version is a person's tag; automation only ever cuts a
patch. A push of a `v*` tag triggers `.github/workflows/release.yaml`,
the shared `release-public.yaml`: it builds the image and binaries with
GoReleaser + ko and pushes the Helm chart to GHCR OCI from that same tag.

## Licence

Apache License 2.0 — same as upstream. As a derivative work of an
Apache-2.0 project, this fork cannot unilaterally relicense itself to
something else; `.github/policy-conformance.yaml` names that exception
against the component contract's [C9](https://github.com/truvity/policy/blob/master/docs/contracts/component.md#c9-the-licence-is-mit-at-the-root).
