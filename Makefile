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
export OVS-CTL 										= $(SUDO) env "PATH=$$PATH" /usr/local/share/openvswitch/scripts/ovs-ctl
export OVS-VSCTL 									= $(SUDO) -s ovs-vsctl
export OVS-OFCTL 									= $(SUDO) -s ovs-ofctl
export OVS-DPCTL									= $(SUDO) -s ovs-dpctl
export OVS-APPCTL 									= $(SUDO) -s ovs-appctl

export BRIDGE_NAME 									= junction-br0

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
	@echo "  help - Show this help message"

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

clean-dpdk-build:
	-$(SUDO) rm -rf $(DPDK_BUILD_DIR)

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

start-ovs-db:
	$(OVS-CTL) --no-ovs-vswitchd start --system-id=$(OVS_SYSTEM_ID)

# $(OVS-VSCTL) clear Open_vSwitch . other_config
clear-ovsdb-table:
	- $(OVS-VSCTL) --all destroy Open_vSwitch

ovs-initialize-dpdk:	
	$(OVS-VSCTL) --no-wait set Open_vSwitch . other_config:dpdk-init=true

start-ovs-vswitchd:
	$(OVS-CTL) --no-ovsdb-server --db-sock="$(OVS_DB_SOCK)" start

assign-1-core-to-pmd-threads:
	$(SUDO) ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=0x01

set-ovs-nhandler-nrevalidator-threads-to-1:
	$(SUDO) ovs-vsctl --no-wait set Open_vSwitch . other_config:n-handler-threads=1
	$(SUDO) ovs-vsctl --no-wait set Open_vSwitch . other_config:n-revalidator-threads=1

disable-caches:
	$(OVS-VSCTL) --no-wait set Open_vSwitch . other_config:emc-insert-inv-prob=0
	$(OVS-APPCTL) upcall/disable-megaflows
	$(OVS-VSCTL) --no-wait set Open_vSwitch . other_config:max-idle=1

post-setup-ovs-db: set-ovs-nhandler-nrevalidator-threads-to-1 disable-caches

# Setup OVS bridge with dtap0 forwarding
setup-bridge: start-ovs-db clear-ovsdb-table ovs-initialize-dpdk start-ovs-vswitchd assign-1-core-to-pmd-threads post-setup-ovs-db
	@echo "Setting up OVS bridge..."
	@chmod +x gigaflow-scripts/setup_ovs_bridge.sh
	@./gigaflow-scripts/setup_ovs_bridge.sh
	@echo "✓ Full OVS setup complete!"

confirm-slowpath-only-mode:
	$(OVS-APPCTL) upcall/show
	$(OVS-APPCTL) dpctl/dump-flows -m type=ovs

enable-caches:
	$(OVS-APPCTL) upcall/enable-megaflows
	$(OVS-VSCTL) --no-wait remove Open_vSwitch . other_config emc-insert-inv-prob || true
	$(OVS-VSCTL) --no-wait remove Open_vSwitch . other_config max-idle || true
	@echo "✓ OVS caches (EMC + megaflows) re-enabled at runtime"

# OVS show commands
$(OVS_VSWITCHD_LOG_FILE):
	echo "Log file [$(OVS_VSWITCHD_LOG_FILE)] does not exist. OVS is not running!"
	false

show-ovs-version:
	ovs-vswitchd --version

show-ovs-status:
	ovs-vsctl show

show-ovs-flows:
	ovs-ofctl dump-flows ovs-vswitchd

show-ovs-bridges:
	ovs-vsctl list-br

show-vswitchd-status:
	$(SUDO) systemctl status ovs-vswitchd

show-vswitchd-log:
	$(SUDO) cat $(OVS_VSWITCHD_LOG_FILE)

show-vswitchd-log-last-40:
	$(SUDO) tail -40 $(OVS_VSWITCHD_LOG_FILE)

delete-log-file:
	$(SUDO) rm -rf $(OVS_VSWITCHD_LOG_FILE)

show-bridges:
	$(OVS-VSCTL) show

show-openflow-ports:
	$(OVS-OFCTL) show $(BRIDGE_NAME)

show-flows:
	$(OVS-OFCTL) dump-flows $(BRIDGE_NAME)

count-flows:
	$(OVS-OFCTL) dump-flows $(BRIDGE_NAME) | wc -l

# Teardown OVS bridge
teardown-bridge:
	@echo "Tearing down OVS bridge..."
	@chmod +x gigaflow-scripts/teardown_ovs_bridge.sh
	@./gigaflow-scripts/teardown_ovs_bridge.sh
	@echo "✓ OVS teardown complete!"

# Uninstall Open vSwitch
uninstall-ovs:
	-$(SUDO) rm -rf $(OVS_BUILD_DIR)
	-$(SUDO) rm -rf $(OVS_INSTALL_DIR_1)/ovs*
	-$(SUDO) rm -rf $(OVS_INSTALL_DIR_2)/ovs*
	-$(SUDO) rm -rf $(OVS_INSTALL_DIR_3)/ovs*
	-$(SUDO) rm -rf $(OVS_SCRIPTS_PATH)/ovs*
	@echo "✓ Complete OVS uninstall finished!"
