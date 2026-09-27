#!/bin/bash
# Rotate Docker secrets

set -e

SECRET_NAME="$1"
NEW_SECRET_VALUE="$2"

if [ -z "$SECRET_NAME" ] || [ -z "$NEW_SECRET_VALUE" ]; then
    echo "Usage: $0 <secret_name> <new_value>"
    exit 1
fi

echo "Rotating secret: $SECRET_NAME"

# Create new version of secret
NEW_SECRET_NAME="${SECRET_NAME}_$(date +%Y%m%d_%H%M%S)"
echo "$NEW_SECRET_VALUE" | docker secret create "$NEW_SECRET_NAME" -

# Update service to use new secret
SERVICES=$(docker service ls --filter "label=uses-secret=$SECRET_NAME" --format "{{.Name}}")

for service in $SERVICES; do
    echo "Updating service: $service"
    
    # Remove old secret and add new one
    docker service update \
        --secret-rm "$SECRET_NAME" \
        --secret-add "source=$NEW_SECRET_NAME,target=$SECRET_NAME" \
        "$service"
done

# Wait for rollout to complete
for service in $SERVICES; do
    echo "Waiting for $service to update..."
    docker service logs -f "$service" &
    
    # Wait for service to be stable
    while [ "$(docker service ps "$service" --filter "desired-state=running" --format "{{.CurrentState}}" | grep -c "Running")" -lt 1 ]; do
        sleep 5
    done
done

# Remove old secret after successful rollout
echo "Removing old secret: $SECRET_NAME"
docker secret rm "$SECRET_NAME" || echo "Warning: Could not remove old secret"

# Rename new secret to original name (Docker doesn't support this directly)
echo "Secret rotation completed!"
echo "Note: New secret is named $NEW_SECRET_NAME"
