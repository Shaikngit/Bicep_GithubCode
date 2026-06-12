# East US 2 Lab Validation Steps for MTU and Iperf Behavior

Hi [Customer Name],

As discussed, we reproduced the test flow in our East US 2 lab to validate the MTU-related behavior under a controlled setup. Below are the same steps we used so you can run them in your lab and share the results back with us.

## 1. Upgrade iperf3 to version 3.10

We upgraded to iperf3 3.10 so the tool supports the IPv4 Don't Fragment option. This is important because it allows us to test MTU behavior without fragmentation being hidden by the network stack.

Run these commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential git autoconf automake libtool pkg-config
cd /tmp
rm -rf iperf
git clone https://github.com/esnet/iperf.git
cd iperf
git fetch --tags
git checkout 3.10
./configure
make -j"$(nproc)"
sudo make install
sudo ldconfig
```

Verify the version:

```bash
iperf3 -v
iperf3 -h | grep -i fragment
```

Expected result:

- You should see `iperf 3.10`
- You should see `--dont-fragment set IPv4 Don't Fragment flag`

## 2. Set and verify the MTU on both VMs

For this validation, we set the MTU on both endpoints to `3872` and verified the interface configuration on each side.

Check the current MTU:

```bash
ip addr show eth0
ip link show eth0
```

If you need to set the MTU for the test:

```bash
sudo ip link set dev eth0 mtu 3872
```

Verify again:

```bash
ip link show eth0
```

Expected result:

- The MTU should reflect the value you set, for example `mtu 3872`

## 3. Start the iperf3 server on the destination VM

This VM should listen for incoming traffic before the client test is started.

Command on the destination VM:

```bash
iperf3 -s
```

Expected result:

- `iperf3` waits for a client connection on port `5201`

## 4. Run a ping test with the DF bit before iperf

Before starting the iperf test, we also recommend running a ping test with the Don't Fragment flag. This is a quick way to confirm that the path supports the selected MTU before sending the TCP iperf traffic.

Command on the source VM:

```bash
ping -M do -s 2000 -c 10 10.235.1.4
```

What this does:

- `-M do` sets the IPv4 Don't Fragment bit
- `-s 2000` sends an ICMP payload that corresponds to the MTU-related test we used in the lab
- `-c 10` sends 10 probes and then stops

Expected result:

- The ping should succeed without fragmentation errors
- This confirms the path supports the MTU-related test before iperf starts

## 5. Run the TCP iperf3 test with DF enabled

This is the main validation step. We ran TCP iperf3 with the DF bit enabled and a payload/MSS of `2000` to see whether the path handled larger packets without retransmission issues.

Command on the source VM:

```bash
iperf3 -c 10.235.1.4 --dont-fragment -M 2000 -l 2000 -t 30 -i 1 -J > tcp_df_2000.json
```

What this does:

- `-c 10.235.1.4` connects to the destination VM
- `--dont-fragment` sets the IPv4 DF flag
- `-M 2000` sets the TCP MSS
- `-l 2000` sets the TCP payload size
- `-J` writes the output in JSON so it is easier to review

Expected result:

- The output should show sender and receiver throughput, plus retransmits
- If retransmits are zero or very low, that is a good sign

## 6. Review retransmissions in the TCP results

TCP iperf does not show packet loss directly, but it does show retransmissions. We used that as the health signal for the TCP flow.

Command to review the result:

```bash
grep -E "retransmits|bits_per_second|sender|receiver" tcp_df_2000.json
```

What to look for:

- `retransmits = 0` or very low
- Sender and receiver throughput close to each other
- No sign of instability during the test

## 7. Capture traffic with tcpdump and confirm packet behavior

We also took a packet capture to verify the wire behavior. This helps confirm what was actually sent and whether the packets were above the standard `1500`-byte MTU.

Command on the source VM while iperf is running:

```bash
sudo tcpdump -i eth0 -nn -s0 -w tcpdump_mtu3872.pcap 'host 10.235.1.4 and tcp port 5201'
```

If you want a readable text version afterward:

```bash
sudo tcpdump -nn -r tcpdump_mtu3872.pcap -vvv > tcpdump_mtu3872.txt
```

Expected result:

- The capture should show the packet details and confirm the MTU-related behavior you are testing

## 8. Share back the results

Please share the following items back with us:

- `iperf3` version output
- `tcp_df_2000.json`
- `tcpdump_mtu3872.pcap` or `tcpdump_mtu3872.txt`
- Any retransmits or unexpected behavior observed during the test

Our East US 2 lab validation did not show retransmission issues under the tested conditions, and the packet capture confirmed the expected MTU behavior. If you run the same steps in your lab and see different results, that will help us compare the environments more precisely.

Best regards,

[Your Name]
