![AWS Jumpbox](https://github.com/user-attachments/assets/5bf904e4-911b-4536-9f15-746cf9d47f8f)

```
+----------------+       +----------------+       +----------------+
| Local Machine  |       |  Jump Server   |       | Internal Machine |
|                |       | (Bastion Host) |       |                |
|  +----------+  |       |  +----------+  |       |  +----------+  |
|  | Terminal |  |  SSH  |  | SSH      |  |  SSH  |  | Service  |  |
|  |          |--------->|  | Server   |--------->|  |          |  |
|  +----------+  |       |  +----------+  |       |  +----------+  |
|                |       |                |       |                |
+----------------+       +----------------+       +----------------+
```

Connection Flow:
1. Local Machine: ssh -J user@jumpserver user@internalmachine
   OR
2. Local Machine: ssh user@jumpserver
   Jump Server: ssh user@internalmachine

