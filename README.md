# YggFW — Lightweight Inbound Connection Filter for Yggdrasil Network on Windows

**Version:** 11 &nbsp;|&nbsp; **Language:** C &nbsp;|&nbsp; **Platform:** Windows x64  
**Dependency:** [WinDivert](https://reqrypt.org/windivert.html)

---

## Who Needs This — And Who Doesn't

If you're running **Linux** — close this document with peace of mind. The problem described below simply doesn't exist on Linux: the netfilter subsystem handles tunnel interfaces correctly, and no additional protection is needed.

If you're on **Windows** and you use the Yggdrasil network — read on.

---

## What This Is About

YggFW is a small filter program for inbound IPv6 connections on Windows. It was created specifically for the Yggdrasil network, but works equally well with any IPv6 interface without any modifications.

The program runs as a Windows service silently in the background, invisible to the user, and intercepts inbound packets before they ever reach the built-in Windows Firewall.

---

## The Problem: Why Standard Protection Isn't Enough

The Yggdrasil network operates through a virtual network interface — a software tunnel that Windows sees not as a regular network adapter, but as a special software-defined adapter.

The built-in Windows Defender Firewall is quite good at blocking unwanted inbound connections on standard interfaces — Ethernet, Wi-Fi, VPN. But with tunnel-type interfaces like Yggdrasil, something unexpected happens: the firewall does not automatically apply its "block all unknown" policy to them. Traffic arrives through the tunnel driver directly, and Windows treats this as "local delivery" that doesn't require default filtering.

**The result.**

A Yggdrasil node on Windows is essentially open to inbound connections from the entire network — the default inbound block simply doesn't apply to it. To fix this, you need to manually create a "block all" rule in Windows Defender Firewall. However, once such a rule is in place, it becomes impossible to create exceptions for trusted addresses.

It might seem the solution is straightforward: create a "block everything from Yggdrasil" rule in the firewall, then add exceptions for the addresses you trust. But here a second problem appears. In Windows Defender Firewall, blocking rules take **priority** over allowing rules when both apply to the same traffic. In other words, a broad "block" rule overrides a narrower "allow" rule, even if the allow rule was created first.

The conclusion: using standard Windows tools alone, you cannot protect your Yggdrasil node while simultaneously keeping access open for trusted addresses.

---

## How YggFW Works

Think of your computer as a house. The network is the street where visitors arrive. Windows Defender Firewall is the front door of your home. The problem is that this door, in the case of Yggdrasil, is unlocked by default — and the lock behaves unpredictably even when you try to fix it.

**YggFW is the gate in the fence around your property.** It stands between the street and your front door. A visitor must pass through the gate first, and only then can they approach the door. If the gate is closed — they never even reach the door.

Technically: YggFW uses the WinDivert library, which intercepts packets at the Windows network stack level before they reach Windows Defender Firewall at all. This means a blocked packet is dropped at the earliest possible stage — the firewall never even sees it.

The program supports:
- blocking entire IPv6 subnets (e.g. the entire `200::/7` range)
- allowing access for specific addresses or subnets
- allowing access to specific ports (TCP and UDP)
- stateful filtering (conntrack): reply traffic for your outbound requests is allowed automatically
- writing logs to files with time-based rotation
- running as a Windows service without any user interaction

---

## Installation

**1.** Create the folder `C:\Bin\YggFW\` and copy the following files into it:

```
C:\Bin\YggFW\
├── yggfw.exe
├── WinDivert.dll
├── WinDivert64.sys
├── settings.txt      (created automatically on first run)
└── rules.txt         (created automatically on first run)
```

**2.** Make sure you have administrator rights.

**3.** Open a command prompt as Administrator and run:

```
sc create YggFW binPath= "C:\Bin\YggFW\yggfw.exe" start= auto
sc description YggFW "Lite Yggdrasil (IPv6) Firewall"
sc start YggFW
```

**4.** Verify the service is running:

```
sc query YggFW
```

You should see the line `STATE : 4  RUNNING`.

To stop and remove the service:

```
sc stop YggFW
sc delete YggFW
```

> On first run, the files `settings.txt` and `rules.txt` will be created automatically in `C:\Bin\YggFW\` with default settings, along with a `Logs\` folder for log files.

---

## Settings: the settings.txt file

This file is read every time the program starts. Lines beginning with `#` and empty lines are ignored. Format: `key=value`.

### Main Parameters

| Parameter | Default | Description |
|---|---|---|
| `loglevel` | `0` | Console output level: `0`=silence, `1`=blocked only, `2`=blocked+allowed, `3`=everything, `4`=debug. Forced to `0` when running as a service. |
| `response` | `0` | `0`=silently drop the packet, `1`=send a rejection notice (TCP RST / ICMPv6 Unreachable). Value `0` is preferred. |
| `conntrack` | `1` | `1`=stateful filtering enabled (reply traffic passes automatically), `0`=disabled. |
| `ct_tcp_timeout` | `120` | Lifetime of an automatic allow rule for TCP connections (seconds). |
| `ct_udp_timeout` | `30` | Lifetime for UDP (seconds). |
| `ct_icmpv6_timeout` | `10` | Lifetime for ICMPv6 echo/ping (seconds). |

### File Logging

| Parameter | Default | Description |
|---|---|---|
| `DumpLevel` | `1` | `0`=off, `1`=blocked only, `2`=blocked+allowed, `3`=everything. |
| `DumpFile` | `.\Logs\yggfw-%Y-%m-%d.log` | Log file path. Supports strftime masks `%Y %m %d %H`. Folders are created automatically. |
| `DumpStart` | `D` | Rotation period: `H`=hour, `D`=day, `W`=week, `M`=month, `Y`=year. |

Example log line:

```
2026-04-04 21:04:15.602 -T [316:c51a::]:80 -> [227:3f13::]:5297 [FIN][ACK] {60/0} @ DENY 200::/7 any * -> *
```

First two characters: `-T`=blocked TCP, `+T`=allowed TCP, `>U`=allowed UDP via conntrack, `.I`=ICMPv6 default allow.

### Verbosity Flags (loglevel=4 only)

| Parameter | Default | Description |
|---|---|---|
| `LogPacketNumber` | `1` | Packet numbering |
| `LogStats` | `1` | Counters: total / allowed / blocked |
| `LogMatches` | `1` | Which rule matched |
| `LogOutcoming` | `1` | Outbound packets |
| `LogConntrack` | `1` | Conntrack events |

---

## Filtering Rules: the rules.txt file

This is the main configuration file. Here you describe who to let in and who to block.

Rules are checked **top to bottom**. The **first matching rule** wins. If no rule matches — the packet is allowed (default allow).

### Rule Format

```
<action> <source_address> <protocol> [<source_port> -> <destination_port>]
```

**Action:**
- `ALLOW` — let through
- `DENY` — block

**Source address (src_addr):**
- `*` — any address
- `200::1` — a specific IPv6 address
- `200::/7` — an address range (subnet)
- `325:62b8:f811:b821::/64` — a narrower subnet

**Protocol (proto):**
- `tcp` — TCP only
- `udp` — UDP only
- `icmpv6` — ICMPv6 only (ping and others). No ports specified.
- `any` — TCP, UDP and ICMPv6 together

**Ports:**
- `* -> *` — any source, any destination
- `* -> 443` — any source, destination port 443
- `53 -> *` — source port 53 (DNS server reply), any destination

### Example Rules

```
# Trusted host — allow everything without restrictions
ALLOW 225:62b8:f811:b821:6c6b:8fcc:c01b:425c  any  * -> *

# Trusted subnet — for example, your own devices
ALLOW 325:62b8:f811:b821::/64  any  * -> *

# DNS servers — allow only their replies (they respond from port 53)
ALLOW 308:84:68:55::   udp  53 -> *
ALLOW 308:25:40:bd::   udp  53 -> *

# Allow inbound connections to a web server
ALLOW *  tcp  * -> 80
ALLOW *  tcp  * -> 443

# Allow ping (otherwise you can't be pinged)
ALLOW *  icmpv6

# Block all remaining traffic from Yggdrasil
DENY  200::/7   any  * -> *
DENY  300::/64  any  * -> *
```

### How Conntrack Works in Practice

Suppose your `rules.txt` only has a block rule for the entire `200::/7` range. You open a browser and visit a site on the Yggdrasil network. Your computer sends a TCP request to the site's server. YggFW sees this outbound request and automatically creates a temporary allow rule: "let through the TCP reply from this server to this port for 120 seconds." When the server replies — the packet passes through. After you close the tab, the connection closes, and the temporary rule is removed.

Without conntrack, you would receive no reply at all, even for connections you initiated yourself.

### Minimal Configuration

If you simply want to protect your computer from unwanted connections and don't need to allow access from specific trusted addresses, just add two rules to `rules.txt` — that's all you need:

```
DENY  200::/7   any  * -> *
DENY  300::/64  any  * -> *
```

Conntrack will ensure your outbound connections continue to work normally.

---

## Technical Notes

| | |
|---|---|
| Language | C (VS 2022/2026, x64) |
| Dependency | WinDivert 2.x |
| Platform | Windows 10/11, Server 2019/2022, x64 |
| Rights | Administrator (to install the WinDivert driver) |
| Ports | Opens no ports whatsoever |

---

*YggFW — lightweight, transparent, reliable.*
