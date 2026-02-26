#!/bin/vbash
source /opt/vyatta/etc/functions/script-template
mkdir -p /config/tailscale
if ! run show container image | grep -q "tailscale/tailscale"; then
  run add container image tailscale/tailscale:latest
fi
