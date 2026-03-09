#!/usr/bin/env bash
set -euo pipefail

source /opt/conda/etc/profile.d/conda.sh
conda activate "${MONOGS_ENV_NAME:-monogs}"

mkdir -p "${HOME:-/tmp/monogs-home}"

cd "${MONOGS_WORKDIR:-/workspace/MonoGS}"

if [ "$#" -eq 0 ]; then
    exec bash
fi

exec "$@"
