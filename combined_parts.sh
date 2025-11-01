#!/bin/bash

# Part 1 
#  - Find the 6 given executables (apps)
#  - Start them all
#  - Record their process IDs (PIDs)
#  - Make one CSV for each app
#  - Clean up (stop everything) when finished

#  Find 6 executable files 
pick_apps() {
  # Look for files inside $APPS_DIR that are executable. $APPS_DIR will be the folder where the 6 executable files are located
  APP_BINS=($(find "$APPS_DIR" -maxdepth 1 -type f -perm -u=x | sort))

  # Make sure exactly 6 were found
  if [ ${#APP_BINS[@]} -ne 6 ]; then
    echo "Error: expected 6 executables in $APPS_DIR, found ${#APP_BINS[@]}."
    exit 1
  fi

  # Saves the names 
  APP_NAMES=()
  for file in "${APP_BINS[@]}"; do
    APP_NAMES+=("$(basename "$file")")
  done

  echo "Found these 6 apps:"
  printf ' - %s\n' "${APP_NAMES[@]}"
}

#  Start all 6 apps
spawn_apps() {
  PIDS=()  # this will hold the process IDs (numbers)

  echo "Starting all 6 apps with HOST_IP=$HOST_IP"
  for i in "${!APP_BINS[@]}"; do
    app="${APP_BINS[$i]}"
    name="${APP_NAMES[$i]}"

    # Make a CSV file for this app with a header row
    echo "seconds,cpu_percent,mem_percent" > "$OUT_DIR/${name}_metrics.csv"

    # Start the app in the background & and pass HOST_IP as its argument
    "$app" "$HOST_IP" >/dev/null 2>&1 &
    
    # Save its PID so we can monitor and stop it later
    pid=$!
    PIDS+=("$pid")

    echo "Started $name (PID $pid)"
  done
}

#  Stopped all apps and clean up 
cleanup() {
  echo "Cleaning up..."

  # Try to end each app nicely
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null
  done

  # Small pause to let them shut down
  sleep 0.2

  # Force kill if anything still running
  for pid in "${PIDS[@]}"; do
    kill -9 "$pid" 2>/dev/null
  done

  # Kill any helper child processes just in case
  pkill -P $$ 2>/dev/null

  echo "All apps stopped."
}
# Call clean up function upon script exit
trap cleanup EXIT

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

    # stop automatically if any process ended
    for pid in "${PIDS[@]}"; do
      if ! ps -p "$pid" > /dev/null 2>&1; then
        echo "One or more apps exited; stopping monitoring loop."
        return
      fi
    done
  done
}

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

# Path to system level metrics CSV
SYSTEM_CSV="$OUT_DIR/system_metrics.csv"

# Create system level CSV header
echo "seconds,RX_kB/s,TX_kB/s,disk_writes,available_disk" > "$SYSTEM_CSV"

# Collect system level resource metrics and append data to system csv
collect_system_metrics() {
    local seconds rx tx disk_writes available_disk
    seconds=$(( $(date +%s) - START_TIME ))
    # Network RX and TX in kB/s
    read rx tx < <(ifstat -i ens33 1 1 | awk 'NR==3 {print $1, $2}')
    # Disk writes in kB/s
    disk_writes=$(iostat -d -k 1 2 | awk '$1=="sda" {print $3}')
    # Available space on disks
    available_disk=$(df -m / | awk 'NR==2 {print $4}')
    # Append to CSV
    echo "$seconds,$rx,$tx,$disk_writes,$available_disk" >> "$SYSTEM_CSV"
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
                return
            fi
        done
        current_time=$(date +%s)
        elapsed_total=$(( current_time - START_TIME ))

        # Stop if maximum duration reached
        if [ $elapsed_total -ge $MAX_DURATION ]
        then
            echo "Warning: max duration of $MAX_DURATION reached. Stopping monitoring."
            return
        fi
        # Pause before next metrics collection
        sleep "$INTERVAL"
    done
}

# Call Part 1 functions
pick_apps
spawn_apps

# Run main timed loop
main_loop