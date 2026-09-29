#!/usr/bin/env bash
# This repository is public and its history cannot be unpublished — a
# rewrite changes the SHAs but not what was already fetched. So the rule
# ("mechanism only; particulars are caller inputs or org variables") is
# enforced mechanically rather than remembered.
#
# Add a pattern here the first time something new turns out to be a
# particular. Never add an exception without one.
set -uo pipefail

# The 12-digit patterns are anchored on word boundaries. Without them,
# `[0-9]{12}` also matches a 12-digit run that happens to fall inside a
# longer hex string -- and a nixpkgs commit SHA is exactly that. The
# devbox bump to 17de0b976395537756f30a3e78f2f06e5cec89ed contains
# `976395537756`, which failed this canary simultaneously in every repo
# that carries it, for a value that is neither a particular nor secret.
# `\b` keeps every real shape (bare, in an ARN, as an ECR host: each is
# bounded by a non-word character) and drops the hex-embedded ones.
patterns=(
  '\b[0-9]{12}\b'                          # AWS account id
  'arn:aws'                            # any ARN
  '\b[0-9]{12}\.dkr\.ecr\.'              # ECR registry host
  '\.svc\.cluster\.local'              # in-cluster DNS
  '/secrets/'                          # SSM parameter paths
  'truvity-[a-z0-9-]*-(ci-cache|artifacts|state)'   # S3 buckets
  '\.truvity\.(xyz|com|co)'            # internal hostnames
  'glpat-|ghp_|github_pat_'            # tokens, in case of an accident
)

fail=0

# Scan TRACKED FILES ONLY. The point of this canary is to stop particulars
# being committed, so git's index is exactly the right scope -- and a
# recursive walk of the working tree is not. It descended into generated,
# gitignored directories: .devbox/state.json carries a
# `nix_print_dev_env_hash` whose hex contains a 12-digit run, which matched
# the AWS-account-id pattern. That made the canary fail on a clean checkout
# for a value that is neither committed nor secret.
#
# This matters more than a nuisance: a canary that cries wolf is one people
# learn to skip, and this one is what stands between us and publishing
# particulars from a public repo.
mapfile -d '' tracked < <(git ls-files -z)

# Narrowed for THIS repository: a fork of aws/amazon-eks-pod-identity-webhook,
# a project whose subject matter IS AWS ARNs, EKS ServiceAccount tokens and
# IAM role annotations. Each line below is mechanism the matched text
# describes, not a Truvity particular (component contract C4's own
# exception: "Mechanism that is the matched text" -- narrow with a reason,
# never weaken the pattern for everyone else).
#
#   - 123456789012 and 111122223333 are AWS's own documented example
#     account IDs, used throughout AWS's IAM/EKS documentation and carried
#     over verbatim from upstream's own hack/ fixtures and pkg/handler test
#     data -- not a Truvity account.
#   - pkg/cache/cache.go's `arn:aws` is a Go regexp literal that VALIDATES
#     the shape of an ARN a caller supplies; it embeds no account of its
#     own.
#   - cmd/webhook/main.go's `.svc.cluster.local` is the fixed Kubernetes
#     in-cluster DNS suffix, built at runtime from the webhook's own
#     Service/Namespace flags -- identical on every cluster, not a Truvity
#     hostname.
#   - /var/run/secrets/... is Kubernetes' own ServiceAccount-token and
#     TLS-secret mount convention (the same path upstream's code and the
#     Kubernetes docs use), not an SSM parameter path -- the shape `/secrets/`
#     otherwise means.
ALLOWED='123456789012|111122223333|pkg/cache/cache\.go|cmd/webhook/main\.go:[0-9]+:.*svc\.cluster\.local|/var/run/secrets/'

for p in "${patterns[@]}"; do
  # Exclude this script: it necessarily contains the patterns it bans.
  if hits=$(printf '%s\0' "${tracked[@]}" \
              | grep -zZv '^hack/leak-canary\.sh$' \
              | xargs -0 -r grep -InE "$p" 2>/dev/null \
              | grep -vE "$ALLOWED"); then
    echo "LEAK: pattern /$p/ matched — particulars belong in caller inputs or org variables:"
    echo "$hits" | head -5 | sed 's/^/    /'
    fail=1
  fi
done

if [ "$fail" = 0 ]; then
  echo "leak canary clean — ${#patterns[@]} patterns checked, no particulars found"
fi
exit $fail
