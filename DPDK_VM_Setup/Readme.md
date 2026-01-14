# DPDK VM Setup Lab

This lab deploys two Ubuntu VMs in the SoutheastAsia region configured for DPDK testing.

## Infrastructure

| Resource | Details |
|----------|---------|
| VMs | 2x Standard_D8s_v3 (8 vCPUs, 32 GB RAM) |
| OS | Ubuntu 22.04 LTS Gen2 |
| Region | SoutheastAsia |
| VNet | 10.0.0.0/16 |
| DPDK Subnet | 10.0.1.0/24 |
| VM1 IP | 10.0.1.10 |
| VM2 IP | 10.0.1.11 |
| Accelerated Networking | Enabled (Required for DPDK) |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   dpdk-vnet (10.0.0.0/16)           │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │         dpdk-subnet (10.0.1.0/24)           │   │
│  │                                             │   │
│  │   ┌───────────┐         ┌───────────┐      │   │
│  │   │  dpdkvm1  │         │  dpdkvm2  │      │   │
│  │   │ D8s_v3    │◄───────►│ D8s_v3    │      │   │
│  │   │10.0.1.10  │  DPDK   │10.0.1.11  │      │   │
│  │   │ AccelNet  │ Traffic │ AccelNet  │      │   │
│  │   └───────────┘         └───────────┘      │   │
│  │                                             │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │    AzureBastionSubnet (10.0.2.0/26)         │   │
│  │              ┌──────────┐                   │   │
│  │              │ Bastion  │                   │   │
│  │              └──────────┘                   │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Deployment

```powershell
.\deploy.ps1
```

## Access VMs

Use Azure Bastion to connect to the VMs securely via the Azure Portal.

## DPDK Setup Steps (Manual)

After VMs are deployed, follow these steps on each VM:

### 1. Verify Accelerated Networking

```bash
# Check for Mellanox VF (Virtual Function)
lspci | grep -i mellanox

# Should show something like:
# 0002:00:02.0 Ethernet controller: Mellanox Technologies MT27710 Family [ConnectX-4 Lx Virtual Function]
```

### 2. Check Network Interfaces

```bash
# List interfaces - you should see eth0 and a VF interface
ip addr show

# The VF interface (e.g., enP30832p0s2) is used for DPDK
```

### 3. Install DPDK Dependencies

```bash
sudo apt update
sudo apt install -y build-essential meson ninja-build python3-pyelftools libnuma-dev libpcap-dev

# Install Mellanox OFED drivers (optional but recommended)
# Download from: https://network.nvidia.com/products/infiniband-drivers/linux/mlnx_ofed/
```

### 4. Download and Build DPDK

```bash
# Download DPDK
wget https://fast.dpdk.org/rel/dpdk-23.11.tar.xz
tar xf dpdk-23.11.tar.xz
cd dpdk-23.11

# Build DPDK
meson setup build
cd build
ninja
sudo ninja install
sudo ldconfig
```

### 5. Configure Hugepages

```bash
# Configure 1GB hugepages (recommended for DPDK)
echo 2048 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Mount hugepages
sudo mkdir -p /mnt/huge
sudo mount -t hugetlbfs nodev /mnt/huge
```

### 6. Test DPDK

```bash
# Run testpmd (example)
sudo dpdk-testpmd -l 0-3 -n 4 -- -i
```

## Cleanup

```powershell
.\cleanup.ps1
```

## Notes

- **D8s_v3** is chosen because it supports accelerated networking and provides 8 vCPUs for DPDK cores
- **Accelerated Networking** exposes the Mellanox VF which DPDK can poll directly
- The VMs have **static IPs** for consistent testing (10.0.1.10 and 10.0.1.11)
- **Azure Bastion** is used for secure access without exposing public IPs
