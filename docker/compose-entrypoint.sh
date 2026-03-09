#!/usr/bin/env bash
set -euo pipefail

wandb_cfg="${MONOGS_WANDB_CFG:-}"
if [ -n "${wandb_cfg}" ] && [ -r "${wandb_cfg}" ]; then
    set -a
    # Support shell-style env files such as lines prefixed with `export`.
    source "${wandb_cfg}"
    set +a
fi

source /opt/conda/etc/profile.d/conda.sh
conda activate "${MONOGS_ENV_NAME:-monogs}"

mkdir -p "${HOME:-/tmp/monogs-home}"

exec /usr/local/bin/monogs-entrypoint "$@"
