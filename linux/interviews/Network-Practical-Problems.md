# Linux Networking Troubleshooting Challenge

Welcome! This challenge is designed to assess your practical Linux networking troubleshooting and configuration skills. You will be presented with several scenarios on a Linux virtual machine where networking is not functioning as expected. Your task is to diagnose the problem and implement the necessary corrections.

## General Instructions for Candidates

*   You will be working on a pre-configured Linux virtual machine.
*   Perform all tasks as the `candidate` user. Use `sudo` for commands requiring root privileges.
*   For each task, your goal is to restore correct functionality or achieve the described desired state.
*   Unless specified otherwise, changes should be made to be **persistent** across reboots where applicable (e.g., IP configurations, routes, firewall rules). If a task implies a temporary change for testing, make that clear if you would normally make it persistent.
*   You are encouraged to use standard Linux command-line utilities and `man` pages for assistance.
*   After resolving each issue, be prepared to explain your diagnostic process, the commands you used, why you chose them, and how you verified your solution.

---

## Scenario-Based Tasks

### Task 1: DNS Resolution Failure

*   **Problem:** Users report that this server cannot resolve external hostnames (e.g., `www.example.com`), and package manager updates are failing with "Could not resolve host" errors. However, direct IP pings to known internet hosts (like `8.8.8.8`) are successful.
*   **Your Goal:** Diagnose and fix the DNS resolution issue. The server must be able to resolve public internet hostnames correctly after your fix.

### Task 2: No Internet Connectivity (Gateway Issue)

*   **Problem:** This server can successfully communicate with other machines on its immediate local network segment. However, it cannot reach any IP addresses outside of this local network (e.g., public internet IPs).
*   **Your Goal:** Identify the cause of the external connectivity failure and restore full internet access.

### Task 3: Firewall Blocking Service

*   **Problem:** A web application has been deployed on this server and is confirmed by local checks (`curl http://127.0.0.1:8080`) to be running and listening on TCP port `8080`. However, clients from other machines on the network cannot connect to this application.
*   **Your Goal:** Diagnose why external clients cannot connect and modify the system's firewall configuration to allow legitimate incoming connections to the web application on TCP port `8080`.

### Task 4: Specific Route Missing

*   **Problem:** This server needs to communicate with systems on a private internal network `10.50.0.0/16`. The designated gateway for reaching this specific network is `192.168.1.254` (assume this gateway is reachable on the server's local network). Currently, attempts to connect to any host within `10.50.0.0/16` are failing.
*   **Your Goal:** Configure the necessary network routing on this server to enable communication with the `10.50.0.0/16` network via the specified gateway.

### Task 5: Service Binding Issue ("Address already in use")

*   **Problem:** An administrator is trying to start a critical custom application that needs to listen on TCP port `9000` on all network interfaces (`0.0.0.0`). Each time they attempt to start it, the application fails immediately, reporting an "Address already in use" error.
*   **Your Goal:** Identify which process is currently using TCP port `9000`. Take appropriate action to stop or remove the conflicting process so that port `9000` becomes available for the critical application. (You do not need to start the custom application itself).

### Task 6: SSH Connectivity Problem

*   **Problem:** Attempts to connect to this server via SSH from other machines are failing with "Connection refused" errors. Assume client-side SSH configuration and network paths from clients are correct.
*   **Your Goal:** Diagnose the reason(s) SSH connections are being refused and restore SSH accessibility to the server.

### Task 7: Incorrect Network Interface IP Address

*   **Problem:** The primary network interface of this server (e.g., `eth0` or `ens33`) is intended to be configured with the static IP address `192.168.1.100`, a netmask of `255.255.255.0` (or `/24`), and a default gateway of `192.168.1.1`. Currently, it has an incorrect IP configuration or no IP address assigned.
*   **Your Goal:** Correctly configure the primary network interface with the specified static IP address, netmask, and default gateway. This configuration must be persistent.

### Task 8: Network Interface Down

*   **Problem:** The primary network interface on this server (e.g., `eth0` or `ens33`) is currently in a "DOWN" state and is not processing network traffic.
*   **Your Goal:** Bring the primary network interface up, ensure it can obtain an IP address (assume DHCP is available and should be used if no static IP is specified by other tasks), and verify it is operational.

### Task 9: Diagnosing Network Degradation (Conceptual Plan)

*   **Problem:** Users are reporting that connections to a specific application running on this server (listening on `10.1.1.5:8000` - assume this IP is configured on a secondary interface or is a virtual IP on this server) are extremely slow and occasionally drop. Pinging the server's primary IP address also shows intermittent packet loss and high latency.
*   **Your Task:** You are **not** required to fix this issue. Instead, create a text file named `~/network_degradation_plan.txt`. In this file, outline in detail:
    1.  The systematic steps you would take **on this server** to investigate the cause of this network degradation.
    2.  The specific Linux commands and tools you would use at each step.
    3.  What kind of information or output you would be looking for from each command/tool.

### Task 10: Investigating MTU Issues (Conceptual Plan / Simplified Practical)

*   **Problem (Part A - Conceptual):** Users report that while most internet browsing from this server works, connections to a specific external partner site (`partner.example.com`) seem to establish but then hang or time out when large amounts of data are expected (e.g., loading a large webpage or downloading a file). Small pings to `partner.example.com` are successful.
*   **Problem (Part B - Simplified Practical):** On this server, `ping google.com -s 1472` (or a similar command to send a 1500-byte packet) is successful. However, sending a slightly larger packet, like `ping google.com -s 1473`, fails with a message like "Packet needs to be fragmented but DF set" or similar.
*   **Your Task:**
    1.  For Part A (Conceptual): In a text file named `~/mtu_analysis_plan.txt`, explain what common network issue could cause this behavior and describe how you would test for it from this server.
    2.  For Part B (Practical): Based on the ping behavior described, what does this indicate? What is the likely maximum effective MTU for reaching `google.com` from this server (excluding IP/ICMP headers)? Then, temporarily change the MTU of your server's primary network interface to `1400`. Verify the change. (This temporary change does not need to be persistent).

