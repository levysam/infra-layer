#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

# Wait for internet connectivity
echo "Waiting for internet connectivity..."
while ! ping -c 1 -W 1 8.8.8.8 &> /dev/null; do
  sleep 2
done
echo "Internet connectivity established."

mkdir -p /config/tailscale
if ! run show container image | grep -q "docker.io/tailscale/tailscale"; then
  run add container image docker.io/tailscale/tailscale:latest
fi
