# Gigaflow/OVS Management for Junction/Concord Demo

This repository contains the management scripts for the Gigaflow/OVS setup for the Junction/Concord demo.

## Usage

You install `DPDK`, followed by `OVS` with `DPDK` support.
Then you setup the bridge between `dtap0` and `veth0` and run traffic through it.
Finally, you teardown the bridge and uninstall `OVS`.

>Note: You need to create copy `ovs.vars.template` as `ovs.vars` and fill in the `USER_PASSWORD` variable value as your password for the `sudo` commands. Then run `source ovs.vars` to load the variables. This is required for the following commands to work.

### Install DPDK

```bash
make get-dpdk
make configure-dpdk
make build-dpdk
make install-dpdk
make show-dpdk-version
```

### Install OVS

```bash
make get-ovs
make build-and-install-ovs-dpdk
make show-ovs-version
```

### Setup Bridge: Slowpath-Only Mode

```bash
make setup-bridge
make show-bridges
make show-flows
```

This will bring up the bridge in a "slow path" only mode.
Check this mode by running:

```bash
make confirm-slowpath-only-mode
```

### Enable Caching: Megaflow/Gigaflow Mode
```bash
make enable-caches
```

You should see a noticable difference in the performance because flows are going to get cached now.

### Run the Junction/Concord Demo...

### Teardown Bridge
```bash
make teardown-bridge
```

### Uninstall OVS
```bash
make uninstall-ovs
```