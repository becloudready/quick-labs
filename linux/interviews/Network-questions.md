# Linux Networking Challenge - Intermediate Level

Welcome to the Linux Networking Challenge! This set of tasks is designed to test your ability to solve common intermediate-level Linux networking problems.

## Instructions for Candidates

*   You will be working on a pre-configured Linux virtual machine.
*   Perform all tasks as the `candidate` user. Use `sudo` for commands requiring root privileges.
*   Achieve the desired state as described in each task. Changes should be effective immediately and persist where typically expected (e.g., firewall rules, host entries).
*   You may use `man` pages or other on-system documentation.
*   The system is equipped with standard Linux networking utilities.

---

## Tasks

### Task 1: DNS Resolution Configuration (5 points)

*   **Problem:** The system needs to use specific external DNS servers for name resolution.
*   **Desired State:**
    *   Primary DNS server: `1.1.1.1`
    *   Secondary DNS server: `9.9.9.9`

### Task 2: Local Hostname Mapping (5 points)

*   **Problem:** Internal services need to be accessible via specific hostnames without relying on external DNS.
*   **Desired State:**
    *   The hostname `web.example.local` must resolve to the IP address `192.168.100.10`.
    *   The hostname `api.example.local` must resolve to the IP address `192.168.100.20`.
    *   These resolutions must be effective on the local machine only.

### Task 3: Network Service Availability (10 points)

*   **Problem:** Two new services need to be made available on the network from this machine.
*   **Desired State:**
    *   A TCP service must be listening on port `6001` on all available IPv4 interfaces.
    *   A UDP service must be listening on port `6002` on all available IPv4 interfaces.
    *   These services should remain running in the background. (Simple listeners are sufficient; no complex application logic is required).

### Task 4: Firewall Configuration (10 points)

*   **Problem:** A new web application development server needs to be accessible from the network.
*   **Desired State:**
    *   Incoming TCP traffic to port `7070` must be permitted through the system's firewall.
    *   Assume the system firewall (e.g., UFW or firewalld) is active or can be made active. The rule should be persistent.

### Task 5: Primary Network Interface Reporting (5 points)

*   **Problem:** For inventory and documentation purposes, key details of the primary network interface are required.
*   **Desired State:**
    *   A file named `~/primary_iface_details.txt` must exist.
    *   The first line of this file must contain only the IPv4 address of the system's primary network interface.
    *   The second line of this file must contain only the MAC address of the system's primary network interface.

### Task 6: Outbound Connectivity Verification (5 points)

*   **Problem:** Ensure basic outbound internet connectivity and DNS lookup capabilities are functional and documented.
*   **Desired State:**
    *   A file named `~/connectivity_tests.txt` must exist.
    *   This file must contain:
        1.  The complete output of a `ping` command testing connectivity to `google.com` (3 packets only).
        2.  The complete output of a command that resolves `wikipedia.org` to its IP address(es).
