#!/usr/bin/env bash
# Render every Argo CD Application that installs a Helm chart, using the same
# chart, version, release name, namespace and values files Argo CD would use,
# then validate the rendered manifests with kubeconform.
#
# Catches broken values files and chart/value mismatches in the PR instead of
# at Argo CD sync time. Requires: helm, yq (mikefarah, v4), kubeconform.
#
# Usage: scripts/helm-render.sh [APPLICATION_FILE...]   (default: clusters/**)
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

files=()
if [ "$#" -eq 0 ]; then
  # while-read instead of mapfile so this also runs on macOS's bash 3.2.
  while IFS= read -r f; do files+=("$f"); done \
    < <(find clusters -type f \( -name '*.yaml' -o -name '*.yml' \) | sort)
else
  files=("$@")
fi

rendered=0
failed=0
for file in "${files[@]}"; do
  [ "$(yq '.kind' "$file")" = "Application" ] || continue
  app="$(yq '.metadata.name' "$file")"
  namespace="$(yq '.spec.destination.namespace // "default"' "$file")"

  # Look at .spec.source and every entry in .spec.sources that names a chart.
  count="$(yq '[.spec.source, (.spec.sources // [])[]] | map(select(.chart != null)) | length' "$file")"
  for ((i = 0; i < count; i++)); do
    src="[.spec.source, (.spec.sources // [])[]] | map(select(.chart != null)) | .[$i]"
    repo="$(yq "$src | .repoURL" "$file")"
    chart="$(yq "$src | .chart" "$file")"
    version="$(yq "$src | .targetRevision" "$file")"
    release="$(yq "$src | .helm.releaseName // \"$app\"" "$file")"

    args=(template "$release" "$chart" --repo "$repo" --version "$version" --namespace "$namespace")
    # "$values/<path>" refers to this repository (the source with ref: values).
    while IFS= read -r vf; do
      [ -n "$vf" ] || continue
      path="${vf#\$values/}"
      if [ ! -f "$path" ]; then
        echo "::error file=$file::$app: values file $vf not found at $path"
        failed=$((failed + 1))
        continue 2
      fi
      args+=(--values "$path")
    done < <(yq "$src | .helm.valueFiles // [] | .[]" "$file")

    echo "==> $app: $chart $version from $repo (release $release, namespace $namespace)"
    # kubeconform only reads files ending in .yaml/.yml/.json.
    tmpdir="$(mktemp -d)"
    out="$tmpdir/$app.yaml"
    if ! helm "${args[@]}" >"$out"; then
      echo "::error file=$file::$app: helm template failed"
      failed=$((failed + 1))
      rm -rf "$tmpdir"
      continue
    fi
    # Charts may ship CRDs or custom resources with no published schema.
    if ! KUBECONFORM_EXTRA="-ignore-missing-schemas" scripts/kubeconform.sh "$out"; then
      echo "::error file=$file::$app: rendered manifests failed validation"
      failed=$((failed + 1))
    fi
    rm -rf "$tmpdir"
    rendered=$((rendered + 1))
  done
done

echo "Rendered $rendered Helm application(s), $failed failure(s)."
[ "$failed" -eq 0 ]
