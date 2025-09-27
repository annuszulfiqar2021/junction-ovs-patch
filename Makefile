# dpdk build options		
export DEPENDENCIES_DIR 							= $(PWD)/deps
export DPDK_SOURCE_DIR 								= $(DEPENDENCIES_DIR)/dpdk
export DPDK_BUILD_DIR 								= $(DPDK_SOURCE_DIR)/build
export DPDK_INSTALL_DIR								= /usr/local/bin
export DPDK_GIT_LINK 								= http://dpdk.org/git/dpdk
export DPDK_VERSION 								= v23.11

export OVS_GIT_LINK 								= https://github.com/openvswitch/ovs.git
export OVS_VERSION 									= v3.4.2
export OVS_SOURCE_DIR 								= $(DEPENDENCIES_DIR)/ovs
export OVS_BUILD_DIR 								= $(OVS_SOURCE_DIR)/build
export OVS_VSWITCHD_BUILD_DIR						= $(OVS_BUILD_DIR)/vswitchd/
export OVS_VSWITCHD_EXECUTABLE_NAME					= ovs-vswitchd

export OVS_BUILD_CONFIGURE_SCRIPT 					= configure
export OVS_BUILD_C_COMPILER 						= gcc
export OVS_BUILD_FLAGS 								= --with-debug
export OVS_BUILD_FLAGS_WITH_DPDK 					= $(OVS_BUILD_FLAGS) --with-dpdk=static
export OVS_BUILD_CFLAGS 							= -g
export OVS_SYSTEM_ID 								= 2025
export OVS_PID_FILE 								= /usr/local/var/run/openvswitch/ovs-vswitchd.pid
export OVS_VSWITCHD_LOG_FILE 						= /usr/local/var/log/openvswitch/ovs-vswitchd.log
export OVS_DB_SOCK 									= /usr/local/var/run/openvswitch/db.sock
export OVS_SCRIPTS_PATH								= /usr/local/share/openvswitch/scripts
export OVS_INSTALL_DIR_1							= /usr/local/sbin
export OVS_INSTALL_DIR_2							= /usr/local/bin
export OVS_INSTALL_DIR_3							= /usr/sbin

# condensed commands
export SUDO 										= echo $(USER_PASSWORD) | sudo -S
export OVS-CTL 										= $(SUDO) env "PATH=$$PATH" ovs-ctl
export OVS-VSCTL 									= $(SUDO) -s ovs-vsctl
export OVS-OFCTL 									= $(SUDO) -s ovs-ofctl
export OVS-DPCTL									= $(SUDO) -s ovs-dpctl
export OVS-APPCTL 									= $(SUDO) -s ovs-appctl

.PHONY: help get-dpdk configure-dpdk build-dpdk install-dpdk show-dpdk-version \
	install-ovs setup-bridge teardown-bridge uninstall-ovs clean status \
	show-bridges get

.DEFAULT_GOAL := help

# Default target
help:
	@echo "GigaFlow OVS Management Scripts"
	@echo "=============================="
	@echo ""
	@echo "Available targets:"
	@echo "  install-ovs     - Install Open vSwitch on Ubuntu"
	@echo "  setup-bridge    - Setup OVS userspace bridge with dtap0 forwarding"
	@echo "  teardown-bridge - Teardown OVS bridge and restore dtap0"
	@echo "  uninstall-ovs   - Uninstall Open vSwitch from Ubuntu"
	@echo "  status          - Show current OVS bridge status"
	@echo "  show-bridges    - Show OVS bridges and their details"
	@echo "  clean           - Alias for teardown-bridge"
	@echo ""

# Dependencies installation
install-dependencies:
	sudo apt install -y autoconf automake libtool

# DPDK installation
get-dpdk:
	cd $(DEPENDENCIES_DIR) && git clone $(DPDK_GIT_LINK)
	cd $(DPDK_SOURCE_DIR) && git checkout $(DPDK_VERSION)

# cd $(DPDK_SOURCE_DIR) && meson configure 
configure-dpdk:
	cd $(DPDK_SOURCE_DIR) && meson setup build --reconfigure \
		-Denable_kmods=true \
		-Denable_trace_fp=true

build-dpdk:
	cd $(DPDK_SOURCE_DIR) && ninja -C build

install-dpdk:
	cd $(DPDK_SOURCE_DIR) && $(SUDO) ninja -C build install

show-dpdk-version:
	pkg-config --modversion libdpdk

