#!/usr/bin/env bash

set -euo pipefail

pacman -Sy --noconfirm sudo git openssh pacman-contrib curl

mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$AUR_SSH_KEY" > /root/.ssh/id_ed25519
chmod 600 /root/.ssh/id_ed25519
ssh-keyscan aur.archlinux.org >> /root/.ssh/known_hosts

git config --global user.name "lumexren"
git config --global user.email "$EMAIL"
git config --global --add safe.directory '*'

git clone ssh://aur@aur.archlinux.org/${AUR_REPO}.git aur-repo

if [[ -f aur-repo/PKGBUILD ]]; then
    old_ver="$(grep "^pkgver=" aur-repo/PKGBUILD 2>/dev/null | cut -d= -f2 | tr -d ' "' || printf "")"
    old_rel="$(grep "^pkgrel=" aur-repo/PKGBUILD 2>/dev/null | cut -d= -f2 | tr -d ' "' || printf "0")"
else
    old_ver=""
    old_rel="0"
fi

if [[ "$old_ver" == "$VERSION" && "${FORCE_UPDATE:-false}" != "true" ]]; then
    echo "Version $VERSION is already up to date. Skipping."
    exit 0
fi

if [[ "$old_ver" == "$VERSION" ]]; then
    new_rel=$(( old_rel + 1 ))
else
    new_rel="1"
fi

cd aur

sed -i "s|^pkgver=.*|pkgver=${VERSION}|" PKGBUILD
sed -i "s|^pkgrel=.*|pkgrel=$new_rel|" PKGBUILD

if ! id -u builder >/dev/null 2>&1; then
    useradd -m builder
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi
chown -R builder:builder .

sudo -u builder bash -c "updpkgsums && makepkg --printsrcinfo > .SRCINFO"

cd ../aur-repo
cp ../aur/{PKGBUILD,.SRCINFO} .

git add PKGBUILD .SRCINFO

if git diff --cached --quiet && [[ "${FORCE_UPDATE:-false}" != "true" ]]; then
    echo "No changes detected, skipping push."
    exit 0
fi

git commit -m "release: update to ${VERSION}-${new_rel}"
git push origin master