#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 <base_image> <image> [image_main_user] [rcfile] [context_path]"
    echo "<base_image>:       The base image to use for the Docker build (e.g., ubuntu:24.04)"
    echo "<image>:            The name and tag for the resulting Docker image (e.g., myimage:latest)"
    echo "[image_main_user]:  Optional. The main user in the base image (default: dev)"
    echo "[rcfile]:           Optional. Shell rc file for PATH entries, relative to HOME (default: .bashrc.user)"
    echo "[context_path]:     Optional. The path to the Docker build context (default: this script directory)"
    exit "${1:-0}"
}

for arg in "$@"; do
    if [[ ${arg} == "-h" || ${arg} == "--help" ]]; then
        usage 0
    fi
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

base_image="${1:-}"
image="${2:-}"
image_main_user="${3:-dev}"
rcfile="${4:-.bashrc.user}"
context_path="${5:-${script_dir}}"
dockerfile_path="${context_path}/Dockerfile.ai-tools"

if [[ -z ${base_image} ]] || [[ -z ${image} ]]; then
    echo "Error: <base_image> and <image> are required." >&2
    usage 1
fi

if [[ ! -f ${dockerfile_path} ]]; then
    echo "Error: Dockerfile was not found at '${dockerfile_path}'." >&2
    exit 1
fi

# --pull and --no-cache together force a fully fresh build: the base image is
# always re-pulled and no layer cache is used. This ensures the AI tools image
# always installs the latest versions of Bun, pnpm packages and RTK.
docker buildx build -f "${dockerfile_path}" \
    --progress=plain \
    --pull \
    --no-cache \
    --build-arg BASE_IMAGE="${base_image}" \
    --build-arg IMAGE_MAIN_USER="${image_main_user}" \
    --build-arg RCFILE="${rcfile}" \
    -t "${image}" "${context_path}"
