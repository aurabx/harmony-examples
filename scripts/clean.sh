#!/usr/bin/env bash
set -euo pipefail

# This script is in scripts/, so repo root is one level up
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PIPELINES_DIR="${ROOT_DIR}/pipelines"

if [[ ! -d "${PIPELINES_DIR}" ]]; then
  echo "pipelines directory not found at: ${PIPELINES_DIR}" >&2
  exit 1
fi

tmp_dirs=()
harmony_bins=()

# Discover items to delete
for pipeline_dir in "${PIPELINES_DIR}"/*; do
  [[ -d "${pipeline_dir}" ]] || continue

  tmp_dir="${pipeline_dir}/tmp"
  harmony_bin="${pipeline_dir}/harmony"

  if [[ -d "${tmp_dir}" ]]; then
    tmp_dirs+=("${tmp_dir}")
  fi

  if [[ -f "${harmony_bin}" ]]; then
    harmony_bins+=("${harmony_bin}")
  fi
done

if [[ ${#tmp_dirs[@]} -eq 0 && ${#harmony_bins[@]} -eq 0 ]]; then
  echo "Nothing to clean under ${PIPELINES_DIR}."
  exit 0
fi

echo "The following items will be deleted:"
if [[ ${#tmp_dirs[@]} -gt 0 ]]; then
  echo
  echo "tmp directories:"
  for d in "${tmp_dirs[@]}"; do
    echo "  ${d}"
  done
fi

if [[ ${#harmony_bins[@]} -gt 0 ]]; then
  echo
  echo "harmony binaries:"
  for f in "${harmony_bins[@]}"; do
    echo "  ${f}"
  done
fi

echo
read -r -p "Proceed with deletion? [y/N] " answer
case "$answer" in
  [Yy]* ) ;;
  * )
    echo "Aborted."
    exit 0
    ;;
esac

# Perform deletions
for d in "${tmp_dirs[@]}"; do
  echo "Removing tmp dir: ${d}"
  rm -rf "${d}"
done

for f in "${harmony_bins[@]}"; do
  echo "Removing harmony binary: ${f}"
  rm -f "${f}"
done

echo "Done."