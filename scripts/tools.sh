#!/usr/bin/env bash
# Maintainer tools for the kit's own checks (not installed into target repos).
# Usage: scripts/tools.sh install    download the pinned tools into .tools/bin
#        scripts/tools.sh versions   print the pins
# Each download is checked against the sha256 below before anything is unpacked; a mismatch
# stops with exit 1 and installs nothing for that tool. A tool already installed at its pinned
# version is left alone. Supported: linux-x64 and darwin-arm64; elsewhere install the tools
# yourself at the versions `versions` prints and put them on PATH.
# Exit: 0 ok, 1 download/checksum/platform failure, 2 usage.
# Checksum sources: gitleaks and actionlint from the release's checksums file, lychee from the
# release's per-asset .sha256 files; shellcheck and shfmt publish none, so their pins were
# cross-checked against the sha256 that shellcheck-py 0.11.0.1 and shfmt-py 4.2.0 (PyPI) pin.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/.tools/bin"

# tool version platform sha256 url member ("-" = the download is the binary itself)
TABLE='
shellcheck 0.11.0 linux-x64 8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198 https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz shellcheck-v0.11.0/shellcheck
shellcheck 0.11.0 darwin-arm64 56affdd8de5527894dca6dc3d7e0a99a873b0f004d7aabc30ae407d3f48b0a79 https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.darwin.aarch64.tar.xz shellcheck-v0.11.0/shellcheck
shfmt 3.14.1 linux-x64 76e77641faa025814b77f153b29796b8e6fa2fca03e0c76a691608b86c7ea7bf https://github.com/mvdan/sh/releases/download/v3.14.1/shfmt_v3.14.1_linux_amd64 -
shfmt 3.14.1 darwin-arm64 b7c872db63553ccffc7253aba3ed7d4885a27d83f1ba567b1138c6315a5847e5 https://github.com/mvdan/sh/releases/download/v3.14.1/shfmt_v3.14.1_darwin_arm64 -
gitleaks 8.30.1 linux-x64 551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz gitleaks
gitleaks 8.30.1 darwin-arm64 b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5 https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_darwin_arm64.tar.gz gitleaks
lychee 0.24.2 linux-x64 1f4e0ef7f6554a6ed33dd7ac144fb2e1bbed98598e7af973042fc5cd43951c9a https://github.com/lycheeverse/lychee/releases/download/lychee-v0.24.2/lychee-x86_64-unknown-linux-gnu.tar.gz lychee-x86_64-unknown-linux-gnu/lychee
lychee 0.24.2 darwin-arm64 c9d3740ea2d891854d37116c9fba840f37b6e7c89d330e7db84ac333631c4977 https://github.com/lycheeverse/lychee/releases/download/lychee-v0.24.2/lychee-aarch64-apple-darwin.tar.gz lychee-aarch64-apple-darwin/lychee
actionlint 1.7.12 linux-x64 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8 https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz actionlint
actionlint 1.7.12 darwin-arm64 aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_darwin_arm64.tar.gz actionlint
'

platform() {
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) echo linux-x64 ;;
    Darwin-arm64) echo darwin-arm64 ;;
    *) echo unsupported ;;
  esac
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

versions() {
  echo "$TABLE" | awk 'NF { if (!seen[$1]++) print $1, $2 }'
}

install_one() { # tool version sha url member
  local tool=$1 version=$2 want=$3 url=$4 member=$5 tmp got
  if [[ -x "$BIN/$tool" && "$(cat "$BIN/.$tool.version" 2>/dev/null)" == "$version" ]]; then
    echo "ok: $tool $version already installed"
    return 0
  fi
  tmp="$WORK/$tool"
  mkdir -p "$tmp"
  if ! curl -sSfL --retry 2 -o "$tmp/download" "$url"; then
    echo "FAIL: could not download $tool $version from $url" >&2
    return 1
  fi
  got=$(sha256_of "$tmp/download")
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: $tool $version checksum mismatch (want $want, got $got); nothing installed" >&2
    return 1
  fi
  mkdir -p "$BIN"
  case "$member" in
    -) cp "$tmp/download" "$tmp/$tool" ;;
    *)
      mkdir "$tmp/x"
      case "$url" in
        *.tar.xz) tar -xJf "$tmp/download" -C "$tmp/x" "$member" ;;
        *) tar -xzf "$tmp/download" -C "$tmp/x" "$member" ;;
      esac
      cp "$tmp/x/$member" "$tmp/$tool"
      ;;
  esac
  chmod 755 "$tmp/$tool"
  mv "$tmp/$tool" "$BIN/$tool"
  echo "$version" >"$BIN/.$tool.version"
  echo "installed: $tool $version"
}

install_all() {
  local plat rc=0 tool version p sha url member
  plat=$(platform)
  if [[ "$plat" == unsupported ]]; then
    echo "unsupported platform $(uname -s)-$(uname -m); install these yourself and put them on PATH:" >&2
    versions | sed 's/^/  install /' >&2
    return 1
  fi
  WORK=$(mktemp -d)
  trap 'rm -rf "$WORK"' EXIT
  while read -r tool version p sha url member; do
    [[ -n "${tool:-}" && "$p" == "$plat" ]] || continue
    install_one "$tool" "$version" "$sha" "$url" "$member" || rc=1
  done <<<"$TABLE"
  [[ $rc -eq 0 ]] && echo "add to PATH: $BIN"
  return $rc
}

case "${1:-}" in
  install) install_all ;;
  versions) versions ;;
  *)
    sed -n '2,3p' "$0"
    exit 2
    ;;
esac
