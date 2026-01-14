# Complete DPDK Setup Guide for Azure VMs

## Summary

Successfully deployed and tested DPDK on Azure achieving **17+ million packets per second** between two VMs.

---

## Prerequisites

### VM Requirements
- **VM Size**: Standard_D8s_v5 (ConnectX-5 required - older ConnectX-3 VMs don't work)
- **Region**: SoutheastAsia (or any Azure region)
- **OS**: Ubuntu 22.04 LTS
- **NICs**: Dual NICs
  - **eth0**: Management (NO accelerated networking) - for SSH
  - **eth1**: DPDK (Accelerated networking enabled)

### Why D8s_v5?
- ✅ ConnectX-5 VF with RDMA support
- ✅ Exposes `mlx5_ib` interfaces needed for DPDK
- ❌ D8s_v3 has ConnectX-3 (no RDMA in VMs) - doesn't work with DPDK

### Why Dual NICs?
- **eth0**: Keeps SSH alive when DPDK takes control of eth1
- **eth1**: Dedicated for DPDK - can be controlled without losing management access

---

## Step 1: Deploy VMs

### Bicep Configuration
```bicep
param vmSize string = 'Standard_D8s_v5'  // ConnectX-5 required

// Management NIC - NO accelerated networking
resource nic1mgmt 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  properties: {
    enableAcceleratedNetworking: false  // SSH safety
  }
}

// DPDK NIC - Accelerated networking enabled
resource nic1dpdk 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  properties: {
    enableAcceleratedNetworking: true  // For DPDK
  }
}
```

### Deployment
```powershell
az group create --name dpdk-lab-rg --location southeastasia
az deployment group create --resource-group dpdk-lab-rg --template-file main.bicep --parameters adminUsername=azureuser adminPassword='YourPassword'
```

---

## Step 2: Verify Hardware

SSH to VM and check:

```bash
# Check network interfaces
ip addr show
# Should see: eth0 (management), eth1 (DPDK), and VF slaves

# Check Mellanox hardware
lspci | grep -i mellanox
# Should show: MT27800 Family [ConnectX-5 Virtual Function]

# Verify RDMA devices (critical!)
ibv_devices
# Should show: mlx5_0, mlx5_1

ls -la /dev/infiniband/
# Should show: uverbs0, uverbs1, rdma_cm
```

**If `ibv_devices` is empty, DPDK won't work!**

---

## Step 3: Install DPDK Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install build tools and RDMA libraries (CRITICAL!)
sudo apt install -y build-essential meson ninja-build python3-pyelftools \
  libnuma-dev libpcap-dev pkg-config linux-headers-$(uname -r) \
  rdma-core ibverbs-utils libibverbs-dev

# Load RDMA kernel module
sudo modprobe mlx5_ib

# Verify module is loaded
lsmod | grep mlx5
```

---

## Step 4: Download and Build DPDK

```bash
# Download DPDK
cd ~
wget https://fast.dpdk.org/rel/dpdk-23.11.tar.xz
tar xf dpdk-23.11.tar.xz
cd dpdk-23.11
```

### **CRITICAL: Modify IP Addresses for Azure**

Before building, you **must** modify the source code to use your actual VM IPs:

```bash
# Edit testpmd source
nano app/test-pmd/txonly.c
```

**Find these lines** (around line 50-60):
```c
#define IP_SRC_ADDR ((198U << 24) | (18 << 16) | (0 << 8) | 1)
#define IP_DST_ADDR ((198U << 24) | (18 << 16) | (0 << 8) | 2)
```

**Change to your VM IPs**:

**On VM1 (10.0.1.20):**
```c
#define IP_SRC_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 20)
#define IP_DST_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 21)
```

**On VM2 (10.0.1.21):**
```c
#define IP_SRC_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 21)
#define IP_DST_ADDR ((10U << 24) | (0 << 16) | (1 << 8) | 20)
```

**Why this is required:**
- Azure's vSwitch validates packet headers
- Default IPs (198.18.0.x) are filtered by Azure
- Without correct IPs, packets are silently dropped

### Build DPDK

```bash
# Build with mlx5 support
meson setup build
cd build
ninja
sudo ninja install
sudo ldconfig
```

### Verify mlx5 driver was built

```bash
cat ~/dpdk-23.11/build/meson-logs/meson-log.txt | grep -i "mlx5\|ibverbs"
# Should show: Run-time dependency libmlx5 found: YES
# Should show: Run-time dependency libibverbs found: YES
```

---

## Step 5: Configure Hugepages

```bash
# Allocate 1GB of 2MB hugepages
echo 512 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Mount hugepages
sudo mkdir -p /mnt/huge
sudo mount -t hugetlbfs nodev /mnt/huge

# Verify
grep -i huge /proc/meminfo
# Should show: HugePages_Total: 512
```

---

## Step 6: Identify DPDK Interface

```bash
# Find PCI addresses
sudo dpdk-devbind.py --status

# Look for eth1's VF:
# Example output:
# fa9a:00:02.0 'MT27800 Family [ConnectX-5 Virtual Function]' if=enP64154s2 drv=mlx5_core

# Note the PCI address for eth1's VF (e.g., fa9a:00:02.0)
```

---

## Step 7: Run testpmd

### Get MAC Addresses

```bash
# On each VM, get eth1's MAC
ip addr show eth1
# VM1: 60:45:BD:1B:45:F7
# VM2: 60:45:BD:1C:9E:32
```

### On VM2 (Receiver)

```bash
sudo dpdk-testpmd \
  -l 0-3 \
  -n 4 \
  -a ecfc:00:02.0 \
  -- --port-topology=chained \
  --nb-cores 2 \
  --forward-mode=rxonly \
  --eth-peer=0,60:45:BD:1B:45:F7 \
  --stats-period 1
```

### On VM1 (Sender)

```bash
sudo dpdk-testpmd \
  -l 0-3 \
  -n 4 \
  -a fa9a:00:02.0 \
  -- --port-topology=chained \
  --nb-cores 2 \
  --forward-mode=txonly \
  --eth-peer=0,60:45:BD:1C:9E:32 \
  --stats-period 1
```

### Expected Results

VM2 should show:
```
Rx-pps:     17327928          Rx-bps:   8871899384
```

**17+ million packets per second!** 🎉

---

## Key Parameters Explained

| Parameter | Purpose |
|-----------|---------|
| `-l 0-3` | Use CPU cores 0-3 |
| `-n 4` | 4 memory channels |
| `-a <pci>` | Attach specific PCI device (eth1's VF) |
| `--port-topology=chained` | Single port forwarding |
| `--nb-cores 2` | Use 2 cores for packet processing |
| `--forward-mode=txonly/rxonly` | TX generates, RX receives |
| `--eth-peer=0,<MAC>` | Set destination MAC |
| `--stats-period 1` | Show stats every second |

---

## Troubleshooting

### No RDMA devices (`ibv_devices` empty)
**Problem**: ConnectX-3 VMs (D8s_v3) don't expose RDMA to VMs  
**Solution**: Use D8s_v5 or newer (ConnectX-5+)

### mlx5 driver not loaded
```bash
# Check if mlx5_ib is loaded
lsmod | grep mlx5

# If not, load it
sudo modprobe mlx5_ib
```

### Packets sent but not received
**Problem**: IP addresses in txonly.c don't match your VMs  
**Solution**: Edit `app/test-pmd/txonly.c` and rebuild DPDK

### SSH connection lost
**Problem**: DPDK took control of management interface  
**Solution**: Use dual NICs - eth0 (no accel) for SSH, eth1 (accel) for DPDK

### testpmd shows "No probed ethernet devices"
**Problem**: RDMA libraries missing during DPDK build  
**Solution**: Install rdma-core, libibverbs-dev, then rebuild DPDK

---

## Performance Results

| Metric | Value |
|--------|-------|
| **Packet Rate** | 17.3 million pps |
| **Throughput** | 8.87 Gbps |
| **Packet Size** | 64 bytes |
| **Packet Loss** | <0.01% |
| **VM Size** | Standard_D8s_v5 |
| **NIC** | ConnectX-5 VF |

---

## Architecture Summary

```
┌─────────────────────────────────────────────────────────┐
│                   dpdk-vnet (10.0.0.0/16)               │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │         dpdk-subnet (10.0.1.0/24)                │  │
│  │                                                  │  │
│  │   ┌────────────────┐      ┌────────────────┐    │  │
│  │   │    dpdkvm1     │      │    dpdkvm2     │    │  │
│  │   │  D8s_v5        │      │  D8s_v5        │    │  │
│  │   │                │      │                │    │  │
│  │   │ eth0: 10.0.1.10│      │ eth0: 10.0.1.11│    │  │
│  │   │ (mgmt, no acc) │      │ (mgmt, no acc) │    │  │
│  │   │                │      │                │    │  │
│  │   │ eth1: 10.0.1.20│◄────►│ eth1: 10.0.1.21│    │  │
│  │   │ (DPDK, accel)  │ 17Mpps│ (DPDK, accel) │    │  │
│  │   │ ConnectX-5 VF  │      │ ConnectX-5 VF  │    │  │
│  │   └────────────────┘      └────────────────┘    │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Critical Success Factors

1. ✅ **VM Size**: Must be v5-series (ConnectX-5) or newer
2. ✅ **RDMA Support**: `ibv_devices` must show mlx5 devices
3. ✅ **Dual NICs**: eth0 for management, eth1 for DPDK
4. ✅ **IP Modification**: Edit txonly.c before building
5. ✅ **Dependencies**: Install rdma-core before building DPDK
6. ✅ **Hugepages**: Configure before running testpmd

---

## Reference

- [Microsoft Azure DPDK Guide](https://learn.microsoft.com/en-us/azure/virtual-network/setup-dpdk)
- [DPDK Documentation](https://doc.dpdk.org/guides/)
- [mlx5 PMD Guide](https://doc.dpdk.org/guides/nics/mlx5.html)

---

## Deployment Files

- **Bicep Template**: `main.bicep` - Deploys dual-NIC VMs with D8s_v5
- **Deploy Script**: `deploy.ps1` - Automated deployment
- **Cleanup Script**: `cleanup.ps1` - Resource cleanup
- **Concepts Guide**: `DPDK_Concepts.md` - Technical background

**Repository**: `c:\Bicep_GithubCode\DPDK_VM_Setup\`

---

**Status**: ✅ Fully operational - 17+ Mpps achieved  
**Last Updated**: January 14, 2026
