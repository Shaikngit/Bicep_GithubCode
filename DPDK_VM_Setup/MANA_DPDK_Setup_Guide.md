# MANA DPDK Setup Guide for Azure

Complete guide for setting up DPDK with Microsoft Azure Network Adapter (MANA) on Azure VMs for VM-to-VM packet forwarding.

## Overview

This guide documents the complete setup process for DPDK with MANA hardware on Azure, including a **critical undocumented requirement** for VM-to-VM packet forwarding: modifying testpmd source code IP addresses to match actual VM IPs.

## Prerequisites

### VM Requirements
- **VM Size**: Standard_D8s_v6 or later (Dv6/Dv6i/Ev6/Mv3 series)
- **Region**: Any region supporting v6 series VMs
- **OS**: Ubuntu 22.04 LTS (kernel 6.2+ or backported 5.15+)
- **Network**: Dual NICs recommended (management + DPDK)
- **Accelerated Networking**: Enabled on DPDK NICs

### Software Requirements
- **Kernel**: 6.2+ (or backported 5.15+ with MANA drivers)
- **DPDK**: 22.11+ (contains net_mana PMD)
- **rdma-core**: v44+ (for MANA InfiniBand driver support)

**Note**: Ubuntu 22.04 with kernel 6.8.0-1044-azure ships with rdma-core v39, which is too old. However, DPDK net_mana PMD can work with it for basic functionality.

## Lab Environment

### Deployment Details
- **VM1 (manavm1)**: Standard_D8s_v6
  - Management NIC (eth0): 10.0.1.10
  - DPDK NIC (eth1): 10.0.1.20
  - MANA MAC: 00:0d:3a:a3:65:1d
  
- **VM2 (manavm2)**: Standard_D8s_v6
  - Management NIC (eth0): 10.0.1.11
  - DPDK NIC (eth1): 10.0.1.21
  - MANA MAC: 00:0d:3a:a3:62:be

- **VNet**: 10.0.0.0/16
- **Subnet**: 10.0.1.0/24

## Hardware Verification

After deployment, verify MANA hardware is present:

```bash
# Check for MANA device (Microsoft Corporation 1414:00ba)
lspci -d 1414:00ba

# Expected output:
# 7870:00:00.0 Ethernet controller: Microsoft Corporation Device 00ba

# Check kernel modules
lsmod | grep mana

# Expected output:
# mana_ib                77824  0
# ib_uverbs             188416  2 mana_ib,rdma_ucm
# ib_core               495616  7 rdma_cm,mana_ib,...

# Check MANA InfiniBand devices
ls -la /sys/class/infiniband/

# Expected output:
# mana_0 -> ../../devices/.../infiniband/mana_0
# manae_0 -> ../../devices/.../infiniband/manae_0

# Verify VM size
curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2021-02-01&format=text"

# Expected: Standard_D8s_v6

# Check MANA driver details
lspci -vv -s 7870:00:00.0 | grep -i "vendor\|device\|driver"

# Expected:
# Kernel driver in use: mana
```

## DPDK Installation

### 1. Install Dependencies

```bash
sudo apt update
sudo apt install -y rdma-core libibverbs-dev ibverbs-utils \
    build-essential libudev-dev libnl-3-dev libnl-route-3-dev \
    ninja-build libssl-dev libelf-dev python3-pip meson libnuma-dev \
    libpcap-dev python3-pyelftools
```

### 2. Download and Build DPDK 23.11 LTS

```bash
cd ~
wget https://fast.dpdk.org/rel/dpdk-23.11.tar.xz
tar xf dpdk-23.11.tar.xz
cd dpdk-23.11

# Build DPDK with MANA PMD support
meson setup build
cd build
ninja
sudo ninja install
sudo ldconfig

# Verify installation
ls -la /usr/local/bin/dpdk-testpmd
```

### 3. Configure Hugepages

```bash
# Allocate 512 x 2MB hugepages (1GB total)
echo 512 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages

# Verify hugepages configuration
grep Huge /proc/meminfo

# Expected output:
# HugePages_Total:     512
# HugePages_Free:      512
# Hugepagesize:       2048 kB
# Hugetlb:         1048576 kB
```

## CRITICAL: Modify testpmd Source Code for Azure

**This step is REQUIRED for VM-to-VM packet forwarding on Azure but is NOT documented in the official MANA guide.**

The Azure vSwitch filters packets with incorrect IP addresses. Default testpmd uses 198.18.0.x IPs which are rejected by Azure's infrastructure.

