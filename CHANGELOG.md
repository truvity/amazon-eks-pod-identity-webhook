# Changelog

All notable changes to the Truvity fork of amazon-eks-pod-identity-webhook are documented here.

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
