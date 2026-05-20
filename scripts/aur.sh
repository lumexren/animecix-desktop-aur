#!/usr/bin/env bash

set -euo pipefail

pacman -Sy --noconfirm sudo git openssh pacman-contrib curl

mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$AUR_SSH_KEY" > /root/.ssh/id_ed25519
chmod 600 /root/.ssh/id_ed25519
ssh-keyscan aur.archlinux.org >> /root/.ssh/known_hosts

git config --global user.name "erffy"
git config --global user.email "$EMAIL"

cd aur/$AUR_REPO

old_ver="$(grep "^pkgver=" PKGBUILD | cut -d= -f2 || printf "")"
old_rel="$(grep "^pkgrel=" PKGBUILD | cut -d= -f2 || printf "0")"

if [[ "$old_ver" == "$VERSION" && "${FORCE_UPDATE:-false}" != "true" ]]; then
    echo "Version $VERSION is already up to date. Skipping."
    exit 0
fi

if [[ "$old_ver" == "$VERSION" ]]; then
    new_rel=$(( old_rel + 1 ))
else
    new_rel="1"
fi

sed -i "s|^pkgver=.*|pkgver=${VERSION}|" PKGBUILD
sed -i "s|^pkgrel=.*|pkgrel=$new_rel|" PKGBUILD

useradd -m builder
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
chown -R builder:builder .

sudo -u builder bash -c "updpkgsums && makepkg --printsrcinfo > .SRCINFO"

cd ../..
git clone ssh://aur@aur.archlinux.org/${AUR_REPO}.git aur-repo
cp aur/$AUR_REPO/{PKGBUILD,.SRCINFO} aur-repo/

cd aur-repo
git add PKGBUILD .SRCINFO

if git diff --cached --quiet && [[ "${FORCE_UPDATE:-false}" != "true" ]]; then
    echo "No changes detected, skipping push."
    exit 0
fi

git commit -m "release: update to ${VERSION}-${new_rel}"
git push origin master