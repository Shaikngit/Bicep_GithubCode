# Azure EastUS2 MTU and Fragmentation Repro Lab

This lab deploys two Ubuntu 22.04 Linux VMs in EastUS2 on accelerated networking capable Overlake hardware and gives a repeatable workflow to reproduce and analyze:

- Oversized packet fragmentation
- ICMP packet loss on fragmented traffic
- TCP retransmissions
- GRO, GSO, and TSO offload effects
- Packet capture differences on synthetic interface and accelerated networking VF path

## 1. Lab Topology

- Resource group: rg-mtu-lab-eastus2
- Region: eastus2
- VNet: vnet-mtu-lab (10.235.0.0/16)
- Subnet: subnet-lab (10.235.1.0/24)
- NSG inbound rules:
  - SSH 22/TCP
  - ICMP
  - iperf3 5201/TCP
- VMs:
  - vm-mtu-src: public IP + private IP
  - vm-mtu-dst: private IP only
- VM size default: Standard_D4s_v5
- Accelerated networking: enabled on both NICs
- Authentication:
  - Password authentication enabled
  - SSH key authentication not required

## 2. Files

- main.bicep: infrastructure deployment
- parameters.json: deployment values
- deploy.ps1: PowerShell deployment script (recommended on Windows)
- cleanup.ps1: PowerShell cleanup script (recommended on Windows)
- deploy.sh: resource group creation + deployment + output extraction
- cleanup.sh: resource group cleanup

## 3. Prerequisites

- Azure CLI installed
- Logged in with az login
- Subscription selected with az account set --subscription <subscription-id>
- Strong password ready

## 4. Deploy

1. Update adminPassword in parameters.json.
2. Run deployment script.

PowerShell (Windows):

```powershell
Set-Location .\MTU_Overlake_EastUS2_Lab
.\deploy.ps1
```

Optional what-if preview:

```powershell
.\deploy.ps1 -WhatIf
```

Bash (optional):

```bash
cd MTU_Overlake_EastUS2_Lab
bash deploy.sh
```

3. Optional: ensure scripts are executable.

```bash
chmod +x deploy.sh cleanup.sh
```

## 5. Get Deployment Outputs

The deployment outputs include:

- sourceVmPublicIp
- sourceVmPrivateIp
- destinationVmPrivateIp
- sourceNicOutputName
- destinationNicOutputName

You can read outputs again with:

```bash
az deployment group list \
  --resource-group rg-mtu-lab-eastus2 \
  --query "[0].name" -o tsv
```

```bash
az deployment group show \
  --resource-group rg-mtu-lab-eastus2 \
  --name <deployment-name> \
  --query properties.outputs -o json
```

## 6. Connect to Source VM and Install Tools

Get source public IP:

```bash
SRC_PUBLIC_IP=$(az vm show -d -g rg-mtu-lab-eastus2 -n vm-mtu-src --query publicIps -o tsv)
echo "$SRC_PUBLIC_IP"
```

SSH to source VM:

```bash
ssh azureuser@${SRC_PUBLIC_IP}
```

Install required packages on source VM:

```bash
sudo apt update
sudo apt install -y tcpdump iperf3 ethtool net-tools traceroute
```

Install same packages on destination VM from Azure CLI (so both endpoints are ready):

```bash
az vm run-command invoke \
  -g rg-mtu-lab-eastus2 \
  -n vm-mtu-dst \
  --command-id RunShellScript \
  --scripts "sudo apt update && sudo apt install -y tcpdump iperf3 ethtool net-tools traceroute"
```

## 7. VM Validation

On each VM run:

```bash
ip addr
ethtool -S eth0
lspci
```

Expected signs for accelerated networking:

- Mellanox/NVIDIA virtual function device visible in lspci
- ethtool statistics on eth0 include synthetic and VF related counters

Find likely VF netdevice name dynamically:

```bash
for i in /sys/class/net/*; do
  dev=$(basename "$i")
  [ -f "$i/device/vendor" ] || continue
  vendor=$(cat "$i/device/vendor")
  device=$(cat "$i/device/device")
  printf "%s vendor=%s device=%s\n" "$dev" "$vendor" "$device"
done
```

If a second interface is present, treat it as VF candidate for side-by-side capture.

## 8. MTU Validation

Show MTU:

```bash
ip a
```

Set temporary MTU to 3872 for the larger-packet test:

```bash
sudo ip link set dev eth0 mtu 3872
```

Revert MTU to 1500 when you are done:

