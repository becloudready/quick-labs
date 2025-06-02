*   **Target Devices:** Use the two provided unused block devices (verify their names, e.g., `/dev/sdb` and `/dev/sdc`).
a.  **Physical Volumes & Volume Group:** Initialize both provided block devices as LVM Physical Volumes. Then, create a new Volume Group named `datavg` using these two Physical Volumes.
b.  **Logical Volume Creation:** Within the `datavg` Volume Group, create a Logical Volume named `applv` with an initial size of `512M`.
c.  **Filesystem & Mount:** Format the `applv` Logical Volume with the `ext4` filesystem. Create a directory `/mnt/appdata` and permanently mount `applv` onto this directory.
d.  **LV Extension & Filesystem Resize:** Extend the size of the `applv` Logical Volume to an absolute size of `768M`. After extending the LV, ensure the `ext4` filesystem on it is also resized to utilize the new space.

```
export ANSIBLE_PRIVATE_KEY_FILE="/path/to/your/private_key"
export ANSIBLE_HOST_KEY_CHECKING=False
```
