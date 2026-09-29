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

# Run all checks (build + test + lint + vuln)
check: build test lint chart-lint

# Build a snapshot release locally (no push, no tag)
snapshot:
    goreleaser release --snapshot --clean

# Lint + render the Helm chart
chart-lint:
    # Regression: defaultAwsRegion is required (component contract C13).
    # helm lint must fail with empty defaultAwsRegion, showing minLength validation error.
    bash -c 'helm lint charts/amazon-eks-pod-identity-webhook 2>&1 | grep -q "minLength" && exit 0 || exit 1'
    # Regression: lint succeeds with a valid region set.
    helm lint charts/amazon-eks-pod-identity-webhook \
        --set config.defaultAwsRegion=eu-example-1
    # Regression: render succeeds with a valid region set.
    helm template webhook charts/amazon-eks-pod-identity-webhook \
        --set config.defaultAwsRegion=eu-example-1 >/dev/null
    # Regression: non-empty serviceAccount.annotations must render and the
    # rendered ServiceAccount must carry them (tpl argument-order bug, fixed
    # in v1.0.9 — `toYaml . | tpl .` passed tpl its arguments backwards).
    helm template webhook charts/amazon-eks-pod-identity-webhook \
        --set config.defaultAwsRegion=eu-example-1 \
        --set serviceAccount.annotations.chart-lint-check=ok \
        --show-only templates/serviceaccount.yaml \
        | grep -q 'chart-lint-check: ok'

# Package Helm chart locally
helm-package:
    helm package charts/amazon-eks-pod-identity-webhook --destination dist/