### On VM1 (10.0.1.20):

```bash
cd ~/dpdk-23.11/app/test-pmd

# Backup original file
sudo cp txonly.c txonly.c.backup

# Modify IP addresses to match VM1's DPDK NIC IP (10.0.1.20) as source
# and VM2's DPDK NIC IP (10.0.1.21) as destination
sudo sed -i 's/#define IP_SRC_ADDR.*/#define IP_SRC_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 20)/' txonly.c
sudo sed -i 's/#define IP_DST_ADDR.*/#define IP_DST_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 21)/' txonly.c

# Verify changes
grep "IP_SRC_ADDR\|IP_DST_ADDR" txonly.c

# Expected output:
# #define IP_SRC_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 20)
# #define IP_DST_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 21)

# Rebuild DPDK
cd ~/dpdk-23.11/build
ninja
sudo ninja install
sudo ldconfig
```

### On VM2 (10.0.1.21):

```bash
cd ~/dpdk-23.11/app/test-pmd

# Backup original file
sudo cp txonly.c txonly.c.backup

# Modify IP addresses to match VM2's DPDK NIC IP (10.0.1.21) as source
# and VM1's DPDK NIC IP (10.0.1.20) as destination
sudo sed -i 's/#define IP_SRC_ADDR.*/#define IP_SRC_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 21)/' txonly.c
sudo sed -i 's/#define IP_DST_ADDR.*/#define IP_DST_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 20)/' txonly.c

# Verify changes
grep "IP_SRC_ADDR\|IP_DST_ADDR" txonly.c

# Expected output:
# #define IP_SRC_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 21)
# #define IP_DST_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 20)

# Rebuild DPDK
cd ~/dpdk-23.11/build
ninja
sudo ninja install
sudo ldconfig
```

## Interface Binding (MANA-Specific)

MANA requires binding the interface to `uio_hv_generic` before DPDK can use it. This is different from Mellanox which uses direct PCI binding.

### On Both VMs:

```bash
# Get interface details for eth1 (DPDK interface)
PRIMARY="eth1"
SECONDARY=$(ip -br link show master $PRIMARY | awk '{ print $1 }')
MANA_MAC=$(ip -br link show master $PRIMARY | awk '{ print $3 }')
BUS_INFO=$(ethtool -i $SECONDARY | grep bus-info | awk '{ print $2 }')

echo "Primary: $PRIMARY"
echo "Secondary: $SECONDARY" 
echo "MANA MAC: $MANA_MAC"
echo "Bus Info: $BUS_INFO"

# Set interfaces DOWN (required before binding)
sudo ip link set $PRIMARY down
sudo ip link set $SECONDARY down

# Bind to uio_hv_generic (MANA-specific requirement)
DEV_UUID=$(basename $(readlink /sys/class/net/$PRIMARY/device))
NET_UUID="f8615163-df3e-46c5-913f-f2d2f965ed0e"
sudo modprobe uio_hv_generic
echo $NET_UUID | sudo tee /sys/bus/vmbus/drivers/uio_hv_generic/new_id
echo $DEV_UUID | sudo tee /sys/bus/vmbus/drivers/hv_netvsc/unbind
echo $DEV_UUID | sudo tee /sys/bus/vmbus/drivers/uio_hv_generic/bind

echo "Interface binding complete!"
```

**Save your MAC addresses for testpmd commands:**
- VM1 MANA MAC: (e.g., 00:0d:3a:a3:65:1d)
- VM2 MANA MAC: (e.g., 00:0d:3a:a3:62:be)

## Running testpmd

### MANA-Specific Syntax

MANA uses **MAC address** for binding instead of PCI address:

```bash
--vdev="<BUS_INFO>,mac=<MAC_ADDRESS>"
```

### Start Receiver First (VM2):

```bash
sudo dpdk-testpmd -l 1-3 --vdev="7870:00:00.0,mac=<VM2_MAC>" -- \
  --forward-mode=rxonly \
  --auto-start \
  --txd=128 --rxd=128 \
  --stats-period 1
```

**Example for VM2:**
```bash
sudo dpdk-testpmd -l 1-3 --vdev="7870:00:00.0,mac=00:0d:3a:a3:62:be" -- \
  --forward-mode=rxonly \
  --auto-start \
  --txd=128 --rxd=128 \
  --stats-period 1
```

### Start Transmitter Second (VM1):

