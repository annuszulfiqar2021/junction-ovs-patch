#!/bin/bash
# uninstall_ovs.sh - Uninstall Open vSwitch from Ubuntu

set -e

echo "Uninstalling Open vSwitch from Ubuntu..."

# Stop the OVS service
echo "Stopping Open vSwitch service..."
sudo systemctl stop openvswitch-switch 2>/dev/null || true

# Disable the service
echo "Disabling Open vSwitch service..."
sudo systemctl disable openvswitch-switch 2>/dev/null || true

# Remove all OVS bridges (cleanup)
echo "Cleaning up any existing OVS bridges..."
for bridge in $(sudo ovs-vsctl list-br 2>/dev/null || true); do
    echo "Removing bridge: $bridge"
    sudo ovs-vsctl del-br "$bridge" 2>/dev/null || true
done

# Uninstall Open vSwitch packages
echo "Uninstalling Open vSwitch packages..."
sudo apt remove --purge -y openvswitch-switch openvswitch-common 2>/dev/null || true

# Remove any remaining OVS configuration files
echo "Removing OVS configuration files..."
sudo rm -rf /etc/openvswitch/ 2>/dev/null || true
sudo rm -rf /var/log/openvswitch/ 2>/dev/null || true

# Clean up any remaining OVS kernel modules
echo "Removing OVS kernel modules..."
sudo modprobe -r openvswitch 2>/dev/null || true

# Clean up package cache
echo "Cleaning up package cache..."
sudo apt autoremove -y
sudo apt autoclean

# Verify removal
if ! command -v ovs-vsctl > /dev/null 2>&1; then
    echo "✓ Open vSwitch successfully uninstalled"
else
    echo "⚠ Some OVS components may still be present"
fi

echo "Uninstall complete!"