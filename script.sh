#!/usr/bin/env bash

set -x

without_prefix_version="${CURRENT_VERSION#v}"
IFS='.' read -ra arr_version <<<"${without_prefix_version}"
major="${arr_version[0]}"
minor="${arr_version[1]}"
patch="${arr_version[2]}"

case "${BUMP_LEVEL}" in
  major)
    major="$((major + 1))"
    minor=0
    patch=0
    ;;
  minor)
    minor="$((minor + 1))"
    patch=0
    ;;
  patch)
    patch="$((patch + 1))"
    ;;
  *)
    printf "invalid argument: %s" "${BUMP_LEVEL}" >&2
    exit 1
    ;;
esac

next_version="${major}.${minor}.${patch}"
if [[ "${CURRENT_VERSION}" == "v"* ]]; then
  next_version="v${next_version}"
fi
echo "next-version=${next_version}" >>"${GITHUB_OUTPUT}"