```bash
sudo dpdk-testpmd -l 1-3 --vdev="7870:00:00.0,mac=<VM1_MAC>" -- \
  --forward-mode=txonly \
  --eth-peer=0,<VM2_MAC> \
  --auto-start \
  --txd=128 --rxd=128 \
  --stats-period 1
```

**Example for VM1:**
```bash
sudo dpdk-testpmd -l 1-3 --vdev="7870:00:00.0,mac=00:0d:3a:a3:65:1d" -- \
  --forward-mode=txonly \
  --eth-peer=0,00:0d:3a:a3:62:be \
  --auto-start \
  --txd=128 --rxd=128 \
  --stats-period 1
```

## Performance Results

### Achieved Throughput (with IP modifications)

**VM2 (Receiver) Statistics:**
```
Port statistics ====================================
######################## NIC statistics for port 0  ########################
RX-packets: 8310768    RX-missed: 62209      RX-bytes:  531889152
RX-errors: 0
RX-nombuf:  0
TX-packets: 0          TX-errors: 0          TX-bytes:  0

Throughput (since last show)
Rx-pps:       780832          Rx-bps:    399786168
Tx-pps:            0          Tx-bps:            0
############################################################################
```

**Performance Summary:**
- **Throughput**: ~780K packets/second
- **Bandwidth**: ~400 Mbps
- **Packet Loss**: 0.74% (62,209 missed out of 8.3M)

**Note**: Performance is lower than Mellanox ConnectX-5 (~17M pps) due to:
1. rdma-core version mismatch (v39 vs required v44+)
2. Different hardware architecture (MANA vs Mellanox)
3. netvsc PMD coordination (warning: "hn_vf_attach(): Couldn't find port for VF")

## Troubleshooting

### 1. No Packets Received (Only 1-2 Packets)

**Symptom**: Transmitter shows millions of packets sent, but receiver shows only 1-2 packets received.

**Cause**: Azure vSwitch filtering packets due to incorrect IP addresses in testpmd packets.

**Solution**: Modify `txonly.c` source code to use actual VM IP addresses (see CRITICAL section above).

### 2. MANA Device Not Found

```bash
# Verify MANA hardware
lspci -d 1414:00ba

# If empty, check VM size
curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2021-02-01&format=text"

# MANA requires Dv6/Dv6i/Ev6/Mv3 or later
```

### 3. Failed to Create TX Queues

```
mana_start_tx_queues(): Failed to create qp queue index 0
mana_dev_start(): failed to start tx queues -19
```

**Cause**: Interface not set to DOWN before binding.

**Solution**:
```bash
sudo ip link set eth1 down
sudo ip link set enP30832s1d1 down
# Then retry binding commands
```

### 4. No Hugepages Available

```
EAL: No free 2048 kB hugepages reported on node 0
EAL: FATAL: Cannot get hugepage information.
```

**Solution**:
```bash
echo 512 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
grep Huge /proc/meminfo
```

### 5. Version Mismatch for rdma-core

**Symptom**: MANA InfiniBand devices (mana_0, manae_0) not visible to DPDK or ibv_devices.

**Cause**: rdma-core version too old (v39 vs required v44+) or driver ID mismatch.

**Workaround**: DPDK net_mana PMD can work without full rdma-core v44+ for basic packet forwarding, though performance may be impacted.

**Full Solution**: Build rdma-core v48+ from source (see Microsoft documentation).

### 6. Low Throughput with netvsc PMD

**Warning**: `hn_vf_attach(): Couldn't find port for VF`

This warning indicates netvsc PMD coordination issues but doesn't prevent packet forwarding. For production deployments, ensure kernel and rdma-core versions meet Microsoft's requirements.

## Key Differences: MANA vs Mellanox

| Aspect | MANA | Mellanox (ConnectX-5) |
|--------|------|----------------------|
| **VM Series** | Dv6/Dv6i/Ev6/Mv3+ | Dv5/Ev5/Mv5 |
| **Hardware** | Microsoft Silicon | NVIDIA Mellanox |
| **PCI ID** | 1414:00ba | 15b3:* |
| **Kernel Driver** | mana, mana_ib | mlx5_core, mlx5_ib |
| **DPDK PMD** | net_mana | mlx5 |
| **rdma-core Min** | v44+ | Earlier versions |
| **Binding Method** | MAC address | PCI address |
| **Interface Prep** | uio_hv_generic | Direct PCI binding |
| **EAL Syntax** | `--vdev="bus,mac=XX"` | `-a pci_address` |
| **Testpmd Command** | Uses --vdev with MAC | Uses -a with PCI |
| **IP Modification** | ✅ Required for VM-to-VM | ✅ Required for VM-to-VM |

