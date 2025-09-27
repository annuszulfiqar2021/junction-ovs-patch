#!/bin/bash
# teardown_ovs_bridge.sh - Teardown OVS bridge and restore dtap0

set -e

BRIDGE_NAME="junction-br0"
TAP_INTERFACE="dtap0"

echo "Tearing down OVS bridge setup..."

# Check if bridge exists
if ! sudo ovs-vsctl br-exists "$BRIDGE_NAME" 2>/dev/null; then
    echo "✗ Bridge $BRIDGE_NAME does not exist"
    exit 1
fi

# Remove dtap0 from the bridge
echo "Removing $TAP_INTERFACE from bridge..."
if sudo ovs-vsctl port-to-br "$TAP_INTERFACE" 2>/dev/null | grep -q "$BRIDGE_NAME"; then
    sudo ovs-vsctl del-port "$BRIDGE_NAME" "$TAP_INTERFACE"
    echo "✓ Removed $TAP_INTERFACE from bridge"
else
    echo "⚠ $TAP_INTERFACE is not on bridge $BRIDGE_NAME"
fi

# Clear all flows from the bridge
echo "Clearing flows from bridge..."
sudo ovs-ofctl del-flows "$BRIDGE_NAME"

# Delete the bridge
echo "Deleting bridge $BRIDGE_NAME..."
sudo ovs-vsctl del-br "$BRIDGE_NAME"

# Check if dtap0 still exists and bring it up
if ip link show "$TAP_INTERFACE" > /dev/null 2>&1; then
    echo "Bringing up $TAP_INTERFACE..."
    sudo ip link set "$TAP_INTERFACE" up
    echo "✓ $TAP_INTERFACE is now available as a standalone interface"
else
    echo "⚠ $TAP_INTERFACE interface not found (may have been removed by Caladan)"
fi

echo "✓ Bridge teardown complete!"