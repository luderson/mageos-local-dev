#!/bin/sh
# Magento's Gruntfile.js only exists after `grunt-cli` deployment mode is set
# up (bin/magento setup:static-content:deploy generates deploy/*.json, and
# dev/tools/grunt ships Gruntfile.js as part of the MageOS source tree).
# On a bare ./src that hasn't run composer create-project yet, that file
# won't exist -- so idle instead of crash-looping, and tell the developer
# how to start watching once code is present.
set -e

cd /var/www/html

if [ -f "Gruntfile.js" ]; then
    if [ ! -d "node_modules" ]; then
        echo "[node] Installing frontend dependencies (npm ci)..."
        npm ci
    fi
    echo "[node] Starting grunt watch..."
    exec npx grunt watch
fi

echo "[node] No Gruntfile.js found in ./src yet -- idling."
echo "[node] Once MageOS is installed, run: docker compose exec node npx grunt watch"
exec tail -f /dev/null