# OVS installation
get-ovs:
	cd $(DEPENDENCIES_DIR) && git clone $(OVS_GIT_LINK)
	cd $(OVS_SOURCE_DIR) && git checkout $(OVS_VERSION)

$(OVS_BUILD_DIR):
	@echo "[LOG] Creating OVS Build Directory => $(OVS_BUILD_DIR)"
	mkdir $(OVS_BUILD_DIR)

boot-ovs-build: 
	cd $(OVS_SOURCE_DIR) && ./boot.sh

configure-ovs-build-with-dpdk: boot-ovs-build | $(OVS_BUILD_DIR)
	cd $(OVS_BUILD_DIR) && (.././$(OVS_BUILD_CONFIGURE_SCRIPT) $(OVS_BUILD_FLAGS_WITH_DPDK) CC=$(OVS_BUILD_C_COMPILER) CFLAGS=$(OVS_BUILD_CFLAGS))

build-ovs:
	cd $(OVS_BUILD_DIR) && make -j4

install-ovs:
	cd $(OVS_BUILD_DIR) && $(SUDO) -s make install

build-and-install-ovs-dpdk: configure-ovs-build-with-dpdk build-ovs install-ovs

# Setup OVS bridge with dtap0 forwarding
setup-bridge:
	@echo "Setting up OVS bridge..."
	@chmod +x gigaflow-scripts/setup_ovs_bridge.sh
	@./gigaflow-scripts/setup_ovs_bridge.sh

# Teardown OVS bridge
teardown-bridge:
	@echo "Tearing down OVS bridge..."
	@chmod +x gigaflow-scripts/teardown_ovs_bridge.sh
	@./gigaflow-scripts/teardown_ovs_bridge.sh

# Uninstall Open vSwitch
uninstall-ovs:
	-$(SUDO) rm -rf $(OVS_BUILD_DIR)
	-$(SUDO) rm -rf $(OVS_INSTALL_DIR_1)/ovs*
	-$(SUDO) rm -rf $(OVS_INSTALL_DIR_2)/ovs*
	-$(SUDO) rm -rf $(OVS_INSTALL_DIR_3)/ovs*
	-$(SUDO) rm -rf $(OVS_SCRIPTS_PATH)/ovs*

# uninstall-ovs:
# 	@echo "Uninstalling Open vSwitch..."
# 	@chmod +x gigaflow-scripts/uninstall_ovs.sh
# 	@./gigaflow-scripts/uninstall_ovs.sh

# Show current OVS status
status:
	@echo "Open vSwitch Status:"
	@echo "==================="
	@echo ""
	@echo "Service status:"
	@systemctl is-active openvswitch-switch 2>/dev/null || echo "Service not running"
	@echo ""
	@echo "Bridges:"
	@sudo ovs-vsctl list-br 2>/dev/null || echo "No bridges found"
	@echo ""
	@echo "Bridge details:"
	@sudo ovs-vsctl show 2>/dev/null || echo "No OVS configuration found"
	@echo ""
	@echo "dtap0 interface:"
	@ip link show dtap0 2>/dev/null || echo "dtap0 interface not found"
	@echo ""
	@echo "Bridge flows:"
	@for bridge in $$(sudo ovs-vsctl list-br 2>/dev/null); do \
		echo "Flows for bridge $$bridge:"; \
		sudo ovs-ofctl dump-flows $$bridge 2>/dev/null || echo "  No flows found"; \
		echo ""; \
	done

# Show OVS bridges and their details
show-bridges:
	@echo "Open vSwitch Bridges:"
	@echo "===================="
	@echo ""
	@echo "Bridge list:"
	@sudo ovs-vsctl list-br 2>/dev/null || echo "No bridges found"
	@echo ""
	@echo "Bridge details:"
	@sudo ovs-vsctl show 2>/dev/null || echo "No OVS configuration found"
	@echo ""
	@echo "Bridge flows:"
	@for bridge in $$(sudo ovs-vsctl list-br 2>/dev/null); do \
		echo "Flows for bridge $$bridge:"; \
		sudo ovs-ofctl dump-flows $$bridge 2>/dev/null || echo "  No flows found"; \
		echo ""; \
	done

# Alias for teardown-bridge
clean: teardown-bridge

# Full setup workflow
setup: install-ovs setup-bridge
	@echo "✓ Full OVS setup complete!"

# Full teardown workflow
teardown: teardown-bridge
	@echo "✓ OVS teardown complete!"

# Complete uninstall workflow
uninstall: teardown-bridge uninstall-ovs
	@echo "✓ Complete OVS uninstall finished!"