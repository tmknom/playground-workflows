#!/usr/bin/env bash
#
# リリースの配布物（bootstrap を入れた zip と SHA256SUMS）を作る。
# リリースのワークフローも、利用者が配布物を再現するときも、このスクリプトを実行する。
#
# 使い方: scripts/release/build.sh <出力先のディレクトリ>
#
# 出力先には、まだ存在しないディレクトリを指定する。
# 同じコミットと同じ版の Go からは、同じバイト列の zip ができる。
set -euo pipefail

readonly PACKAGE="gates-lambda-linux-arm64.zip"

fail() {
  echo "error: $*" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <output-dir>" >&2
  exit 2
fi

case "$1" in
  /*) output_dir="$1" ;;
  *) output_dir="${PWD}/$1" ;;
esac
# 前回の出力が混ざらないよう、出力先は新しく作る
if [[ -e "${output_dir}" ]]; then
  fail "${output_dir} already exists"
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."

# コミットにない変更がビルドに混ざらないよう、作業ツリーに変更があれば失敗する
if [[ -n "$(git status --porcelain)" ]]; then
  fail "the working tree has uncommitted changes"
fi

# ビルドの結果を変える設定を、手元の環境に左右されないよう固定する
export CGO_ENABLED=0 GOOS=linux GOARCH=arm64 GOARM64=v8.0
export GOTOOLCHAIN=local GOFLAGS=-mod=readonly GOEXPERIMENT='' GOFIPS140=off
export GOPROXY=https://proxy.golang.org GOSUMDB=sum.golang.org GOPRIVATE='' GONOPROXY='' GONOSUMDB='' GOINSECURE=''
# zip は環境変数 ZIPOPT の値をオプションとして読む
unset ZIPOPT

# Go の版が違うとバイト列が変わるため、go.mod の go の版と一致しなければ失敗する
want="go$(go list -m -f '{{.GoVersion}}')"
got="$(go env GOVERSION)"
if [[ "${got}" != "${want}" ]]; then
  fail "Go ${want#go} is required, but ${got#go} is in use"
fi

go mod download
go mod verify

mkdir -- "${output_dir}"
bootstrap="${output_dir}/bootstrap"
go build -trimpath -buildvcs=false -ldflags="-s -w" -o "${bootstrap}" .
chmod 755 "${bootstrap}"

# zip は中のファイルの更新時刻をバイト列に記録するため、コミット日時に固定する。
# GNU と BSD の date の違いを避けるため、git が UTC で整形した時刻を touch に渡す
timestamp="$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y%m%d%H%M.%S)"
TZ=UTC touch -t "${timestamp}" "${bootstrap}"
if [[ "$(TZ=UTC date -r "${bootstrap}" +%Y%m%d%H%M.%S)" != "${timestamp}" ]]; then
  fail "the modification time of bootstrap is not the commit time ${timestamp}"
fi

package="${output_dir}/${PACKAGE}"
TZ=UTC zip -X -j -q "${package}" "${bootstrap}"
if [[ "$(unzip -Z -1 "${package}")" != "bootstrap" ]]; then
  fail "${PACKAGE} must contain only bootstrap"
fi

cd -- "${output_dir}"
if command -v sha256sum > /dev/null; then
  sha256sum "${PACKAGE}" > SHA256SUMS
else
  shasum -a 256 "${PACKAGE}" > SHA256SUMS
fi
cat SHA256SUMS
