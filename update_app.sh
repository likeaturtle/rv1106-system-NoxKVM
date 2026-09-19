#!/bin/bash
set -eE

APP_URL="${1:-https://dl.acenova.tech/noxkvm/app/latest/jetkvm_app}"

curl -fL "$APP_URL" -o /tmp/jetkvm_app

if [ ! -s /tmp/jetkvm_app ]; then
    echo "Error: Failed to download latest app binary from ${APP_URL}"
    exit 1
fi

chmod +x /tmp/jetkvm_app
mv /tmp/jetkvm_app project/app/jetkvm/jetkvm/bin/jetkvm_app

echo "Successfully updated jetkvm_app from ${APP_URL}"

rm -rf project/app/jetkvm/out
