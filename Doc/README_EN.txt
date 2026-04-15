================================================================================
  YggFW — Lightweight Inbound Connection Filter for Yggdrasil Network on Windows
================================================================================

Version: 11  |  Language: C  |  Platform: Windows x64
Dependency: WinDivert (https://reqrypt.org/windivert.html)


  WHO NEEDS THIS — AND WHO DOESN'T
  ══════════════════════════════════

If you're running Linux — close this document with peace of mind. The problem
described below simply doesn't exist on Linux: the netfilter subsystem handles
tunnel interfaces correctly, and no additional protection is needed.

If you're on Windows and you use the Yggdrasil network — read on.


  WHAT THIS IS ABOUT
  ══════════════════

YggFW is a small filter program for inbound IPv6 connections on Windows.
It was created specifically for the Yggdrasil network, but works equally well
with any IPv6 interface without any modifications.

The program runs as a Windows service silently in the background, invisible to
the user, and intercepts inbound packets before they ever reach the built-in
Windows Firewall.


  THE PROBLEM: WHY STANDARD PROTECTION ISN'T ENOUGH
  ═══════════════════════════════════════════════════

The Yggdrasil network operates through a virtual network interface — a software
tunnel that Windows sees not as a regular network adapter, but as a special
software-defined adapter.

The built-in Windows Defender Firewall is quite good at blocking unwanted inbound
connections on standard interfaces — Ethernet, Wi-Fi, VPN. But with tunnel-type
interfaces like Yggdrasil, something unexpected happens: the firewall does not
automatically apply its "block all unknown" policy to them. Traffic arrives
through the tunnel driver directly, and Windows treats this as "local delivery"
that doesn't require default filtering.

The result.

A Yggdrasil node on Windows is essentially open to inbound connections from
the entire network — the default inbound block simply doesn't apply to it.
To fix this, you need to manually create a "block all" rule in Windows Defender
Firewall. However, once such a rule is in place, it becomes impossible to create
exceptions for trusted addresses.

It might seem the solution is straightforward: create a "block everything from
Yggdrasil" rule in the firewall, then add exceptions for the addresses you trust.
But here a second problem appears. In Windows Defender Firewall, blocking rules
take priority over allowing rules when both apply to the same traffic. In other
words, a broad "block" rule overrides a narrower "allow" rule, even if the allow
rule was created first.

The conclusion: using standard Windows tools alone, you cannot protect your
Yggdrasil node while simultaneously keeping access open for trusted addresses.


  HOW YggFW WORKS
  ════════════════

Think of your computer as a house. The network is the street where visitors
arrive. Windows Defender Firewall is the front door of your home. The problem
is that this door, in the case of Yggdrasil, is unlocked by default — and the
lock behaves unpredictably even when you try to fix it.

YggFW is the gate in the fence around your property. It stands between the
street and your front door. A visitor must pass through the gate first, and
only then can they approach the door. If the gate is closed — they never even
reach the door.

Technically: YggFW uses the WinDivert library, which intercepts packets at the
Windows network stack level before they reach Windows Defender Firewall at all.
This means a blocked packet is dropped at the earliest possible stage — the
firewall never even sees it.

The program supports:
  - blocking entire IPv6 subnets (e.g. the entire 200::/7 range)
  - allowing access for specific addresses or subnets
  - allowing access to specific ports (TCP and UDP)
  - stateful filtering (conntrack): reply traffic for your outbound requests
    is allowed automatically — as any normal connection should work
  - writing logs to files with time-based rotation
  - running as a Windows service without any user interaction


  INSTALLATION
  ════════════

1. Create the folder C:\Bin\YggFW\ and copy the following files into it:

     C:\Bin\YggFW\
     ├── yggfw.exe
     ├── WinDivert.dll
     ├── WinDivert64.sys
     ├── settings.txt      (created automatically on first run)
     └── rules.txt         (created automatically on first run)

2. Make sure you have administrator rights.

3. Open a command prompt as Administrator and run:

     sc create YggFW binPath= "C:\Bin\YggFW\yggfw.exe" start= auto
     sc description YggFW "Lite Yggdrasil (IPv6) Firewall"
     sc start YggFW

4. Verify the service is running:

     sc query YggFW

   You should see the line STATE : 4 RUNNING.

To stop and remove the service:

     sc stop YggFW
     sc delete YggFW

Note: on first run, the files settings.txt and rules.txt will be created
automatically in C:\Bin\YggFW\ with default settings, along with a Logs\
folder for log files.


  SETTINGS: the settings.txt file
  ═════════════════════════════════

This file is read every time the program starts. Lines beginning with # and
empty lines are ignored. Format: key=value.

────────────────────────────────────────────────────
  MAIN PARAMETERS
────────────────────────────────────────────────────

loglevel = 0
  Console output level (console mode only).
  0 — complete silence. Used when running as a service.
  1 — show only blocked connections.
  2 — show blocked and explicitly allowed connections (excluding default-allow).
  3 — show everything.
  4 — maximum verbosity for debugging.
  When running as a Windows service, loglevel is forced to 0 — a service has
  no screen to display messages on.

response = 0
  What to do with a blocked packet.
  0 — silently drop it. The sender gets no reply, as if the address doesn't exist.
  1 — send a rejection notification (TCP RST or ICMPv6 Unreachable).
  Value 0 is preferred: it reveals no information about your node.

conntrack = 1
  Stateful (intelligent) filtering.
  1 — enabled. The program tracks your outbound connections and automatically
      allows reply traffic. For example, if you query a DNS server, its reply
      is passed through automatically.
  0 — disabled. You would need to manually write allow rules for all reply
      traffic, which is extremely inconvenient.

ct_tcp_timeout = 120
  Lifetime of an automatic allow rule for a TCP connection (in seconds).
  After the connection closes or the timer expires, the rule is removed.

ct_udp_timeout = 30
  Lifetime of an automatic allow rule for UDP (in seconds).

ct_icmpv6_timeout = 10
  Lifetime of an automatic allow rule for ICMPv6 echo (ping) in seconds.
  Tied to the specific request identifier — someone else's ping won't sneak through.

────────────────────────────────────────────────────
  FILE LOGGING
────────────────────────────────────────────────────

DumpLevel = 1
  File logging level. Works independently of loglevel.
  0 — do not write to file.
  1 — log only blocked connections. Optimal for production.
  2 — blocked and explicitly allowed connections.
  3 — absolutely everything.

DumpFile = .\Logs\yggfw-%Y-%m-%d.log
  Path to the log file. Supports strftime-style date/time masks:
    %Y — year (2026), %m — month (04), %d — day (15), %H — hour (21).
  Folders are created automatically.
  Example for a different location: C:\Logs\yggfw\yggfw-%Y-%m-%d.log

DumpStart = D
  How often to create a new log file:
  H — every hour
  D — every day (default)
  W — every week
  M — every month
  Y — every year

Example log line:
  2026-04-04 21:04:15.602 -T [316:c51a::]:80 -> [227:3f13::]:5297 [FIN][ACK] {60/0} @ DENY 200::/7 any * -> *

  Key:
    -T  = blocked TCP packet
    +T  = allowed TCP packet
    >U  = allowed UDP packet via conntrack (reply traffic)
    .I  = ICMPv6 passed by default
    {60/0} = packet size 60 bytes, payload 0 bytes
    @ ...  = the rule that matched

────────────────────────────────────────────────────
  VERBOSITY FLAGS (loglevel=4 only)
────────────────────────────────────────────────────

LogPacketNumber = 1   Packet numbering in output
LogStats        = 1   Counters: total / allowed / blocked
LogMatches      = 1   Which rule matched
LogOutcoming    = 1   Outbound packets (used by conntrack)
LogConntrack    = 1   Conntrack events: added / renewed / removed


  FILTERING RULES: the rules.txt file
  ═════════════════════════════════════

This is the main configuration file. Here you describe who to let in and who to block.

Rules are checked from top to bottom. The first matching rule wins.
If no rule matches — the packet is allowed (default allow).

────────────────────────────────────────────────────
  RULE FORMAT
────────────────────────────────────────────────────

  <action> <source_address> <protocol> [<source_port> -> <destination_port>]

Action:
  ALLOW — let through
  DENY  — block

Source address (src_addr):
  *                          — any address
  200::1                     — a specific IPv6 address
  200::/7                    — an address range (subnet)
  325:62b8:f811:b821::/64    — a narrower subnet

Protocol (proto):
  tcp     — TCP only
  udp     — UDP only
  icmpv6  — ICMPv6 only (ping and others). No ports are specified.
  any     — TCP, UDP and ICMPv6 together

Ports:
  * -> *      any source port, any destination port
  * -> 443    any source port, destination port 443 (HTTPS)
  53 -> *     source port 53 (DNS server reply), any destination port

────────────────────────────────────────────────────
  EXAMPLE RULES
────────────────────────────────────────────────────

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

────────────────────────────────────────────────────
  HOW CONNTRACK WORKS IN PRACTICE
────────────────────────────────────────────────────

Suppose your rules.txt only has a block rule for the entire 200::/7 range.
You open a browser and visit a site on the Yggdrasil network. Your computer
sends a TCP request to the site's server. YggFW sees this outbound request and
automatically creates a temporary allow rule: "let through the TCP reply from
this server to this port for 120 seconds." When the server replies — the packet
passes through. After you close the tab, the connection closes, and the temporary
rule is removed.

Without conntrack, you would receive no reply at all, even for connections you
initiated yourself.

────────────────────────────────────────────────────
  MINIMAL CONFIGURATION
────────────────────────────────────────────────────

If you simply want to protect your computer from unwanted connections and don't
need to allow access from specific trusted addresses, just add two rules to
rules.txt — that's all you need:

  DENY  200::/7   any  * -> *
  DENY  300::/64  any  * -> *

Conntrack will ensure your outbound connections continue to work normally.


  TECHNICAL NOTES
  ════════════════

Language:    C (compiled with VS 2022/2026, x64)
Dependency:  WinDivert 2.x (https://reqrypt.org/windivert.html)
Platform:    Windows 10/11, Windows Server 2019/2022, x64
Rights:      administrator rights required (to install the WinDivert driver)
Ports:       opens no ports, creates no network connections

Compilation:
  cl main.c /W3 /O2 /I<path_to_windivert.h>
     /link /LIBPATH:<path_to_windivert.lib> WinDivert.lib Ws2_32.lib


================================================================================
  YggFW — lightweight, transparent, reliable.
================================================================================
