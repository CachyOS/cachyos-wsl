#!/bin/bash

set -euo pipefail

# Fixed TZ to ensure consistency
export TZ=UTC

declare -r WORKDIR="$1"
declare -r BUILDDIR="$WORKDIR/build"
declare -r OUTPUTDIR="$WORKDIR/output"
declare -r IMAGE_VERSION="$2"
SOURCE_DATE_EPOCH=$(date -u -d "$(awk -F. '{print $1"-"$2"-"$3}' <<< "$IMAGE_VERSION")" +"%s")
readonly SOURCE_DATE_EPOCH
export SOURCE_DATE_EPOCH

# Packages installed on top of base
declare -ra PACKAGES=(
	base
	sudo
	cachyos-keyring
	cachyos-mirrorlist
	cachyos-v3-mirrorlist
	cachyos-v4-mirrorlist
	cachyos-hooks
	cachyos-settings
	cachyos-rate-mirrors
	fish
	cachyos-fish-config
)

# For eventual debugging purposes
echo -e "SOURCE_DATE_EPOCH: ${SOURCE_DATE_EPOCH}"

mkdir -vp "$BUILDDIR/alpm-hooks/usr/share/libalpm/hooks"
find /usr/share/libalpm/hooks -exec ln -sf /dev/null "$BUILDDIR/alpm-hooks"{} \;

mkdir -vp "$BUILDDIR/var/lib/pacman/" "$OUTPUTDIR"

# Use the build-time mirrorlists, the ones from the packages aren't installed yet
sed 's|Include = /etc/pacman.d/|Include = scripts/pacman.d/|g' < rootfs/etc/pacman.conf > "$WORKDIR/pacman.conf"

cp --recursive --preserve=timestamps rootfs/* "$BUILDDIR/"
ln -sf /usr/lib/os-release "$BUILDDIR/etc/os-release"

fakechroot -- fakeroot -- \
    pacman -Sy --disable-sandbox-filesystem -r "$BUILDDIR" \
        --logfile /dev/null \
        --noconfirm --dbpath "$BUILDDIR/var/lib/pacman" \
        --config "$WORKDIR/pacman.conf" \
        --noscriptlet \
        --hookdir "$BUILDDIR/alpm-hooks/usr/share/libalpm/hooks/" "${PACKAGES[@]}"

fakechroot -- fakeroot -- chroot "$BUILDDIR" update-ca-trust
fakechroot -- fakeroot -- chroot "$BUILDDIR" pacman-key --init
fakechroot -- fakeroot -- chroot "$BUILDDIR" pacman-key --populate
fakechroot -- fakeroot -- chroot "$BUILDDIR" /usr/bin/systemd-sysusers --root "/"

# Replicate the relevant parts of the scriptlets and hooks skipped by --noscriptlet / --hookdir
fakechroot -- fakeroot -- chroot "$BUILDDIR" /usr/share/libalpm/scripts/cachyos-branding os-release
printf '%s\n' /usr/bin/fish /bin/fish >> "$BUILDDIR/etc/shells"
fakechroot -- fakeroot -- chroot "$BUILDDIR" /usr/bin/systemctl enable \
	ananicy-cpp \
	cachyos-rate-mirrors.timer \
	pkgfile-update.timer
chmod 0440 "$BUILDDIR/etc/sudoers.d/10-wheel"

fakechroot -- fakeroot -- chroot "$BUILDDIR" /usr/bin/systemctl mask \
	console-getty \
	systemd-firstboot \
	systemd-networkd \
	systemd-networkd-wait-online \
	systemd-resolved \
	systemd-tmpfiles-clean \
	systemd-tmpfiles-setup \
	systemd-tmpfiles-setup-dev \
	systemd-tmpfiles-setup-dev-early \
	tmp.mount

# Disable getty template units to prevent service failures caused by shared Hyper-V TTY devices across WSL instances
# See https://github.com/microsoft/WSL/issues/13595
ln -sf /dev/null "$BUILDDIR/etc/systemd/system/getty@.service"
ln -sf /dev/null "$BUILDDIR/etc/systemd/system/serial-getty@.service"

# Clear pacman keyring for reproducible builds
 rm -rf "$BUILDDIR"/etc/pacman.d/gnupg/*

# Normalize mtimes
find "$BUILDDIR" -exec touch --no-dereference --date="@$SOURCE_DATE_EPOCH" {} +

# Use fakeroot to map the gid / uid of the builder process to root
# See https://gitlab.archlinux.org/archlinux/archlinux-docker/-/issues/22
fakeroot -- \
    tar \
        --numeric-owner \
        --xattrs \
        --acls \
        --mtime="@$SOURCE_DATE_EPOCH" \
        --clamp-mtime \
        --sort=name \
        --pax-option=delete=atime,delete=ctime \
        --exclude-from=scripts/exclude \
        -C "$BUILDDIR" \
        -c . \
        -f "$OUTPUTDIR/cachyos-$IMAGE_VERSION.tar"

cd "$OUTPUTDIR"
xz -T0 -9 "cachyos-$IMAGE_VERSION.tar"
mv -v "cachyos-$IMAGE_VERSION.tar.xz" "cachyos-$IMAGE_VERSION.wsl"
sha256sum "cachyos-$IMAGE_VERSION.wsl" > "cachyos-$IMAGE_VERSION.wsl.SHA256"
echo "The sha256 hash of the image is:"
cat "cachyos-$IMAGE_VERSION.wsl.SHA256"
