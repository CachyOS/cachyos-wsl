# Reproducing an image locally

Images are bit for bit [reproducible](https://reproducible-builds.org).

To reproduce an image locally, follow the below instructions.

## Disclaimer

Reproducible builds [expect the same build environment across builds](https://reproducible-builds.org/docs/definition/).

While it *should* be fine in most cases, this means we cannot guarantee that you will always be able to successfully reproduce a specific image locally over time.

Technically speaking, the older the image you're trying to reproduce is, the more chance there is to have more or less significant differences between your build environment and the one used to build the original image (for instance in terms of packages versions).  
Such differences can affect the build (and the resulting artifacts). Please note that failing to reproduce an image locally does not necessarily mean that it isn't reproducible per se, but can just be the result of significant enough differences between your build environment and the one used to build the original image.

You can avoid (or mitigate) eventual issues due to such differences by restoring all packages of your build environment to the build date of the original image (see the [related instructions from the Arch Wiki](https://wiki.archlinux.org/title/Arch_Linux_Archive#Restore_all_packages_to_a_specific_date)).

## Dependencies

Install the following Arch Linux packages:

- make
- devtools
- git
- fakechroot
- fakeroot
- diffoscope

## Prepare the build environment

Set the `IMAGE_VERSION` environment variable with the version of the image you're aiming to reproduce.  
For instance, if you're aiming to reproduce the `archlinux-2026.03.01.160197.wsl` image:

```bash
export IMAGE_VERSION="2026.03.01.160197"
```

Then clone the [archlinux-wsl repository](https://gitlab.archlinux.org/archlinux/archlinux-wsl.git), move into it and checkout to the state of the repo corresponding to the image version / date that you're aiming to reproduce:

```bash
git clone https://gitlab.archlinux.org/archlinux/archlinux-wsl.git
cd archlinux-wsl
git checkout --detach "$(git rev-list -1 --before="$(awk -F. '{print $1"-"$2"-"$3}' <<< "$IMAGE_VERSION") 09:00:00 UTC" main)"
```

Note that all the following instructions assume that you are at the root of the archlinux-wsl repository cloned above.

## Build the image

You can now (re)build the image you're aiming to reproduce:

```bash
make IMAGE_VERSION="$IMAGE_VERSION"
```

The following resulting artifacts will be located in `$PWD/workdir/output`:

- archlinux-$IMAGE_VERSION.wsl (the built image)
- archlinux-$IMAGE_VERSION.wsl.SHA256 (sha256 hash of the built image)

## Check the image reproducibility

Download the image you're aiming to reproduce, as well as the associated "SHA256" file, [from the mirror](https://fastly.mirror.pkgbuild.com/wsl/).

You can compare the content of the `archlinux-$IMAGE_VERSION.wsl.SHA256` file you downloaded from the mirror to the one generated during your local build. The sha256 hash should be the same, indicating that the image has been successfully reproduced.

Additionally, you can check differences between the `archlinux-$IMAGE_VERSION.wsl` image you downloaded from the mirror to the one built during your local build with `diffoscope` *(where `/tmp/archlinux-$IMAGE_VERSION.wsl` is the image downloaded from the mirror and `$PWD/workdir/output/archlinux-$IMAGE_VERSION.wsl` is the image built during your local build in the following example)*:

```bash
diffoscope /tmp/archlinux-$IMAGE_VERSION.wsl $PWD/workdir/output/archlinux-$IMAGE_VERSION.wsl
```

This should return no difference, acting as additional indicator that the image has been successfully reproduced.
