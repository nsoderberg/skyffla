#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/release/package-release.sh <version> <target-triple> <bin-dir> [out-dir]

Produces a release archive in <out-dir>:
  - *.tar.gz on unix-like targets
  - *.zip    on *-pc-windows-* targets
EOF
}

if [[ $# -lt 3 || $# -gt 4 ]]; then
  usage >&2
  exit 1
fi

VERSION="$1"
TARGET_TRIPLE="$2"
BIN_DIR="$3"
OUT_DIR="${4:-dist}"

if [[ "${TARGET_TRIPLE}" == *windows* ]]; then
  EXE_SUFFIX=".exe"
  ARCHIVE_EXT="zip"
else
  EXE_SUFFIX=""
  ARCHIVE_EXT="tar.gz"
fi

ARCHIVE_NAME="skyffla-v${VERSION}-${TARGET_TRIPLE}.${ARCHIVE_EXT}"

SKYFFLA_BIN="${BIN_DIR}/skyffla${EXE_SUFFIX}"
RENDEZVOUS_BIN="${BIN_DIR}/skyffla-rendezvous${EXE_SUFFIX}"

if [[ ! -f "${SKYFFLA_BIN}" ]]; then
  echo "missing binary: ${SKYFFLA_BIN}" >&2
  exit 1
fi

if [[ ! -f "${RENDEZVOUS_BIN}" ]]; then
  echo "missing binary: ${RENDEZVOUS_BIN}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
# Resolve OUT_DIR to an absolute path so we can `cd` into the staging dir
# without losing the destination.
OUT_DIR_ABS="$(cd "${OUT_DIR}" && pwd)"

STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/skyffla-package.XXXXXX")"
cleanup() {
  rm -rf "${STAGE_DIR}"
}
trap cleanup EXIT

install -m 0755 "${SKYFFLA_BIN}"    "${STAGE_DIR}/skyffla${EXE_SUFFIX}"
install -m 0755 "${RENDEZVOUS_BIN}" "${STAGE_DIR}/skyffla-rendezvous${EXE_SUFFIX}"
install -m 0644 README.md           "${STAGE_DIR}/README.md"
install -m 0644 LICENSE             "${STAGE_DIR}/LICENSE"

ARCHIVE_PATH="${OUT_DIR_ABS}/${ARCHIVE_NAME}"

if [[ "${ARCHIVE_EXT}" == "zip" ]]; then
  # Prefer 7z (preinstalled on GitHub windows runners); fall back to `zip`.
  if command -v 7z >/dev/null 2>&1; then
    rm -f "${ARCHIVE_PATH}"
    ( cd "${STAGE_DIR}" && 7z a -tzip -bd -bso0 "${ARCHIVE_PATH}" \
        "skyffla${EXE_SUFFIX}" \
        "skyffla-rendezvous${EXE_SUFFIX}" \
        README.md \
        LICENSE >/dev/null )
  elif command -v zip >/dev/null 2>&1; then
    rm -f "${ARCHIVE_PATH}"
    ( cd "${STAGE_DIR}" && zip -q "${ARCHIVE_PATH}" \
        "skyffla${EXE_SUFFIX}" \
        "skyffla-rendezvous${EXE_SUFFIX}" \
        README.md \
        LICENSE )
  else
    echo "no zip tool available (need 7z or zip)" >&2
    exit 1
  fi
else
  tar -C "${STAGE_DIR}" -czf "${ARCHIVE_PATH}" \
    skyffla \
    skyffla-rendezvous \
    README.md \
    LICENSE
fi

echo "${ARCHIVE_PATH}"