**Common Requirement**: Both MANA and Mellanox require modifying testpmd source code IP addresses for VM-to-VM packet forwarding on Azure, though this is not documented in official guides.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Azure VNet                          │
│                        10.0.0.0/16                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   Subnet 10.0.1.0/24                  │  │
│  │                                                       │  │
│  │  ┌──────────────────┐         ┌──────────────────┐  │  │
│  │  │   VM1 (manavm1)  │         │   VM2 (manavm2)  │  │  │
│  │  │  D8s_v6 (MANA)   │         │  D8s_v6 (MANA)   │  │  │
│  │  ├──────────────────┤         ├──────────────────┤  │  │
│  │  │ eth0: 10.0.1.10  │◄───SSH──┤ eth0: 10.0.1.11  │  │  │
│  │  │  (Management)    │         │  (Management)    │  │  │
│  │  ├──────────────────┤         ├──────────────────┤  │  │
│  │  │ eth1: 10.0.1.20  │         │ eth1: 10.0.1.21  │  │  │
│  │  │   (DPDK/MANA)    │◄────────┤   (DPDK/MANA)    │  │  │
│  │  │  MAC: xx:65:1d   │  Packets│  MAC: xx:62:be   │  │  │
│  │  └──────────────────┘  780Kpps└──────────────────┘  │  │
│  │         │                             │              │  │
│  │         │                             │              │  │
│  │    ┌────▼─────────────────────────────▼────┐        │  │
│  │    │     MANA Hardware (7870:00:00.0)      │        │  │
│  │    │   Microsoft Azure Network Adapter     │        │  │
│  │    │    - uio_hv_generic binding           │        │  │
│  │    │    - MAC-based addressing             │        │  │
│  │    └───────────────────────────────────────┘        │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Files in This Repository

- `main.bicep` - Infrastructure template with hardware type selection
- `deploy.ps1` - Deployment script
- `cleanup.ps1` - Resource deletion script
- `MANA_DPDK_Setup_Guide.md` - This guide
- `DPDK_Setup_Guide.md` - Mellanox/ConnectX-5 setup guide
- `DPDK_Concepts.md` - Technical concepts (VF, SR-IOV, etc.)

## References

### Official Documentation
- [Microsoft MANA DPDK Guide](https://learn.microsoft.com/en-us/azure/virtual-network/setup-dpdk-mana)
- [DPDK MANA PMD Documentation](https://doc.dpdk.org/guides/nics/mana.html)
- [DPDK Official Documentation](https://doc.dpdk.org/)

### GitHub Repositories
- [DPDK Source](https://github.com/DPDK/dpdk)
- [Linux MANA Driver](https://github.com/torvalds/linux/tree/master/drivers/net/ethernet/microsoft/mana)
- [MANA InfiniBand Driver](https://github.com/torvalds/linux/tree/master/drivers/infiniband/hw/mana)
- [rdma-core](https://github.com/linux-rdma/rdma-core)

## Important Notes

1. **IP Address Modification is Critical**: Without modifying testpmd source code to use actual VM IPs, you will only receive 1-2 packets instead of millions. This applies to both MANA and Mellanox hardware.

2. **rdma-core Version**: Ubuntu 22.04 ships with rdma-core v39 which is older than the recommended v44+. Basic packet forwarding works but performance may be impacted.

3. **MAC Address Binding**: MANA uses MAC addresses instead of PCI addresses for DPDK binding. This is a key difference from Mellanox hardware.

4. **Dual NIC Recommended**: Use separate NICs for management (SSH) and DPDK to prevent connection loss when DPDK takes control.

5. **Performance**: MANA achieved ~780K pps compared to Mellanox ConnectX-5 which achieved ~17M pps. This may improve with proper rdma-core version and optimizations.

6. **Azure vSwitch**: The same packet filtering behavior applies to both MANA and Mellanox hardware on Azure infrastructure.

## Summary

MANA DPDK setup successfully demonstrates VM-to-VM packet forwarding on Azure with Microsoft's custom silicon. The critical undocumented requirement is modifying testpmd source code IP addresses to match actual VM IPs, confirming Azure's vSwitch filtering applies uniformly across hardware types.

---

**Last Updated**: January 14, 2026  
**Tested Environment**: Ubuntu 22.04 LTS, Kernel 6.8.0-1044-azure, DPDK 23.11, Standard_D8s_v6
