#!/bin/bash

# Part 3
# - Holds config/CLI parsing 
# - Makes CSV headers
# - Runs the timed main loop
# - Calls Part 1/2 functions

# Parse CLI arguments 
if [ "$#" -ne 3 ]; then
  echo "Error: expected $0 <APPS_DIR> <OUT_DIR> <HOST_IP>"
  exit 1
fi

# Assign CLI arguments to variables
APPS_DIR=$1
OUT_DIR=$2
HOST_IP=$3
# Variable used to pause in main_loop
INTERVAL=5
MAX_DURATION=900 #15 minutes total

# Create output directory
mkdir -p "$OUT_DIR"

# Record start time
start=$(date +%s)

# Path to system level metrics CSV
SYSTEM_CSV="$OUT_DIR/system_metrics.csv"

# Create system level CSV header
echo "seconds,RX_kB/s,TX_kB/s,disk_writes,available_disk" > "$SYSTEM_CSV"

# Call Part 1 functions
pick_apps
spawn_apps

collect_system_metrics() {
    local now rx tx disk_writes available_disk
    now=$(( $(date +%s) - start))
    # Network RX and TX in kB/s
    read rx tx < <(ifstat -i ens33 1 1 | awk 'NR==3 {print $1, $2}')
    # Disk writes in kB/s
    disk_writes=$(iostat -d -k 1 2 | awk '$1=="sda" {print $3}')
    # Available space on disks
    available_disk=$(df -m / | awk 'NR==2 {print $4}')
    # Append to CSV
    echo "$now,$rx,$tx,$disk_writes,$available_disk" >> "$SYSTEM_CSV"
}

# Main timed loop
main_loop() {
    while true; do
        # Call Part 2 Function
        collect_metrics
        collect_system_metrics

        # Stop if any app exits
        for pid in "${PIDS[@]}"; do
            if ! ps -p "$pid" >/dev/null 2>&1; then
                echo "Warning: one monitored app has exited. Stopping monitoring."
                exit 0
            fi
        done
        now=$(date +%s)
        elapsed=$(( now - start ))

        # Stop if maximum duration reached
        if [ $elapsed -ge $MAX_DURATION ]
        then
            echo "Warning: max duration of $MAX_DURATION reached. Stopping monitoring."
            exit 0
        fi
        # Pause before next metrics collection
        sleep "$INTERVAL"
    done
}
# Run main loop
main_loop
cleanup