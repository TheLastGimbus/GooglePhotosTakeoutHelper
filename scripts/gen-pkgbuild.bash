#!/bin/bash
# Script to generate PKGBUILD files for Arch Linux

set -e  # fail if generating sha fails or smth

if [ -z "$1" ]; then
  echo "Usage: $0 <path-to-gpth-linux-binary>"
  exit 1
fi

if [ ! -f "$1" ]; then
  echo "Error: File '$1' not found!"
  exit 1
fi

pkgver=$(grep -oP '(?<=version: ).*' pubspec.yaml)
if [ -z "$pkgver" ]; then
  echo "Error: Could not extract version from pubspec.yaml"
  exit 1
fi

sha256sum=$(sha256sum "$1" | cut -d " " -f 1)
if [ -z "$sha256sum" ]; then
  echo "Error: Could not generate sha256sum for '$1'"
  exit 1
fi

txt="# Maintainer: TheLastGimbus <mateusz.soszynski@tuta.io>
pkgname=gpth-bin
pkgver=${pkgver}
pkgrel=1
pkgdesc='Tool to help you with exporting stuff from Google Photos'
arch=('x86_64')
url='https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper'
license=('Apache')
depends=()
provides=('gpth')
conflicts=('gpth')
options=('!strip')
source=(\"\${url}/releases/download/v\${pkgver}/gpth-linux\")
sha256sums=('${sha256sum}')

package() {
    install -Dm755 \"\${srcdir}/gpth-linux\" \"\${pkgdir}/usr/bin/gpth\"
}"

echo "$txt" | tee PKGBUILD
