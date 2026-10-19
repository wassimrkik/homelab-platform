#!/usr/bin/env bash
# Validate Kubernetes manifests against the Kubernetes API schemas, plus the
# community CRD catalog for custom resources such as Argo CD Applications.
#
# Usage:
#   scripts/kubeconform.sh                 # validate apps/ and clusters/
#   scripts/kubeconform.sh FILE_OR_DIR...  # validate specific paths
#   helm template ... | scripts/kubeconform.sh -   # validate stdin
#
# Shared by the lefthook pre-commit hook and the "kubernetes" workflow, so a
# manifest that passes locally passes in CI too.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  set -- apps clusters
fi

# KUBECONFORM_EXTRA lets callers add flags, e.g. -ignore-missing-schemas for
# rendered Helm charts that ship CRDs without a published schema.
# shellcheck disable=SC2086
exec kubeconform \
  -strict \
  -summary \
  -output text \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  ${KUBECONFORM_EXTRA:-} \
  "$@"
