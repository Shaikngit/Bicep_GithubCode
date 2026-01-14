# DPDK and Accelerated Networking Concepts

## VM Verification Output

### dpdkvm1 (10.0.1.10)
```bash
azureuser@dpdkvm1:~$ lspci | grep -i mellanox
68c5:00:02.0 Ethernet controller: Mellanox Technologies MT27710 Family [ConnectX-4 Lx Virtual Function] (rev 80)

azureuser@dpdkvm1:~$ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 60:45:bd:1d:a4:30 brd ff:ff:ff:ff:ff:ff
    inet 10.0.1.10/24 metric 100 brd 10.0.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::6245:bdff:fe1d:a430/64 scope link 
       valid_lft forever preferred_lft forever
3: enP26821s1: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc mq master eth0 state UP group default qlen 1000
    link/ether 60:45:bd:1d:a4:30 brd ff:ff:ff:ff:ff:ff
    altname enP26821p0s2
    inet6 fe80::6245:bdff:fe1d:a430/64 scope link 
       valid_lft forever preferred_lft forever
```

### dpdkvm2 (10.0.1.11)
```bash
azureuser@dpdkvm2:~$ lspci | grep -i mellanox
05bd:00:02.0 Ethernet controller: Mellanox Technologies MT27710 Family [ConnectX-4 Lx Virtual Function] (rev 80)

azureuser@dpdkvm2:~$ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 7c:ed:8d:b4:b9:77 brd ff:ff:ff:ff:ff:ff
    inet 10.0.1.11/24 metric 100 brd 10.0.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::7eed:8dff:feb4:b977/64 scope link 
       valid_lft forever preferred_lft forever
3: enP1469s1: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc mq master eth0 state UP group default qlen 1000
    link/ether 7c:ed:8d:b4:b9:77 brd ff:ff:ff:ff:ff:ff
    altname enP1469p0s2
    inet6 fe80::7eed:8dff:feb4:b977/64 scope link 
       valid_lft forever preferred_lft forever
```

### Summary Table

| VM | Mellanox VF PCI Address | VF Interface | IP Address |
|----|------------------------|--------------|------------|
| dpdkvm1 | `68c5:00:02.0` | `enP26821s1` | 10.0.1.10 |
| dpdkvm2 | `05bd:00:02.0` | `enP1469s1` | 10.0.1.11 |

---

## What is Mellanox VF PCI Address?

**PCI Address** (e.g., `68c5:00:02.0`) is the unique identifier for a hardware device on the PCI bus - think of it like a street address for hardware inside your VM.

**Mellanox** is a company (now owned by NVIDIA) that makes high-performance network cards (NICs). Azure uses Mellanox ConnectX-4 cards in their datacenters.

**VF (Virtual Function)** is a key concept:

```
┌─────────────────────────────────────────────────────────┐
│              Azure Physical Host                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │     Mellanox Physical NIC (PF - Physical Func)  │   │
│  │                                                 │   │
│  │   ┌─────────┐  ┌─────────┐  ┌─────────┐        │   │
│  │   │  VF #1  │  │  VF #2  │  │  VF #3  │  ...   │   │
│  │   └────┬────┘  └────┬────┘  └────┬────┘        │   │
│  └────────┼────────────┼────────────┼─────────────┘   │
│           │            │            │                  │
│     ┌─────▼─────┐ ┌────▼─────┐ ┌────▼─────┐           │
│     │   VM 1    │ │   VM 2   │ │   VM 3   │           │
│     │ (dpdkvm1) │ │(dpdkvm2) │ │  (other) │           │
│     └───────────┘ └──────────┘ └──────────┘           │
└─────────────────────────────────────────────────────────┘
```

With **SR-IOV (Single Root I/O Virtualization)**, the physical NIC creates multiple "virtual copies" of itself (VFs). Each VM gets its own VF, which means:
- **Direct hardware access** - bypasses the hypervisor
- **Near bare-metal performance** - much faster than software emulation

---

## What is VF Interface?

The **VF Interface** (e.g., `enP26821s1`) is the Linux network interface name for that Virtual Function inside your VM.

### How it works in your VMs:

