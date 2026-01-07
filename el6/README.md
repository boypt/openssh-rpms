# OpenSSH RPM Build for EL6

This project provides an RPM Spec file designed to build a modern version of OpenSSH on Enterprise Linux 6 (EL6) systems.

## Key Features

### 1. Legacy Environment Support (EL6)
Building modern software on EL6 requires handling outdated system libraries. This spec file addresses these limitations to provide a secure, modern SSH server.

### 2. Static OpenSSL Compilation
Modern versions of OpenSSH require newer OpenSSL libraries than those provided by EL6.
*   The spec file compiles a modern version of OpenSSL from source within the build environment.
*   **Static Linking**: OpenSSL is built statically and linked directly into the OpenSSH binaries.
*   **System Integrity**: This ensures the new OpenSSH has access to modern cryptography while leaving the system's original OpenSSL libraries untouched to prevent dependency conflicts.

### 3. System Perl
Unlike the EL5 build process, EL6 provides a version of Perl (5.10+) that is sufficient for building modern OpenSSL. Therefore, the **Perl bootstrap process is not required**, and the system Perl is used directly.

## Build Flow Summary

1.  **Build OpenSSL**: Use system Perl to configure and build OpenSSL statically.
2.  **Build OpenSSH**: Configure OpenSSH to use the custom OpenSSL headers and libraries.

## Default Versions

Versions are typically defined in the `version.env` file in the project root.

*   **OpenSSH**: (e.g., 10.2p1)
*   **OpenSSL**: (e.g., 3.0.18)
