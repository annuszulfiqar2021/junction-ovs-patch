#!/bin/bash
# setup_ovs_veth.sh - Setup OVS userspace bridge with veth0 (for Concord) and dtap0 (for iokernel/junction)

set -e

BRIDGE_NAME="junction-br0"
TAP_INTERFACE="dtap0"
VETH0="veth0"   # Concord binds to this
VETH1="veth1"   # OVS sees this

echo "Setting up OVS userspace bridge with $TAP_INTERFACE and veth pair..."

# Check if dtap0 interface exists
if ! ip link show "$TAP_INTERFACE" > /dev/null 2>&1; then
    echo "✗ Interface $TAP_INTERFACE not found. Please ensure Caladan iokerneld is running."
    exit 1
fi

# Check if OVS is running
if ! systemctl is-active --quiet openvswitch-switch; then
    echo "✗ Open vSwitch is not running. Please run install_ovs.sh first."
    exit 1
fi

# Create veth pair if not exists
if ! ip link show "$VETH0" > /dev/null 2>&1; then
    echo "Creating veth pair: $VETH0 <-> $VETH1"
    sudo ip link add "$VETH0" type veth peer name "$VETH1"
fi

# Bring up veth interfaces
sudo ip link set "$VETH0" up
sudo ip link set "$VETH1" up

# Note: Assign Concord's IP to veth0, not to dtap0
# Example (adjust as needed):
# sudo ip addr add 192.168.100.1/24 dev $VETH0

# Create OVS bridge as userspace (netdev) datapath
echo "Creating OVS userspace bridge: $BRIDGE_NAME"
sudo ovs-vsctl --may-exist add-br "$BRIDGE_NAME" \
    -- set Bridge "$BRIDGE_NAME" datapath_type=netdev \
    -- set Bridge "$BRIDGE_NAME" fail-mode=secure

# Add ports: veth1 and dtap0
echo "Adding $VETH1 and $TAP_INTERFACE to OVS bridge..."
sudo ovs-vsctl --may-exist add-port "$BRIDGE_NAME" "$VETH1"
sudo ovs-vsctl --may-exist add-port "$BRIDGE_NAME" "$TAP_INTERFACE"

# Bring up the bridge interface
sudo ip link set "$BRIDGE_NAME" up

# Get OpenFlow port numbers
P_VETH1=$(sudo ovs-vsctl get Interface "$VETH1" ofport)
P_TAP=$(sudo ovs-vsctl get Interface "$TAP_INTERFACE" ofport)

sudo ovs-ofctl del-flows "$BRIDGE_NAME"

# Add pipeline flows: veth1 <-> dtap0 (5-stage resubmit pipeline)
echo "Adding vSwitch pipeline flows..."
sudo ovs-ofctl add-flow "$BRIDGE_NAME" "table=0,in_port=$P_VETH1,actions=resubmit(,1)"
sudo ovs-ofctl add-flow "$BRIDGE_NAME" "table=0,in_port=$P_TAP,actions=resubmit(,1)"
sudo ovs-ofctl add-flow "$BRIDGE_NAME" "table=1,actions=resubmit(,2)"
sudo ovs-ofctl add-flow "$BRIDGE_NAME" "table=2,actions=resubmit(,3)"
sudo ovs-ofctl add-flow "$BRIDGE_NAME" "table=3,actions=resubmit(,4)"
# Final table sends back out the opposite port
sudo ovs-ofctl add-flow "$BRIDGE_NAME" "table=4,in_port=$P_VETH1,actions=output:$P_TAP"
sudo ovs-ofctl add-flow "$BRIDGE_NAME" "table=4,in_port=$P_TAP,actions=output:$P_VETH1"

# Display bridge status
echo "Userspace bridge setup complete!"
echo "Bridge status:"
sudo ovs-vsctl show

echo "Current flows:"
sudo ovs-ofctl dump-flows "$BRIDGE_NAME"

echo "✓ Userspace OVS bridge $BRIDGE_NAME is ready with veth0<->dtap0 forwarding pipeline"