```
┌─────────────────────────────────────────┐
│              Your VM (dpdkvm1)          │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │    eth0 (10.0.1.10)             │   │
│  │    ↑                            │   │
│  │    │ bonded together            │   │
│  │    ↓                            │   │
│  │    enP26821s1 (VF interface)    │◄──┼── Direct to Mellanox VF hardware
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

---

## Network Path Comparison

### Without Accelerated Networking (Slow)
```
App → Linux Kernel → Hypervisor (slow software switch) → Physical NIC
```

### With Accelerated Networking (What you have now)
```
App → Linux Kernel → VF → Physical NIC (bypasses hypervisor!)
```

### With DPDK (What you'll set up)
```
App → DPDK (polls VF directly, bypasses kernel too!) → Physical NIC
```

---

## Why This Matters for DPDK

DPDK will:
1. Take control of the VF interface (`enP26821s1` on VM1, `enP1469s1` on VM2)
2. Use **poll-mode drivers** instead of interrupts
3. Process packets entirely in userspace
4. Achieve **millions of packets per second**

This is why you needed **D8s_v3** - it supports SR-IOV/Accelerated Networking which exposes the Mellanox VF that DPDK requires.

---

## Key Terminology

| Term | Description |
|------|-------------|
| **SR-IOV** | Single Root I/O Virtualization - allows a single PCIe device to appear as multiple devices |
| **PF (Physical Function)** | The main/real NIC on the Azure host |
| **VF (Virtual Function)** | A lightweight "copy" of the PF assigned to your VM |
| **Accelerated Networking** | Azure's feature that enables SR-IOV for VMs |
| **DPDK** | Data Plane Development Kit - framework for fast packet processing |
| **Poll-mode driver** | Driver that constantly checks for packets instead of waiting for interrupts |
| **Hugepages** | Large memory pages (2MB or 1GB) used by DPDK for better performance |

---

## Useful Commands

```bash
# Check if Mellanox VF is present
lspci | grep -i mellanox

# List network interfaces
ip addr show

# Check interface details
ethtool -i enP26821s1

# Check if accelerated networking is working
ethtool -S eth0 | grep vf_

# View hugepages configuration
cat /proc/meminfo | grep -i huge
```

---

## Single NIC and SSH Safety - Will I Lose SSH When Binding VF to DPDK?

**No, you won't lose SSH** even with a single NIC. Azure's Accelerated Networking has a built-in failover mechanism.

### Azure's Dual-Path Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                        Your VM (dpdkvm1)                       │
│                                                                │
│   ┌──────────────────────────────────────────────────────┐    │
│   │                    eth0 (netvsc)                     │    │
│   │                    10.0.1.10                         │    │
│   │                                                      │    │
│   │    ┌─────────────────┐    ┌─────────────────┐       │    │
│   │    │  Synthetic Path │    │    VF Path      │       │    │
│   │    │  (Hypervisor)   │    │  (SR-IOV/DPDK)  │       │    │
│   │    │    BACKUP       │    │    PRIMARY      │       │    │
│   │    └────────┬────────┘    └────────┬────────┘       │    │
│   └─────────────┼──────────────────────┼────────────────┘    │
│                 │                      │                      │
└─────────────────┼──────────────────────┼──────────────────────┘
                  │                      │
                  ▼                      ▼
        ┌─────────────────┐    ┌─────────────────┐
        │   Hypervisor    │    │   Mellanox VF   │
        │  (slower but    │    │  (fast, direct  │
        │   always works) │    │   hardware)     │
        └─────────────────┘    └─────────────────┘
```

### What Happens When You Bind VF to DPDK

| Component | Before DPDK | After Binding VF to DPDK |
|-----------|-------------|--------------------------|
| **eth0** | Uses VF for traffic | Falls back to synthetic path |
| **VF (enP26821s1)** | Bonded to eth0 | Controlled by DPDK |
| **SSH** | Works via VF (fast) | Works via synthetic (slower, but works!) |

### The Azure netvsc Failover

Azure's `netvsc` driver (which manages eth0) has **automatic failover**:

```
Normal operation:     eth0 → VF (enP26821s1) → Physical NIC  [FAST]
                            ↓
When VF is unbound:   eth0 → Hypervisor → Physical NIC      [SLOWER but SSH works!]
```

### Why You're Safe:

1. **eth0 has TWO paths** - VF (primary) and synthetic (backup)
2. When DPDK takes the VF, **eth0 automatically uses the synthetic path**
3. SSH continues working through eth0 (just slower ~1-2 Gbps instead of 25 Gbps)

### Best Practice (Optional)

For production DPDK setups, you could add a **second NIC** dedicated to management:

```
Management NIC (no accelerated networking, SSH only)
DPDK NIC (accelerated networking, for DPDK traffic)
```

But for lab/testing, **the single NIC setup is perfectly fine** - Azure's failover mechanism will keep SSH alive.

### Verify After Binding

After you bind VF to DPDK, verify SSH still works:
```bash
# Check eth0 is using synthetic path (no VF slave)
ip addr show eth0

# SSH should still work, just through hypervisor
```
