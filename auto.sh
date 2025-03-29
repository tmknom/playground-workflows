#!/usr/bin/env bash
set -euo pipefail

DEFAULT_BRANCH=main

#git fetch --tag
current_version="$(git tag --sort=-v:refname | head -1)"

range="${DEFAULT_BRANCH}"
if [[ "${current_version}" != "" ]]; then
  range="${current_version}..${DEFAULT_BRANCH}"
fi

messages="$(git log "${range}" --merges --pretty='format:%s')"
numbers=$(grep -oE '#[0-9]+' <<<"${messages}" | sed 's/#//g' | sort -u)

result="none"
mapfile -t prs <<<"${numbers}"
for pr in "${prs[@]}"; do
  labels="$(gh pr view "${pr}" --json labels --jq '.labels[].name')"
  if grep -Eqx "enhancement" <<<"${labels}"; then
    result="minor"
    break
  elif grep -Eqx "bug|dependencies" <<<"${labels}"; then
    result="patch"
    # Note: Do not break; a higher-priority label may still appear.
  fi
done

echo "${result}"
