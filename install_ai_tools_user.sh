#!/usr/bin/env bash
# install_ai_tools_user.sh
#
# User-level AI tooling setup. Must NOT run as root.
#
# Installs under ${HOME}:
#   - Bun runtime          → ${HOME}/.bun
#   - pnpm global packages → ${HOME}/.local/share/pnpm
#       - context-mode
#       - @upstash/context7-mcp
#   - RTK (Rust Token Killer)
#   - PATH entries in the rc file specified by --rcfile (default: ~/.bashrc)
#
# Arguments:
#   --rcfile <filename>   Shell startup file for PATH entries, relative to
#                         HOME. Defaults to ".bashrc".

set -euo pipefail

# ---------------------------------------------------------------------------
# Validate that the script is NOT running as root.
# ---------------------------------------------------------------------------
if [[ "$(id -u)" -eq 0 ]]; then
    echo "Error: this script must NOT run as root." >&2
    exit 1
fi

if [[ -z ${HOME:-} || ! -d ${HOME} ]]; then
    echo "Error: HOME must point to an existing user home directory." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Arguments.
#
# --rcfile <filename>  Shell startup file that receives the PATH entries for
#                      user-local tooling. The filename is relative to HOME.
#                      Defaults to ".bashrc".
# ---------------------------------------------------------------------------
RCFILE=".bashrc"

while [[ $# -gt 0 ]]; do
    case "$1" in
    --rcfile)
        if [[ -z ${2:-} ]]; then
            echo "Error: --rcfile requires a value." >&2
            exit 1
        fi
        RCFILE="$2"
        shift 2
        ;;
    *)
        echo "Error: unknown argument '$1'." >&2
        exit 1
        ;;
    esac
done

