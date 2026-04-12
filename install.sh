#!/usr/bin/env bash
# Install a single skill from this repo into ~/.agents/skills/
# Usage: ./install.sh <skill-name>

set -euo pipefail

SKILL_NAME="${1:?Usage: ./install.sh <skill-name>}"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)/${SKILL_NAME}"
TARGET_DIR="${HOME}/.agents/skills/${SKILL_NAME}"

if [ ! -d "$SKILL_DIR" ]; then
  echo "Error: skill '${SKILL_NAME}' not found in $(dirname "$SKILL_DIR")"
  exit 1
fi

mkdir -p "$(dirname "$TARGET_DIR")"

if [ -d "$TARGET_DIR" ]; then
  echo "Updating existing skill at ${TARGET_DIR}..."
  rm -rf "$TARGET_DIR"
fi

cp -R "$SKILL_DIR" "$TARGET_DIR"
echo "Installed '${SKILL_NAME}' to ${TARGET_DIR}"
