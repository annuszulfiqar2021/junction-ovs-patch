#!/bin/bash
# install_ovs.sh - Install Open vSwitch on Ubuntu

set -e

echo "Installing Open vSwitch on Ubuntu..."

# Update package list
sudo apt update

# Install Open vSwitch
sudo apt install -y openvswitch-switch

# Enable and start the OVS service
sudo systemctl enable openvswitch-switch
sudo systemctl start openvswitch-switch

# Check if OVS is running
if systemctl is-active --quiet openvswitch-switch; then
    echo "✓ Open vSwitch installed and running successfully"
else
    echo "✗ Failed to start Open vSwitch service"
    exit 1
fi

# Display OVS version
echo "Open vSwitch version:"
ovs-vsctl --version

echo "Installation complete!"