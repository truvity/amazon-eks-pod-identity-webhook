# Changelog

All notable changes to the Truvity fork of amazon-eks-pod-identity-webhook are documented here.

## [0.6.17-truvity.1] — 2026-07-04

### Changed
- Go toolchain updated to 1.26.4 via devbox (security: CVE-2026-42504 mime quadratic complexity)
- devbox packages updated (govulncheck 1.3.0→1.5.0, just 1.51.0→1.54.0, just-lsp 0.4.5→0.4.7, helm 4.2.0→4.2.2)
- All Go dependencies updated to latest versions:
  - github.com/aws/aws-sdk-go-v2 v1.42.0→v1.42.1
  - github.com/aws/smithy-go v1.27.1→v1.27.3
  - github.com/go-openapi/swag v0.23.0→v0.27.0 (modularized)
  - github.com/prometheus/common v0.67.5→v0.69.0
  - golang.org/x/net v0.55.0→v0.56.0
  - golang.org/x/oauth2 v0.34.0→v0.36.0
  - sigs.k8s.io/structured-merge-diff/v6 v6.3.2→v6.4.0

### Upstream
- Checked upstream aws/amazon-eks-pod-identity-webhook: only new commit is `golang.org/x/net` CVE bump to v0.55.0 (already included in our previous Renovate update, now superseded by v0.56.0)

### Security
- Go 1.26.4 fixes CVE-2026-42504 (mime: quadratic complexity in WordDecoder.DecodeHeader)
- golang.org/x/net v0.56.0 addresses CVE-2026-33814, CVE-2026-39821, CVE-2026-25680/25681/27136/42502/42506
- govulncheck reports no known vulnerabilities in dependency tree

## [0.6.16-truvity.4] — 2026-06-21

### Fixed
- devbox.json: use `kubernetes-helm` package name (not `helm` — segfaulted in CI)
- devbox.json: add `GOEXPERIMENT=jsonv2` env var
- devbox.json: add `gopls`, `just-lsp` packages (matches org repos)

## [0.6.16-truvity.3] — 2026-06-21

### Changed
- **Build: Dockerfile → GoReleaser + ko** — pure ko-based container image on `distroless/static:nonroot`, no Docker-in-Docker, no bootstrapped Go toolchain
- **CI: devbox + Justfile** — single `just check` job (build + test + lint + vuln), matches org-wide pattern
- **Dependency management: Dependabot → Renovate** — self-hosted renovate bot with automerge for non-major updates
- **Security workflow** — separate `security.yaml` with govulncheck + Trivy (weekly + push/PR)
- **Devbox update workflow** — weekly automated devbox package updates
- **golangci-lint** — v2 config with gocritic, gosec, gocyclo, misspell, unparam, nolintlint
- **devbox.json** — added golangci-lint, goreleaser, just, helm
- **Merged upstream** — Go 1.26.4 bump (v0.6.17 tag content)

### Added
- `Justfile` with standard targets (fmt, build, test, lint, vuln, check, snapshot, helm-lint, helm-package)
- `.golangci.yml` (v2 schema, aligned with org standards)
- `.goreleaser.yaml` (ko-based multi-arch image, binary archives, GitHub release)
- `.editorconfig`
- `renovate.json`
- `CHANGELOG.md`
- README badges (CI, Release, Go Report Card, License)
- Devbox-update, Renovate, Security GitHub workflows

### Removed
- `Dockerfile` (replaced by ko)
- `.go-version` (devbox manages Go)
- `.github/dependabot.yml` (replaced by Renovate)
- `dependabot-auto-merge.yaml` workflow

## [0.6.16-truvity.2] — 2026-05-23

### Fixed
- Restored Helm chart and chart release workflow

## [0.6.16-truvity.1] — 2026-05-22

### Added
- **admission/v1 migration** — webhook uses `admission/v1` (upstream uses deprecated `v1beta1` removed in K8s 1.35)
- Set `TypeMeta` (APIVersion + Kind) on `AdmissionReview` responses (required by v1 API server)
- GitHub Actions CI: build, test, govulncheck, Trivy scanning
- Release workflow: multi-arch Docker image to GHCR
- Devbox environment

### Changed
- Dependencies bumped to k8s.io v0.36.1 (Kubernetes 1.36 / Talos 1.13 compatible)
- `go-jose/v4` bumped to v4.1.4 (CVE fix)

### Removed
- AWS-specific build/test workflows
- Makefile (replaced by `go build`)
