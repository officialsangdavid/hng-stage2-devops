 #!/bin/sh
set -e

# Substitute environment variables into Nginx config template
envsubst '$ACTIVE_POOL' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf

echo "Starting Nginx with ACTIVE_POOL=$ACTIVE_POOL..."
nginx -g 'daemon off;'

