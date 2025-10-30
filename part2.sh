#!/bin/bash

# Part 2
#  - Continuously collect metrics
#  - Each row: seconds,cpu_percent,mem_percent
#  - Appends to each app's CSV
#  - Stops when any app exits or user interrupts

# Record the script start time for relative seconds column
START_TIME=$(date +%s)

# Collect one sample for all apps
collect_metrics() {
  local now elapsed cpu mem name pid csvfile

  now=$(date +%s)
  elapsed=$(( now - START_TIME ))

  # Iterate over each app & its PID
  for i in "${!APP_NAMES[@]}"; do
    name="${APP_NAMES[$i]}"
    pid="${PIDS[$i]}"
    csvfile="$OUT_DIR/${name}_metrics.csv"

    if ps -p "$pid" > /dev/null 2>&1; then
      # Query CPU and MEM for this PID
      read cpu mem < <(ps -p "$pid" -o %cpu= -o %mem=)
    else
      # If process has exited, mark zeros
      cpu=0
      mem=0
    fi

    # Append row to the app's CSV
    echo "$elapsed,$cpu,$mem" >> "$csvfile"
  done
}

# Continuous monitor loop
monitor_loop() {
  local interval=${1:-1}  # seconds between samples

  echo "Collecting metrics every $interval second(s)..."
  while true; do
    collect_metrics
    sleep "$interval"

    stop automatically if any process ended
    for pid in "${PIDS[@]}"; do
      if ! ps -p "$pid" > /dev/null 2>&1; then
        echo "One or more apps exited; stopping monitoring loop."
        return
      fi
    done
  done
}

