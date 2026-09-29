# Development commands for amazon-eks-pod-identity-webhook

# Disable go.work (parent workspace interferes with standalone module builds)
export GOWORK := "off"

# Format all Go files (gofmt + goimports via golangci-lint)
fmt:
    golangci-lint fmt ./...

# Build the webhook binary
build: fmt
    go build -o bin/webhook -ldflags="-s -w" ./cmd/webhook

# Run unit tests
test:
    go test ./... -coverprofile=coverage.out

# Run linters
lint:
    golangci-lint run ./...

# Run Go vulnerability check
vuln:
    govulncheck ./...

# Run go mod tidy
tidy:
    go mod tidy

# Clean build artifacts
clean:
    rm -rf bin/ dist/ coverage.out

# Run all checks (build + test + lint + chart-lint + leak-canary; vuln has
# its own schedule in security.yaml so a new CVE can't turn this red)
check: build test lint chart-lint leak-canary

# Build a snapshot release locally (no push, no tag)
snapshot:
    goreleaser release --snapshot --clean

# Lint + render the Helm chart against its golden, and prove every fixture
# under tests/invalid/ is refused by values.schema.json (component contract
# C3 — a reviewer sees what a change did to the output, and a refusal that
# stops working fails the gate rather than going quiet).
chart-lint:
    #!/usr/bin/env bash
    set -euo pipefail
    # Regression: defaultAwsRegion is required (component contract C13).
    # helm lint must fail with empty defaultAwsRegion, showing minLength validation error.
    # (Captured via command substitution, not a `helm lint | grep` pipe —
    # under `pipefail`, helm lint's own non-zero exit would fail the `if`
    # even when grep found its match.)
    if lint_out=$(helm lint charts/amazon-eks-pod-identity-webhook 2>&1); then
        echo "ERROR: amazon-eks-pod-identity-webhook accepted an empty config.defaultAwsRegion" >&2
        exit 1
    elif ! grep -q "minLength" <<<"$lint_out"; then
        echo "ERROR: helm lint on an empty config.defaultAwsRegion failed for a reason other than minLength:" >&2
        echo "$lint_out" >&2
        exit 1
    fi
    echo "OK: empty config.defaultAwsRegion is correctly refused (minLength)"
    # Regression: lint succeeds with a valid region set.
    helm lint charts/amazon-eks-pod-identity-webhook \
        --values tests/cases/amazon-eks-pod-identity-webhook/default.yaml
    # Regression: non-empty serviceAccount.annotations must render and the
    # rendered ServiceAccount must carry them (tpl argument-order bug, fixed
    # in v1.0.9 — `toYaml . | tpl .` passed tpl its arguments backwards).
    helm template webhook charts/amazon-eks-pod-identity-webhook \
        --values tests/cases/amazon-eks-pod-identity-webhook/default.yaml \
        --set serviceAccount.annotations.chart-lint-check=ok \
        --show-only templates/serviceaccount.yaml \
        | grep -q 'chart-lint-check: ok'
    # Golden: diff the default render (region set via tests/cases, nothing
    # else) against its recorded output — a reviewer sees what a change did
    # to the rendered manifests (component contract C3).
    diff -u tests/golden/amazon-eks-pod-identity-webhook/default.yaml \
        <(helm template webhook charts/amazon-eks-pod-identity-webhook \
            --values tests/cases/amazon-eks-pod-identity-webhook/default.yaml)
    # Every fixture under tests/invalid/ must be refused by values.schema.json.
    for fixture in tests/invalid/amazon-eks-pod-identity-webhook/*; do
        if helm template webhook charts/amazon-eks-pod-identity-webhook --values "$fixture" >/dev/null 2>&1; then
            echo "ERROR: amazon-eks-pod-identity-webhook accepted $fixture — values.schema.json not enforced" >&2
            exit 1
        fi
    done

# Regenerate the golden render under tests/golden/amazon-eks-pod-identity-webhook/ — review the diff.
golden:
    helm template webhook charts/amazon-eks-pod-identity-webhook \
        --values tests/cases/amazon-eks-pod-identity-webhook/default.yaml \
        >tests/golden/amazon-eks-pod-identity-webhook/default.yaml

# Package Helm chart locally
helm-package:
    helm package charts/amazon-eks-pod-identity-webhook --destination dist/

# Scan tracked files for particulars that don't belong in a public repo
# (component contract C4).
leak-canary:
    bash hack/leak-canary.sh
