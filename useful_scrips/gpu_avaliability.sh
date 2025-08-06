#!/usr/bin/env bash
# gpu_avaliability.sh — accurate GPU utilisation for a partition (any Slurm version)
# ------------------------------------------------------------------------------
# Usage:   ./node_gpu_usage.sh [partition]          # default = gpu, you can also use 'pli' if you got access
# Optional: export EXCLUDE_REGEX="^(della-l03g8|della-l04g8)$"      # to skip flaky nodes if there is one

part=${1:-gpu}
EXCLUDE_REGEX=${EXCLUDE_REGEX:-""}

# 1. Get a *compressed* nodelist for the partition (fast) …
nodes=$(sinfo -h -p "$part" -o "%N" | tr -d ' ')
# … and drop excluded hosts if a regex is set
if [[ -n $EXCLUDE_REGEX ]]; then
    # expand to one-per-line, filter, recompress
    nodes=$(scontrol show hostnames "$nodes" | grep -vE "$EXCLUDE_REGEX" | paste -sd, -)
fi

if [[ -z $nodes ]]; then
    echo "Partition '$part' not found or no eligible nodes."
    exit 1
fi

# 2. One scontrol call gives *all* node records in a single shot
read -r total_gpu used_gpu <<<"$(
    scontrol -o show node "$nodes" | awk '
        {
          if (match($0, /CfgTRES=[^ ]*gres\/gpu=([0-9]+)/, a)) total += a[1];
          if (match($0, /AllocTRES=[^ ]*gres\/gpu=([0-9]+)/, b)) used  += b[1];
        }
        END {print total, used}
    '
)"

# 3. Final maths / print
idle=$(( total_gpu - used_gpu ))
(( idle < 0 )) && idle=0
pct=$(awk "BEGIN {printf \"%.1f\", ($total_gpu ? ($used_gpu/$total_gpu)*100 : 0)}")

printf "Partition : %s\nTotal GPUs: %d\nUsed  GPUs: %d\nIdle  GPUs: %d\nUsage %%  : %s%%\n" \
       "$part" "$total_gpu" "$used_gpu" "$idle" "$pct"
