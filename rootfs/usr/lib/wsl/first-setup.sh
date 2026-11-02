#!/bin/bash

set -u

declare -r DEFAULT_UID=1000
declare -r DEFAULT_GROUPS=wheel

# Show some documentation
cat <<EOF
Welcome to the CachyOS WSL image!

This image is maintained at <https://github.com/CachyOS/cachyos-wsl>.

Please, report bugs at <https://github.com/CachyOS/cachyos-wsl/issues>.
Note that WSL 1 is not supported, and that this image requires a CPU supporting x86-64-v3 (AVX2).

For more information about CachyOS, see the CachyOS Wiki at <https://wiki.cachyos.org/>.

While images are built regularly, it is strongly recommended running "sudo pacman -Syu" right after the first setup due to the rolling release nature of CachyOS.
EOF

# Generate pacman lsign key (see the "/!\/!\/!\ Note" at https://gitlab.archlinux.org/archlinux/archlinux-docker#principles)
echo -e "\nGenerating pacman keys..." && pacman-key --init &> /dev/null && echo "Done"
echo -e "\nPopulating keyring..." && pacman-key --populate archlinux cachyos &> /dev/null && echo "Done"

# Not fatal, the default mirrorlists work anywhere (just possibly slower)
echo -e "\nRanking mirrors, this can take a minute..."
if cachyos-rate-mirrors &> /dev/null; then
	echo "Done"
else
	echo "Failed to rank mirrors, keeping the default mirrorlists"
fi

# Create the default user, WSL then logs in as $DEFAULT_UID (see defaultUid in /etc/wsl-distribution.conf)
username=$(getent passwd "$DEFAULT_UID" | cut -d: -f1)
if [ -n "$username" ]; then
	echo -e "\nUser account \"$username\" already exists, skipping creation"
else
	echo -e "\nPlease create a default user account. The username does not need to match your Windows username."
	echo "For more information visit: https://aka.ms/wslusers"
	while read -rp 'Enter new username: ' name; do
		if useradd --create-home --uid "$DEFAULT_UID" --groups "$DEFAULT_GROUPS" --shell /usr/bin/fish -- "$name"; then
			username=$name
			break
		fi
	done
	# read failed (e.g. EOF), WSL will run this script again on the next launch
	[ -n "$username" ] || exit 1
fi

# Also resumes a previous run that was interrupted before the password was set,
# as the account would otherwise be left with a locked password
if [ "$(passwd -S -- "$username" | awk '{print $2}')" != P ]; then
	until passwd -- "$username"; do
		[ -t 0 ] || exit 1
		echo "Please try again"
	done
fi
