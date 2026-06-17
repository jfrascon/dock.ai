#!/usr/bin/env bash
# install_ai_tools_root.sh
#
# System-level AI tooling setup. Must run as root.
#
# Installs:
#   - System packages required by AI tool installers (curl, git, unzip, bubblewrap, etc.)
#   - Node.js LTS from NodeSource
#   - Corepack + pnpm global shims (requires root to write to /usr/bin)

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Validate that the script is running as root.
# ---------------------------------------------------------------------------
if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: this script must run as root (current uid: $(id -u))." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# System packages.
# ---------------------------------------------------------------------------
apt-get update

apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    unzip \
    tar \
    xz-utils \
    bubblewrap

# ---------------------------------------------------------------------------
# Node.js LTS from NodeSource.
# setup_lts.x tracks the current LTS automatically — no manual version bump needed.
# Skipped if node is already present (e.g. base image already has it).
# ---------------------------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get update
    apt-get install -y --no-install-recommends nodejs
fi

for cmd in node npm; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "Error: ${cmd} was not found after Node.js setup." >&2
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Corepack + pnpm.
#
# Corepack ships with modern Node.js but may not be enabled by default.
# corepack enable must run as root because it creates shims under /usr/bin.
# Running it as IMAGE_MAIN_USER can fail with EACCES.
#
# pnpm is used instead of npm for user-level AI tooling because it provides
# a cleaner package-management model.
# ---------------------------------------------------------------------------
if ! command -v corepack >/dev/null 2>&1; then
    npm install -g corepack
fi

corepack enable
corepack prepare pnpm@latest --activate

for cmd in corepack pnpm; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "Error: ${cmd} was not found after Corepack/pnpm setup." >&2
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Cleanup apt cache to keep image layer small.
# ---------------------------------------------------------------------------
rm -rf /var/lib/apt/lists/*
