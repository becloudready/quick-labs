# Linux Storage Skills Challenge

Welcome to the Linux Storage Skills Challenge! This set of tasks is designed to test your ability to manage storage, work with LVM, format filesystems, and handle mounts in a Linux environment.

## Instructions for Candidates

*   You will be working on a pre-configured Linux virtual machine.
*   Perform all tasks as the `candidate` user. Use `sudo` for commands requiring root privileges.
*   Achieve the desired state as described in each task. Changes should be effective immediately and persist where typically expected (e.g., mount points in `/etc/fstab`).
*   You may use `man` pages or other on-system documentation.
*   The system is equipped with standard Linux storage utilities.
*   **Two unused block devices (e.g., `/dev/sdb`, `/dev/sdc` - verify exact names using `lsblk`) of approximately 10GB each are available for your use.**
*   **An additional unused block device (e.g., `/dev/sdd` - verify exact name) of approximately 5GB is available for Task 3.**

---

## Tasks

### Task 1: Basic Partitioning, Filesystem, and Mounting (15 points)

*   **Problem:** A new, dedicated storage area is required for application logs.
*   **Desired State (using `/dev/sdd` or your third available 5GB disk):**
    a.  Create a single primary partition that utilizes all available space on the disk.
    b.  Format this new partition with the `XFS` filesystem.
    c.  Create a directory `/var/log/applogs`.
    d.  Mount the XFS formatted partition persistently (i.e., it should mount automatically on boot) at `/var/log/applogs`.
    e.  Ensure the mount point `/var/log/applogs` is owned by the user `syslog` and group `adm`, with permissions `rwxrwxr-x` (0775).

### Task 2: LVM Setup and Initial Use (25 points)

*   **Problem:** A flexible and expandable storage solution is needed for critical application data.
*   **Desired State (using your two 10GB disks, e.g., `/dev/sdb`, `/dev/sdc`):**
    a.  Initialize both provided 10GB block devices as LVM Physical Volumes (PVs).
    b.  Create an LVM Volume Group (VG) named `appvg` utilizing both of these PVs.
    c.  Within `appvg`, create an LVM Logical Volume (LV) named `data01` with a size of `8G`.
    d.  Format `data01` with the `ext4` filesystem.
    e.  Create a directory `/srv/appdata`.
    f.  Mount `data01` persistently at `/srv/appdata`.

### Task 3: LVM Expansion (15 points)

*   **Problem:** The existing `data01` Logical Volume in `appvg` is running out of space and needs to be expanded.
*   **Desired State:**
    a.  Extend the `data01` Logical Volume to a new total size of `12G`.
    b.  After extending the LV, ensure the `ext4` filesystem on `data01` is resized to utilize all the newly available space.
    c.  Verify that data can still be written to `/srv/appdata` after the expansion (e.g., by creating a small test file).

### Task 4: Filesystem Check and Repair (Conceptual - 5 points)

*   **Problem:** You suspect potential filesystem corruption on a non-critical, unmounted `ext4` filesystem located at `/dev/externals/reports_fs` (assume this device and filesystem exist and are currently unmounted).
*   **Desired Output:**
    a.  Create a file named `~/fs_check_plan.txt`.
    b.  In this file, describe the command(s) you would use to safely check this `ext4` filesystem for errors and attempt to repair them non-interactively if possible.
    c.  Briefly explain any important options you would use with the command(s) and why.
    *(You do not need to actually create or corrupt a filesystem for this task; describe your approach).*

### Task 5: Inode Usage Monitoring (Conceptual - 5 points)

*   **Problem:** A filesystem mounted at `/opt/project_files` is reported to be "full", but `df -h` shows there is still some disk space available. You suspect an inode exhaustion issue.
*   **Desired Output:**
    a.  Create a file named `~/inode_check_plan.txt`.
    b.  In this file, list the command(s) you would use to check inode usage on the `/opt/project_files` filesystem.
    c.  If inode exhaustion is confirmed, briefly describe one common cause and one potential way to mitigate it in the future for that directory structure (assuming many small files are legitimate).




