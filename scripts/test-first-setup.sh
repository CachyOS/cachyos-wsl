#!/bin/bash

# Run the first setup in a container from the given image, answering its prompts,
# then install the profiles and check the result.
# Usage: test-first-setup.sh IMAGE [PROFILES_ANSWER]
# PROFILES_ANSWER must not select docker, as the test installs podman first.
# Requires docker and expect.

set -euo pipefail

declare -r IMAGE="$1"
declare -r PROFILES_ANSWER="${2:-}"
declare -r USERNAME=tester

CID=$(docker run --detach --privileged "$IMAGE" sleep infinity)
export CID PROFILES_ANSWER USERNAME
trap 'docker rm --force "$CID" > /dev/null' EXIT

# The prompts read from a terminal and passwd discards input typed ahead, so answer each prompt once it is shown
expect <<'EOF'
set timeout 1800
spawn docker exec --interactive --tty $env(CID) /usr/lib/wsl/first-setup.sh
proc wait_for {prompt answer} {
	expect {
		$prompt { send "$answer\r" }
		"The profiles were not installed" { puts "\nThe profiles installation failed"; exit 1 }
		timeout { puts "\nTimed out waiting for \"$prompt\""; exit 1 }
		eof { puts "\nThe first setup ended before \"$prompt\""; exit 1 }
	}
}
wait_for "Enter new username: " $env(USERNAME)
wait_for "New password: " "TestPass123!x"
wait_for "Retype new password: " "TestPass123!x"
wait_for "press Enter to skip: " $env(PROFILES_ANSWER)
expect {
	-re {Enter a number \(default=[0-9]+\): } { send "\r"; exp_continue }
	-re {\[Y/n\] } { send "y\r"; exp_continue }
	"The profiles were not installed" { puts "\nThe profiles installation failed"; exit 1 }
	timeout { puts "\nTimed out waiting for the first setup to finish"; exit 1 }
	eof
}
lassign [wait] pid spawn_id os_error status
exit $status
EOF

docker exec --env USERNAME "$CID" /usr/bin/bash -euc '
	test "$(id -u "$USERNAME")" = 1000
	id -nG "$USERNAME" | grep -qw wheel
	test "$(getent passwd "$USERNAME" | cut -d: -f7)" = /usr/bin/fish
	test "$(passwd -S "$USERNAME" | cut -d" " -f2)" = P
	grep -q "^$USERNAME:" /etc/subuid
	grep -q "^$USERNAME:" /etc/subgid

	/usr/lib/wsl/install-profiles --noconfirm developer podman
	pacman -Q git github-cli podman podman-docker
	pacman -Qqk

	# Both profiles provide the docker command
	if /usr/lib/wsl/install-profiles --print docker podman; then exit 1; fi

	# Switch to Docker, which is refused while an unpackaged docker command (Docker Desktop) is present
	pacman -Rns --noconfirm podman-docker
	ln -s /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker /usr/bin/docker
	for profile in docker podman; do
		if error=$(/usr/lib/wsl/install-profiles --noconfirm "$profile" 2>&1); then exit 1; fi
		grep -q "doesn.t belong to a package" <<< "$error"
	done
	if pacman -Q docker 2> /dev/null; then exit 1; fi
	rm /usr/bin/docker
	/usr/lib/wsl/install-profiles --noconfirm docker
	pacman -Q docker docker-compose docker-buildx
	id -nG "$USERNAME" | grep -qw docker
	test -L /etc/systemd/system/sockets.target.wants/docker.socket
	pacman -Qqk

	# Without an NVIDIA GPU, the ai profile is neither offered nor installable
	list=$(/usr/lib/wsl/install-profiles --list)
	if grep -q "^  ai " <<< "$list"; then exit 1; fi
	if error=$(/usr/lib/wsl/install-profiles --noconfirm ai 2>&1); then exit 1; fi
	grep -q "needs an NVIDIA GPU" <<< "$error"
	# Pretend WSL exposes the CUDA library, then only resolve the ai packages (several GiB) without installing them
	mkdir -p /usr/lib/wsl/lib
	touch /usr/lib/wsl/lib/libcuda.so.1
	/usr/lib/wsl/install-profiles --list | grep -q "^  ai "
	mapfile -t packages < <(/usr/lib/wsl/install-profiles --print ai)
	resolved=$(pacman -Sp --print-format %n "${packages[@]}")
	grep -qx python-pytorch-cuda <<< "$resolved"
	# The Linux NVIDIA driver must never be installed, WSL provides it from Windows
	if grep -E "^(lib32-)?nvidia(-|$)" <<< "$resolved"; then exit 1; fi
'
echo "The first setup test passed"
