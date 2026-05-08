#!/bin/sh

PORT="${PORT:-8080}"
DEBUG="${DEBUG:-false}"

if ! echo "$PORT" | grep -qE '^[0-9]+$'; then
    echo "Error: PORT must be a numeric value." >&2
    exit 1
fi

if [ "$DEBUG" != "true" ] && [ "$DEBUG" != "false" ]; then
    echo "Error: DEBUG must be either 'true' or 'false'." >&2
    exit 1
fi

# Generate CookieFarm config from unified YAML
python3 /app/generate_config.py
if [ $? -ne 0 ]; then
    echo "Error: Failed to generate config" >&2
    exit 1
fi

# Read password from our unified config
PASSWORD="$(python3 -c "import yaml; print(yaml.safe_load(open('/config/farm.yml'))['server_password'])")"
if [ -z "$PASSWORD" ]; then
    echo "Error: server_password not found in /config/farm.yml" >&2
    exit 1
fi

CMD="/app/bin/cks"

ARGS="-P ${PASSWORD}"
ARGS="$ARGS -p ${PORT}"
ARGS="$ARGS -c /app/config.yml"

if [ "$DEBUG" = "true" ]; then
    ARGS="$ARGS -D"
fi

CMD="$CMD $ARGS"
eval exec $CMD
