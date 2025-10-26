#!/bin/bash

# This script continuously checks the /version endpoint via Nginx
# and prints which app (blue or green) is responding.

URL="http://localhost:8080/version"

echo "Starting continuous version checks on $URL ..."
echo "Press Ctrl+C to stop."

while true; do
  # Capture the X-App-Pool and X-Release-Id headers
  curl -s -i $URL | grep -E "X-App-Pool|X-Release-Id" | sed 's/^/  /'
  echo "---------------------------------------"
  sleep 1
done