if [[ ${RCFILE} == /* || ${RCFILE} == *".."* ]]; then
    echo "Error: --rcfile must be a filename relative to HOME." >&2
    exit 1
fi

RC_PATH="${HOME}/${RCFILE}"

if [[ ! -f ${RC_PATH} ]]; then
    touch "${RC_PATH}"
fi

# ---------------------------------------------------------------------------
# Pre-requisite checks.
# ---------------------------------------------------------------------------
for cmd in corepack curl find grep mkdir node npm pnpm; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "Error: '${cmd}' was not found. It must be installed before running this script." >&2
        exit 1
    fi
done

export PNPM_HOME="${HOME}/.local/share/pnpm"
export BUN_INSTALL="${HOME}/.bun"

# ---------------------------------------------------------------------------
# PATH and env vars for user-local tooling.
#
# pnpm stores global binaries under PNPM_HOME/bin. Both PNPM_HOME and
# PNPM_HOME/bin are added to PATH so pnpm-installed CLIs are reachable
# without relying on pnpm setup (which edits shell startup files).
#
# RTK may install to ~/.local/bin or ~/.cargo/bin depending on the installer.
# Both are prepended to PATH before running the RTK installer.
# ---------------------------------------------------------------------------

# Add paths to PATH only if they are not already present.
path_dirs=(
    "${HOME}/.local/bin"
    "${HOME}/.cargo/bin"
    "${PNPM_HOME}/bin"
    "${BUN_INSTALL}/bin"
)

for dir in "${path_dirs[@]}"; do
    if [[ ":${PATH}:" != *":${dir}:"* ]]; then
        export PATH="${dir}:${PATH}"
    fi

    # Ensure the directory exists so tools can be installed there.
    mkdir -p "${dir}"
done

pnpm config set global-bin-dir "${PNPM_HOME}/bin"

# ---------------------------------------------------------------------------
# Supply-chain hardening: disable lifecycle scripts for npm and pnpm.
#
# npm packages can define lifecycle hooks (preinstall, install, postinstall)
# that execute automatically during installation and are a common attack vector.
# Setting ignore-scripts=true prevents them from running during pnpm add.
#
# Trade-off: some packages that legitimately need install scripts may be
# incomplete. Install those explicitly with --ignore-scripts=false after review.
# ---------------------------------------------------------------------------
npm config set ignore-scripts true
pnpm config set ignore-scripts true

# ---------------------------------------------------------------------------
# Bun runtime.
#
# Installed under ${HOME}/.bun because BUN_INSTALL is already exported above.
# The official installer may append PATH setup to ~/.bashrc; PATH is set
# explicitly before running installers so binary checks in this script work.
# ---------------------------------------------------------------------------
curl -fsSL https://bun.sh/install | bash

if [[ ! -x "${BUN_INSTALL}/bin/bun" ]]; then
    echo "Error: bun was not found at ${BUN_INSTALL}/bin/bun after installation." >&2
    ls -la "${BUN_INSTALL}/bin" >&2
    exit 1
fi

if [[ ! -x "${BUN_INSTALL}/bin/bunx" ]]; then
    echo "Error: bunx was not found at ${BUN_INSTALL}/bin/bunx after installation." >&2
    ls -la "${BUN_INSTALL}/bin" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# MCP tools: context-mode and context7-mcp.
#
# Both are installed persistently via pnpm so they have stable CLI entrypoints
# under PNPM_HOME/bin, avoiding pnpm dlx / bunx downloads at runtime.
#
# context-mode is installed via pnpm first (creates the global shim), then
# upgraded through its own update path — which may pull a newer runtime
# version than the npm package version pnpm reports.
# ---------------------------------------------------------------------------
pnpm add -g \
    @upstash/context7-mcp@latest \
    context-mode@latest

if ! command -v context7-mcp >/dev/null 2>&1; then
    echo "Error: context7-mcp was not found after installation." >&2
    exit 1
fi

if ! command -v context-mode >/dev/null 2>&1; then
    echo "Error: context-mode was not found after installation." >&2
    exit 1
fi

# context-mode manages its own plugin/runtime update path from GitHub.
# Running upgrade here ensures the image has the latest effective version.
# ~/.claude must exist before upgrade runs (context-mode stores state there).
mkdir -p "${HOME}/.claude"
context-mode upgrade

# ---------------------------------------------------------------------------
# RTK (Rust Token Killer).
#
# Installed via the official quick-install script so the binary and
# configuration land in the user's HOME, not /root.
# ---------------------------------------------------------------------------
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

if ! command -v rtk >/dev/null 2>&1; then
    echo "Error: rtk was not found after installation." >&2
    echo "Current PATH: ${PATH}" >&2
    echo "Candidates:" >&2
    find "${HOME}" -type f -name 'rtk*' -print 2>/dev/null >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Persist PATH for interactive Bash shells.
#
# The PATH block is written to a dedicated AI rc file (RC_PATH_AI) derived
# from RCFILE by appending ".ai" (e.g. ".bashrc" → ".bashrc.ai"). This keeps
# the main rc file clean — it receives only a single source line.
#
# RC_PATH_AI is always overwritten (not appended) so re-running the script
# produces an idempotent result with no duplicate entries.
#
# The source line is added to RC_PATH only once, guarded by grep -qxF.
# ---------------------------------------------------------------------------
RC_PATH_AI="${RC_PATH}.ai"

cat >"${RC_PATH_AI}" <<'EOF'
export BUN_INSTALL="${HOME}/.bun"
export PNPM_HOME="${HOME}/.local/share/pnpm"

path_dirs=(
  "${HOME}/.local/bin"
  "${HOME}/.cargo/bin"
  "${PNPM_HOME}/bin"
  "${BUN_INSTALL}/bin"
)

for dir in "${path_dirs[@]}"; do
  if [[ ":${PATH}:" != *":${dir}:"* ]]; then
    export PATH="${dir}:${PATH}"
  fi
done
EOF

source_line="[ -f \"${RC_PATH_AI}\" ] && . \"${RC_PATH_AI}\""

if ! grep -qxF "${source_line}" "${RC_PATH}"; then
    echo '# --------------------------------------' >>"${RC_PATH}"
    echo "${source_line}" >>"${RC_PATH}"
fi

# ---------------------------------------------------------------------------
# Verification summary.
# ---------------------------------------------------------------------------
echo "node:          $(node --version)"
echo "npm:           $(npm --version)"
echo "corepack:      $(corepack --version)"
echo "pnpm:          $(pnpm --version)"
echo "bun:           $("${BUN_INSTALL}/bin/bun" --version)"
echo "bunx:          $("${BUN_INSTALL}/bin/bunx" --version)"
echo "rtk:           $(rtk --version)"
echo "context-mode:  $(command -v context-mode)"
echo "context7-mcp:  $(command -v context7-mcp)"

echo "context-mode doctor:"
context-mode doctor

echo "pnpm global packages:"
pnpm list -g --depth=0
