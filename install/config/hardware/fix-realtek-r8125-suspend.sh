if lspci -nn | grep -q "10ec:8125"; then
  sudo mkdir -p /usr/lib/systemd/system-sleep
  cat <<'EOF' | sudo tee /usr/lib/systemd/system-sleep/omarchy-r8125-resume.sh >/dev/null
#!/bin/bash
if [[ "$1" != "post" ]]; then
  exit 0
fi

# Wait for systemd-networkd to be ready
sleep 2

# Find all Realtek RTL8125 interfaces and trigger systemd-networkd to reconfigure them
# This ensures routes are properly restored after resume without disrupting the link layer
for iface in /sys/class/net/*; do
  ifname=$(basename "$iface")
  if [[ "$ifname" == "lo" ]]; then
    continue
  fi

  driver=$(basename "$(readlink "$iface/device/driver" 2>/dev/null)" 2>/dev/null)
  if [[ "$driver" != "r8169" ]] && [[ "$driver" != "r8125" ]]; then
    continue
  fi

  # Wait for carrier to be detected
  for i in {1..10}; do
    if [[ -f "$iface/carrier" ]] && [[ $(cat "$iface/carrier" 2>/dev/null) == "1" ]]; then
      break
    fi
    sleep 0.5
  done

  # Trigger systemd-networkd to reconfigure the interface and restore routes
  if command -v networkctl >/dev/null 2>&1; then
    networkctl reconfigure "$ifname" 2>/dev/null || true
  fi
done
EOF
  sudo chmod +x /usr/lib/systemd/system-sleep/omarchy-r8125-resume.sh
fi