```bash
sudo ip link set dev eth0 mtu 1500
```

## 9. Offload Validation

View current offload state:

```bash
sudo ethtool -k eth0
```

Disable offloads on eth0:

```bash
sudo ethtool -K eth0 gro off
sudo ethtool -K eth0 gso off
sudo ethtool -K eth0 tso off
```

Re-enable offloads on eth0:

```bash
sudo ethtool -K eth0 gro on
sudo ethtool -K eth0 gso on
sudo ethtool -K eth0 tso on
```

Repeat on VF interface (replace <vf-iface>):

```bash
sudo ethtool -k <vf-iface>
sudo ethtool -K <vf-iface> gro off
sudo ethtool -K <vf-iface> gso off
sudo ethtool -K <vf-iface> tso off
```

```bash
sudo ethtool -K <vf-iface> gro on
sudo ethtool -K <vf-iface> gso on
sudo ethtool -K <vf-iface> tso on
```

## 10. Packet Capture

Do not use -i any for this lab.

Use explicit interfaces and snaplen 74:

```bash
sudo tcpdump -i eth0 -nn -s 74 -w eth0_capture.pcap host <peer-ip>
```

```bash
sudo tcpdump -i eth1 -nn -s 74 -w eth1_capture.pcap host <peer-ip>
```

Why not -i any:

- It produces Linux cooked capture format instead of native per-interface L2 framing.
- Cooked captures abstract away interface-specific metadata and can hide details required for fragmentation and path-level analysis.
- You cannot cleanly compare synthetic path versus VF path when packets are merged through cooked capture abstraction.

## 11. ICMP Fragmentation Repro

Run from source to destination private IP.

Recommended DF validation for the 3872 MTU test:

```bash
ping -M do -s 2000 -c 500 <peer-ip>
```

Packet math:

- 2000 + 8 + 20 = 2028 bytes

Standard MTU boundary test:

```bash
ping -s 1473 -c 500 <peer-ip>
```

Packet math:

- 1473 + 8 + 20 = 1501 bytes

Larger fragmentation test:

```bash
ping -s 2001 -c 500 <peer-ip>
```

Packet math:

- 2001 + 8 + 20 = 2029 bytes

## 12. iperf3 Testing

On destination VM:

```bash
iperf3 -s
```

On source VM:

```bash
iperf3 -c <peer-ip> --dont-fragment -M 2000 -l 2000 -P 8 -t 120
```

This test uses a 2000-byte TCP payload/MSS while DF is enabled so you can compare retransmissions and throughput against the MTU 3872 setting.

## 13. Analysis Guidance

### Compare eth0 vs VF captures

- Start captures on both interfaces at the same time window.
- Use identical filters and snaplen.
- Compare packet counts and timing around fragmentation or retransmission periods.

### Identify fragmented packets

- In Wireshark, inspect IPv4 flags and fragment offset.
- First fragment typically has MF=1 and offset 0.
- Subsequent fragments have increasing fragment offset.

### Identify missing fragments

- Look for sequences where an initial fragment is present but one or more follow-on fragment offsets are absent.
- Correlate with ping loss spikes or ICMP echo reply gaps.

### Identify TCP retransmissions

- In Wireshark use tcp.analysis.retransmission display filter.
- Correlate retransmission bursts with offload mode and packet loss windows.

### GRO/GSO/TSO impact on captures

- With offloads enabled, host captures may show larger coalesced packets that are not wire-accurate.
- With offloads disabled, captures are usually closer to on-wire segmentation behavior.
- Comparing enabled versus disabled states is required before concluding true network-level fragmentation or loss.

## 14. Suggested Test Matrix

Run each scenario while collecting captures on both source and destination:

1. Baseline MTU 1500 with offloads on
2. Baseline MTU 1500 with offloads off
3. MTU 3872 with offloads on
4. MTU 3872 with offloads off
5. ICMP size 2000 with DF under each mode
6. iperf3 parallel streams with 2000-byte payload/MSS under each mode

## 15. Cleanup

PowerShell (Windows):

```powershell
.\cleanup.ps1
```

Non-interactive cleanup:

```powershell
.\cleanup.ps1 -Force
```

Bash (optional):

```bash
bash cleanup.sh
```

## 16. Notes

- This lab is intentionally isolated to EastUS2 for reproducibility.
- Overlake class VM SKUs can vary by subscription capacity; if Standard_D4s_v5 is unavailable, use a larger accelerated networking capable Dsv5 SKU.
