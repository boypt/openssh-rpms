# OpenSSH RPM Build for EL7+ (EL8/EL9)

This project provides an RPM Spec file designed to build a modern version of OpenSSH on Enterprise Linux 7 (EL7). Thanks to the implementation of **systemd**, this configuration is also compatible with newer distributions like EL8 and EL9 (including RHEL, CentOS, Rocky Linux, and AlmaLinux).

## Key Features

### 1. Systemd Native Support
Unlike the EL5 and EL6 builds which rely on SysVinit scripts (`/etc/init.d/sshd`), this spec file configures OpenSSH to run as a native systemd service.
*   **Unit File**: Installs a standard `sshd.service` unit file.
*   **Management**: Fully integrated with `systemctl` for service management.

### 2. Forward Compatibility (EL8/EL9)
Because EL7, EL8, and EL9 all share the systemd architecture, this spec file allows the same source configuration to be built and deployed across these major versions with minimal or no changes.

### 3. Static OpenSSL Compilation
To support the latest OpenSSH features (which require newer cryptography than what EL7 provides by default), this build process:
*   Compiles a modern version of OpenSSL (e.g., 3.0.x) from source.
*   Links it **statically** into the OpenSSH binaries.
*   Ensures no conflict with the system's default OpenSSL libraries.

## Systemd Integration Details

The spec file utilizes specific RPM macros and configurations to handle the systemd lifecycle:

*   **Unit Installation**: The `sshd.service` file is installed into `%{_unitdir}` (typically `/usr/lib/systemd/system/`).
*   **Socket Activation**: (If configured) The spec may also include support for `sshd.socket` for on-demand activation, though the standard service is the default.

## Usage

After installing the generated RPM, manage the service using standard systemd commands:

```bash
# Enable the service to start at boot
systemctl enable sshd

# Start the service immediately
systemctl start sshd

# Check status
systemctl status sshd
```

## Default Versions

*   **OpenSSH**: (Defined in `version.env`, e.g., 10.2p1)
*   **OpenSSL**: (Defined in `version.env`, e.g., 3.0.18)
