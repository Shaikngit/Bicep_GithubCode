# UDP Port Testing with MANA DPDK (IKE Packet Testing)

## Overview
This guide documents how to test DPDK transmission with specific UDP ports by modifying testpmd source code. This procedure was used to test IKE packets (UDP port 500) to address customer complaints about IKE packet transmission via MANA DPDK.

## Prerequisites
- Two MANA VMs deployed (Standard_D8s_v6) with dual NICs
- DPDK 23.11 installed on both VMs
- Hugepages configured (512x 2MB)
- Management access via eth0 (do not bind to DPDK)
- DPDK interface on eth1

## VM Configuration
- **VM1**: 
  - Management IP: 10.0.1.10 (eth0)
  - DPDK IP: 10.0.1.20 (eth1)
  - DPDK MAC: 00:0d:3a:a3:65:1d
  
- **VM2**: 
  - Management IP: 10.0.1.11 (eth0)
  - DPDK IP: 10.0.1.21 (eth1)
  - DPDK MAC: 00:0d:3a:a3:62:be

## Step 1: Modify testpmd Source Code (Both VMs)

### On VM1 (Transmitter - 10.0.1.20 → 10.0.1.21):
```bash
cd ~/dpdk-23.11/app/test-pmd

# Change UDP source port from 9 to 500
sudo sed -i 's/uint16_t tx_udp_src_port = 9;/uint16_t tx_udp_src_port = 500;/' txonly.c

# Change UDP destination port from 9 to 500
sudo sed -i 's/uint16_t tx_udp_dst_port = 9;/uint16_t tx_udp_dst_port = 500;/' txonly.c

# Verify the changes
grep "tx_udp_src_port\|tx_udp_dst_port" txonly.c

# Verify IP addresses are correct (should be 10.0.1.20 → 10.0.1.21)
grep "tx_ip_src_addr\|tx_ip_dst_addr" txonly.c
```

**Expected output for IP verification:**
```
uint32_t tx_ip_src_addr = (10U << 24) | (0 << 16) | (1 << 8) | 20;  // 10.0.1.20
uint32_t tx_ip_dst_addr = (10U << 24) | (0 << 16) | (1 << 8) | 21;  // 10.0.1.21
```

### On VM2 (Receiver - 10.0.1.21 → 10.0.1.20):
```bash
cd ~/dpdk-23.11/app/test-pmd

# Change UDP ports to 500
sudo sed -i 's/uint16_t tx_udp_src_port = 9;/uint16_t tx_udp_src_port = 500;/' txonly.c
sudo sed -i 's/uint16_t tx_udp_dst_port = 9;/uint16_t tx_udp_dst_port = 500;/' txonly.c

# Verify the changes
grep "tx_udp_src_port\|tx_udp_dst_port" txonly.c

# Verify IP addresses (should be 10.0.1.21 → 10.0.1.20)
grep "tx_ip_src_addr\|tx_ip_dst_addr" txonly.c
```

## Step 2: Rebuild DPDK (Both VMs)

```bash
cd ~/dpdk-23.11/build
ninja
sudo ninja install
sudo ldconfig
```

## Step 3: Bind Interfaces to DPDK (Both VMs)

### Set Environment Variables:
```bash
export NET_UUID="f8615163-df3e-46c5-913f-f2d2f965ed0e"
export DEV_UUID=$(basename $(readlink /sys/class/net/eth1/device))
```

### Verify Variables:
```bash
echo "NET_UUID: $NET_UUID"
echo "DEV_UUID: $DEV_UUID"
```

### Bind to uio_hv_generic:
```bash
sudo modprobe uio_hv_generic
echo $NET_UUID | sudo tee /sys/bus/vmbus/drivers/uio_hv_generic/new_id
echo $DEV_UUID | sudo tee /sys/bus/vmbus/drivers/hv_netvsc/unbind
echo $DEV_UUID | sudo tee /sys/bus/vmbus/drivers/uio_hv_generic/bind
```

### Verify Binding:
```bash
~/dpdk-23.11/usertools/dpdk-devbind.py --status
```

## Step 4: Start testpmd Receiver (VM2)

```bash
sudo ~/dpdk-23.11/build/app/dpdk-testpmd -l 1-3 \
  --vdev="7870:00:00.0,mac=00:0d:3a:a3:62:be" -- \
  --forward-mode=rxonly \
  --eth-peer=0,00:0d:3a:a3:65:1d \
  --auto-start \
  --txd=128 \
  --rxd=128 \
  --stats-period 1
```

