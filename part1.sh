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
