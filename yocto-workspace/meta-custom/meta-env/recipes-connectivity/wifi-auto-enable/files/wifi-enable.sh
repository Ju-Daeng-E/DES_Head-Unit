#!/bin/sh

# WiFi auto-enable script with retry logic
MAX_RETRIES=10
RETRY_DELAY=5

echo "Starting WiFi auto-enable service..."

for i in $(seq 1 $MAX_RETRIES); do
    echo "Attempt $i/$MAX_RETRIES to enable WiFi..."

    if connmanctl enable wifi 2>&1 | grep -q "Enabled\|Already"; then
        echo "WiFi enabled successfully on attempt $i"
        exit 0
    fi

    echo "Failed to enable WiFi, waiting ${RETRY_DELAY}s before retry..."
    sleep $RETRY_DELAY
done

echo "ERROR: Failed to enable WiFi after $MAX_RETRIES attempts"
exit 1
