# CachyOS WSL Image

[![Build](https://github.com/CachyOS/cachyos-wsl/actions/workflows/build.yml/badge.svg?branch=cachyos)](https://github.com/CachyOS/cachyos-wsl/actions/workflows/build.yml)

CachyOS provides a WSL image, based on the [Arch Linux WSL image](https://gitlab.archlinux.org/archlinux/archlinux-wsl).

The image itself is generic, so it runs on any x86-64 CPU. Like the CachyOS installer, its first setup then detects the CPU and switches to the best matching CachyOS repositories (`znver4`, `x86-64-v4` or `x86-64-v3`), which downloads the optimized packages.  
It ships the `cachyos-settings`, `cachyos-rate-mirrors` and `cachyos-fish-config` packages, and its first setup creates a default user (with `fish` as its shell and `sudo` access via the `wheel` group).

Images are built & released monthly (via a [GitHub Actions schedule](https://github.com/CachyOS/cachyos-wsl/actions/workflows/build.yml)).

While images are built regularly, it is strongly recommended running `sudo pacman -Syu` right after the first setup due to the rolling release nature of CachyOS.

Images are signed using [Sigstore Cosign keyless signing](https://docs.sigstore.dev/cosign/signing/overview/).  
An image can be verified with the following command:

```bash
cosign verify-blob cachyos-2026.11.01.1.wsl --bundle cachyos-2026.11.01.1.wsl.bundle --certificate-identity "https://github.com/CachyOS/cachyos-wsl/.github/workflows/build.yml@refs/heads/cachyos" --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

## Installation

From a Windows system with [WSL 2 installed](https://learn.microsoft.com/en-us/windows/wsl/install), use one of the following installation methods.  
Note that WSL 1 is **not** supported.

### WSL 2.4.4 or greater

Download the [latest CachyOS ".wsl" image](https://github.com/CachyOS/cachyos-wsl/releases/latest) and double-click on it to start the installation.

You can then run CachyOS in WSL via the `cachyos` application from the Start menu, or by running `wsl -d cachyos` in a PowerShell prompt.

### WSL prior to 2.4.4

Download the [latest CachyOS ".wsl" image](https://github.com/CachyOS/cachyos-wsl/releases/latest) and run the following command in a PowerShell prompt:

```powershell
wsl --import <Distro name> <Install location> <WSL image>
```

For instance:

```powershell
wsl --import cachyos C:\Users\<Username>\Documents\WSL\cachyos C:\Users\<Username>\Downloads\cachyos-2026.11.01.1.wsl
```

You can then run CachyOS in WSL by running `wsl -d cachyos` in a PowerShell prompt.  
Make sure to execute the first setup script by running `/usr/lib/wsl/first-setup.sh` right after the first launch.  
Then set the created user as the default one by adding the following to `/etc/wsl.conf` (keeping the existing `[boot]` section), and restart the distribution by running `wsl --terminate cachyos` in a PowerShell prompt:

```ini
[user]
default=<Username>
```

## Building your own image

This repository contains all scripts and files needed to create a WSL image for CachyOS.

### Dependencies

Install the following Arch Linux packages:

- make
- fakechroot
- fakeroot

The build host pacman keyring must trust the CachyOS signing key (already the case on CachyOS):

```bash
pacman-key --recv-keys F3B607488DB35A47 --keyserver hkps://keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47
```

The following additional packages are required to run tests (see the "Usage" chapter below for details):

- git (for `make test`)
- python (for `make test`)

### Usage

Run `make` to build a new image (which can be then found in the `workdir/output` directory).  
The version ID of the built image is equal to the current date (in the format "YEAR.MONTH.DAY"), it can be set via the `IMAGE_VERSION` variable: `make IMAGE_VERSION="YEAR.MONTH.DAY"`.

You can also run `make test` to execute a series of tests against the built image, as well as `make clean` to delete every directories & files generated during build and tests (including the built image itself).

## Syncing with upstream

The `main` branch mirrors the [Arch Linux WSL image](https://gitlab.archlinux.org/archlinux/archlinux-wsl) repository, while the CachyOS changes live in the `cachyos` branch.  
To pull in upstream changes, fast-forward `main` to the upstream `main` branch and merge it into `cachyos`.
