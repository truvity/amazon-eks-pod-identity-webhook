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
    helm lint charts/amazon-eks-pod-identity-webhook
    helm template webhook charts/amazon-eks-pod-identity-webhook >/dev/null

# Package Helm chart locally
helm-package:
    helm package charts/amazon-eks-pod-identity-webhook --destination dist/
