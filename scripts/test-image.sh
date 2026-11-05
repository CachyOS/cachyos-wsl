#!/bin/bash

set -euo pipefail

# Fixed TZ to ensure consistency
export TZ=UTC

declare -r WORKDIR="$1"
declare -r BUILDDIR="$WORKDIR/build"
declare -r OUTPUTDIR="$WORKDIR/output"
declare -r CLONEDIR="$WORKDIR/clone"
declare -r VENVDIR="$WORKDIR/venv"
declare -r IMAGE_VERSION="$2"

# Run some tests / commands from the built rootfs
fakechroot -- fakeroot -- chroot "$BUILDDIR" test "$(wc -l /etc/group | awk '{print $1}')" -gt 10
fakechroot -- fakeroot -- chroot "$BUILDDIR" test "$(wc -l /etc/passwd | awk '{print $1}')" -gt 10
fakechroot -- fakeroot -- chroot "$BUILDDIR" pacman-key --init
fakechroot -- fakeroot -- chroot "$BUILDDIR" pacman-key --populate archlinux cachyos
fakechroot -- fakeroot -- chroot "$BUILDDIR" pacman -Sy --disable-sandbox-filesystem
fakechroot -- fakeroot -- chroot "$BUILDDIR" pacman -Qqk
fakechroot -- fakeroot -- chroot "$BUILDDIR" pacman -Syyu --disable-sandbox-filesystem --noconfirm podman grep
fakechroot -- fakeroot -- chroot "$BUILDDIR" podman -v
fakechroot -- fakeroot -- chroot "$BUILDDIR" id -u http
fakechroot -- fakeroot -- chroot "$BUILDDIR" locale | grep -q UTF-8
fakechroot -- fakeroot -- chroot "$BUILDDIR" grep -q "^ID=cachyos$" /etc/os-release
fakechroot -- fakeroot -- chroot "$BUILDDIR" grep -qx /usr/bin/fish /etc/shells
fakechroot -- fakeroot -- chroot "$BUILDDIR" sh -c '! grep -Eq "^\[cachyos-(v3|v4|znver4)\]$" /etc/pacman.conf'
fakechroot -- fakeroot -- chroot "$BUILDDIR" pacman -Qq cachyos-settings cachyos-fish-config cachyos-rate-mirrors
# fakechroot doesn't wrap statx(), so check from outside the chroot
test "$(stat -c %a "$BUILDDIR/etc/sudoers.d/10-wheel")" = 440

# Run Microsoft's WSL image validation script: https://github.com/microsoft/WSL/blob/master/distributions/validate-modern.py
if [ -d "$CLONEDIR" ]; then
	git -C "$CLONEDIR" pull https://github.com/microsoft/WSL.git 
else
	git clone https://github.com/microsoft/WSL.git "$CLONEDIR"
fi
python -m venv "$VENVDIR"
export PATH="$VENVDIR/bin:$PATH"
pip install -r "$CLONEDIR/distributions/requirements.txt"
python "$CLONEDIR/distributions/validate-modern.py" --tar "$OUTPUTDIR/cachyos-$IMAGE_VERSION.wsl"