**Parameters explained:**
- `-l 1-3`: Use CPU cores 1-3
- `--vdev="7870:00:00.0,mac=00:0d:3a:a3:62:be"`: MANA device with VM2's MAC
- `--forward-mode=rxonly`: Receive-only mode
- `--eth-peer=0,00:0d:3a:a3:65:1d`: VM1's MAC address
- `--auto-start`: Start forwarding automatically
- `--txd=128 --rxd=128`: TX/RX descriptor ring sizes
- `--stats-period 1`: Display statistics every 1 second

## Step 5: Start testpmd Transmitter (VM1)

```bash
sudo ~/dpdk-23.11/build/app/dpdk-testpmd -l 1-3 \
  --vdev="7870:00:00.0,mac=00:0d:3a:a3:65:1d" -- \
  --forward-mode=txonly \
  --eth-peer=0,00:0d:3a:a3:62:be \
  --auto-start \
  --txd=128 \
  --rxd=128 \
  --stats-period 1
```

**Parameters explained:**
- `--vdev="7870:00:00.0,mac=00:0d:3a:a3:65:1d"`: MANA device with VM1's MAC
- `--forward-mode=txonly`: Transmit-only mode (generates packets)
- `--eth-peer=0,00:0d:3a:a3:62:be`: VM2's MAC address

## Expected Results

### On VM1 (Transmitter):
```
Port statistics ====================================
  ######################## NIC statistics for port 0  ########################
  TX-packets: 4750000      TX-errors: 0             TX-bytes:  304000000
  Throughput (since last show)
  Tx-pps:        780000          Tx-bps:    399360000
```

### On VM2 (Receiver):
```
Port statistics ====================================
  ######################## NIC statistics for port 0  ########################
  RX-packets: 4750000      RX-missed: 0             RX-bytes:  304000000
  Throughput (since last show)
  Rx-pps:        780000          Rx-bps:    399360000
```

**Typical Performance:** ~780K packets per second with MANA hardware

## Step 6: Verify UDP Port 500 Packets

### Option 1: Using tcpdump (Requires temporarily unbinding from DPDK)

On **VM2**:
```bash
# Stop testpmd (Ctrl+C)

# Unbind from DPDK
export DEV_UUID=$(basename $(readlink /sys/class/net/eth1/device) 2>/dev/null || echo "check manually")
echo $DEV_UUID | sudo tee /sys/bus/vmbus/drivers/uio_hv_generic/unbind
echo $DEV_UUID | sudo tee /sys/bus/vmbus/drivers/hv_netvsc/bind

# Wait for interface to come up
sleep 2

# Capture UDP port 500 packets
sudo tcpdump -i eth1 -n udp port 500 -c 10 -v
```

**Expected output:**
```
10:15:32.123456 IP (tos 0x0, ttl 64, id 0, offset 0, flags [none], proto UDP (17), length 46)
    10.0.1.20.500 > 10.0.1.21.500: UDP, length 18
```

### Option 2: Using testpmd Verbose Mode

In the **testpmd console** (VM2):
```
testpmd> set verbose 1
testpmd> start
```

This will display packet headers showing UDP port 500 details.

## Troubleshooting

### No packets received on VM2:
1. Verify MAC addresses match your VMs
2. Ensure both VMs have modified source code and rebuilt DPDK
3. Check that interfaces are bound to DPDK on both VMs
4. Verify hugepages are configured: `grep HugePages /proc/meminfo`

### Cannot verify port numbers:
- testpmd statistics only show packet counts, not protocol details
- Use tcpdump or verbose mode to inspect packet headers

### Performance lower than expected:
- MANA typically achieves ~780K pps vs Mellanox 17M pps
- Consider upgrading rdma-core to v44+ (current v39)
- Verify kernel version is 6.2+ (current 6.8.0-1044-azure)

## Protocol Variations

### To test different protocols, modify txonly.c:

**For ICMP packets:**
```c
// Change next_proto_id from IPPROTO_UDP to IPPROTO_ICMP
pkt->l3_len = sizeof(struct rte_ipv4_hdr);
pkt->l4_len = 0;  // ICMP has no L4 header in DPDK context
```

**For different UDP ports:**
```c
uint16_t tx_udp_src_port = 4500;  // IKE NAT-T
uint16_t tx_udp_dst_port = 4500;
```

## Key Findings

✅ **Working:** IKE packets (UDP port 500) transmit successfully via MANA DPDK  
✅ **Performance:** ~780K pps sustained throughput  
✅ **Verification:** tcpdump confirms UDP port 500 in packet headers  
✅ **Compatibility:** testpmd is globally accepted standard for DPDK testing  

## References
- Main MANA setup guide: [MANA_DPDK_Setup_Guide.md](MANA_DPDK_Setup_Guide.md)
- DPDK testpmd documentation: https://doc.dpdk.org/guides/testpmd_app_ug/
- MANA PMD documentation: https://doc.dpdk.org/guides/nics/mana.html
