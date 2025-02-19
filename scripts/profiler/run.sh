#!/bin/bash

# Define a common prefix path for profiles
prefix_path="/Users/mrityunjoydey/Documents/comms/memory_leak"

# Define an array of profile names
profiles=("heap_01" "heap_02" "heap_03")

# Determine the starting port
start_port=10001

# Function to stop pprof servers
stop_pprof_servers() {
  echo "Stopping pprof servers..."
  for pid in "${pids[@]}"; do
    kill $pid
  done
}

# Function to listen for 'x' and stop servers
listen_terminate() {
  read -n 1 key
  if [ "$key" == "x" ]; then
    stop_pprof_servers
  else
    listen_terminate
  fi
}

pids=()

# Start pprof HTTP servers in the background and capture their PIDs
for profile in "${profiles[@]}"; do
  port=$((start_port++))
  go tool pprof -http=localhost:$port ${prefix_path}/${profile} -noinlines &
  pids+=($!)
done

# Prompt the user to press "x" followed by Enter to stop pprof servers
echo "Press 'x' and Enter to stop pprof servers..."
listen_terminate

# Optionally, you can also wait for the processes to terminate
wait
