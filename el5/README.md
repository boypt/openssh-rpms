# OpenSSH RPM Build for EL5

This project provides an RPM Spec file designed to build a modern version of OpenSSH on legacy Enterprise Linux 5 (EL5) systems.

## Key Features

### 1. Legacy Environment Support (EL5)
Building modern software on EL5 is challenging due to outdated system libraries and build tools. This spec file contains specific logic to overcome these limitations without replacing core system packages.

### 2. Perl Bootstrap
Modern versions of OpenSSL (which are required for modern OpenSSH) depend on Perl version 5.10.0 or higher for their build system. EL5 repositories typically provide Perl 5.8, which is insufficient.

To address this, the spec file implements a **Perl bootstrap process**:
*   It checks the version of the system's Perl.
*   If the system Perl is too old, it compiles a modern version of Perl (default: 5.38.2) from source inside the build directory.
*   This custom Perl is used exclusively during the build process to compile OpenSSL and is not installed into the final RPM or the system.

### 3. Static OpenSSL Compilation
Using the bootstrapped Perl, the spec file compiles a modern version of OpenSSL (default: 3.0.8).
*   OpenSSL is built statically within the build tree.
*   It is linked directly into the OpenSSH binaries.
*   This ensures the new OpenSSH has access to modern cryptography (like TLS 1.3 support) while leaving the system's original OpenSSL libraries untouched to prevent dependency conflicts.

### 4. Final OpenSSH Build
The process culminates in building OpenSSH (default: 9.6p1), linked against the custom-built static OpenSSL library.

## Build Flow Summary

1.  **Detect Perl Version**: If system Perl < 5.10, build custom Perl.
2.  **Build OpenSSL**: Use the custom Perl to configure and build OpenSSL.
3.  **Build OpenSSH**: Configure OpenSSH to use the custom OpenSSL headers and libraries.

## Default Versions
*   **OpenSSH**: 9.6p1
*   **OpenSSL**: 3.0.8
*   **Perl**: 5.38.2
