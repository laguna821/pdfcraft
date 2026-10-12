#!/usr/bin/env bash
# Achmage PDFCraft installer for macOS and Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/laguna821/pdfcraft/main/install/install.sh | bash
#
# macOS (11+, Apple silicon and Intel): the app goes to /Applications (or ~/Applications). curl
#   sets no quarantine flag, so Gatekeeper opens the unsigned app without a warning.
# Arch Linux, CachyOS, EndeavourOS, Manjaro: builds the release's PKGBUILD with makepkg and
#   installs it with pacman (remove with `sudo pacman -R achmage-pdfcraft-bin`). Runs natively on
#   Wayland (Niri, Hyprland, Sway, KDE, GNOME); no FUSE or XWayland.
# Debian/Ubuntu: the .deb with apt. Fedora/openSUSE: the .rpm with dnf/zypper.
# Anything else: the tarball into ~/.local (no root).
#
# Every download is checked against the release's SHA256SUMS.txt.
# Options: ACHMAGE_VERSION=0.1.0 (a specific release), ACHMAGE_METHOD=tarball (skip the package
# manager on Linux).
set -euo pipefail

REPO="laguna821/pdfcraft"
say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "this installer needs '$1'"; }

need curl
need uname
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ -n "${ACHMAGE_VERSION:-}" ]; then
  TAG="v${ACHMAGE_VERSION#v}"
else
  say "looking up the latest release on GitHub"
  TAG="$(curl -fsSL -H 'User-Agent: achmage-pdfcraft-installer' "https://api.github.com/repos/$REPO/releases/latest" |
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  [ -n "$TAG" ] || die "couldn't find the latest release (GitHub API rate limit? try again later)"
fi
VERSION="${TAG#v}"
BASE="https://github.com/$REPO/releases/download/$TAG"
say "Achmage PDFCraft $VERSION"

curl -fsSL -o "$WORK/SHA256SUMS.txt" "$BASE/SHA256SUMS.txt" || die "no SHA256SUMS.txt in release $TAG"

fetch() {
  local name="$1"
  say "downloading $name"
  curl -fL --progress-bar -o "$WORK/$name" "$BASE/$name" || die "download failed: $name"
  local expected actual
  expected="$(grep -E "[[:space:]]\*?$name\$" "$WORK/SHA256SUMS.txt" | head -n 1 | cut -d' ' -f1)"
  [ -n "$expected" ] || die "SHA256SUMS.txt has no entry for $name"
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$WORK/$name" | cut -d' ' -f1)"
  else
    actual="$(shasum -a 256 "$WORK/$name" | cut -d' ' -f1)"
  fi
  [ "$expected" = "$actual" ] || die "checksum mismatch for $name"
}

sudo_() { if [ "$(id -u)" = 0 ]; then "$@"; else need sudo; sudo "$@"; fi; }

install_macos() {
  local zip="achmage-pdfcraft-$VERSION-macos-universal.app.zip"
  fetch "$zip"
  need ditto
  ditto -x -k "$WORK/$zip" "$WORK/app"
  local app="$WORK/app/Achmage PDFCraft.app"
  [ -d "$app" ] || die "the archive has no Achmage PDFCraft.app"
  local dest="/Applications"
  if [ ! -w "$dest" ]; then
    if sudo -n true 2>/dev/null; then :; else dest="$HOME/Applications"; mkdir -p "$dest"; fi
  fi
  say "installing to $dest"
  if [ -w "$dest" ]; then
    rm -rf "$dest/Achmage PDFCraft.app"
    ditto "$app" "$dest/Achmage PDFCraft.app"
    xattr -dr com.apple.quarantine "$dest/Achmage PDFCraft.app" 2>/dev/null || true
  else
    sudo rm -rf "$dest/Achmage PDFCraft.app"
    sudo ditto "$app" "$dest/Achmage PDFCraft.app"
    sudo xattr -dr com.apple.quarantine "$dest/Achmage PDFCraft.app" 2>/dev/null || true
  fi
  say "done: open 'Achmage PDFCraft' from Launchpad or $dest"
}

linux_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo x86_64 ;;
    aarch64 | arm64) echo aarch64 ;;
    *) die "unsupported CPU $(uname -m) (x86_64 and aarch64 are built)" ;;
  esac
}

install_arch() {
  need pacman
  if [ "$(id -u)" = 0 ]; then die "run this as your normal user on Arch (makepkg refuses root); it asks for sudo itself"; fi
  say "installing build tools for makepkg (base-devel) if missing"
  sudo_ pacman -S --needed --noconfirm base-devel >/dev/null
  curl -fsSL -o "$WORK/PKGBUILD" "$BASE/PKGBUILD" || die "no PKGBUILD in release $TAG"
  expected="$(grep -E '[[:space:]]\*?PKGBUILD$' "$WORK/SHA256SUMS.txt" | head -n 1 | cut -d' ' -f1)"
  [ -z "$expected" ] || [ "$expected" = "$(sha256sum "$WORK/PKGBUILD" | cut -d' ' -f1)" ] || die "checksum mismatch for PKGBUILD"
  say "building and installing the pacman package (achmage-pdfcraft-bin)"
  (cd "$WORK" && makepkg -si --noconfirm)
  say "done: launch 'Achmage PDFCraft' from your launcher, or run 'pdfcraft'"
  if ! pacman -Qq xdg-desktop-portal-gnome xdg-desktop-portal-gtk >/dev/null 2>&1; then
    say "tip (Niri and other wlroots compositors): 'sudo pacman -S xdg-desktop-portal-gnome' gives native file dialogs"
  fi
  if ! pacman -Qq fcitx5-hangul >/dev/null 2>&1; then
    say "tip: for Korean typing install 'fcitx5-hangul' (and fcitx5-configtool)"
  fi
}

install_deb() {
  local f="achmage-pdfcraft-$VERSION-linux-$1.deb"
  fetch "$f"
  sudo_ apt-get install -y "$WORK/$f"
  say "done: launch 'Achmage PDFCraft' from your applications menu"
}

install_rpm() {
  local f="achmage-pdfcraft-$VERSION-linux-$1.rpm"
  fetch "$f"
  if command -v dnf >/dev/null 2>&1; then sudo_ dnf install -y "$WORK/$f"; else sudo_ zypper --non-interactive install --allow-unsigned-rpm "$WORK/$f"; fi
  say "done: launch 'Achmage PDFCraft' from your applications menu"
}

install_tarball() {
  local arch="$1" name="achmage-pdfcraft-$VERSION-linux-$1"
  fetch "$name.tar.gz"
  local prefix="$HOME/.local/opt/achmage-pdfcraft"
  rm -rf "$prefix"
  mkdir -p "$prefix" "$HOME/.local/bin" "$HOME/.local/share/applications"
  tar -C "$WORK" -xzf "$WORK/$name.tar.gz"
  cp -a "$WORK/$name/." "$prefix/"
  ln -sf "$prefix/bin/pdfcraft" "$HOME/.local/bin/achmage-pdfcraft"
  ln -sf "$prefix/bin/pdfcraft-cli" "$HOME/.local/bin/pdfcraft-cli"
  local desktop
  desktop="$(find "$prefix/share/applications" -name '*.desktop' | head -n 1)"
  if [ -n "$desktop" ]; then
    sed -e "s|^Exec=pdfcraft|Exec=$prefix/bin/pdfcraft|" -e "s|^TryExec=pdfcraft|TryExec=$prefix/bin/pdfcraft|" "$desktop" \
      >"$HOME/.local/share/applications/$(basename "$desktop")"
  fi
  if [ -d "$prefix/share/icons" ]; then
    mkdir -p "$HOME/.local/share/icons"
    cp -a "$prefix/share/icons/." "$HOME/.local/share/icons/"
  fi
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  say "done: installed to $prefix; run 'achmage-pdfcraft' (make sure ~/.local/bin is on PATH)"
}

case "$(uname -s)" in
  Darwin) install_macos ;;
  Linux)
    ARCH="$(linux_arch)"
    if [ "${ACHMAGE_METHOD:-}" = "tarball" ]; then
      install_tarball "$ARCH"
    elif command -v pacman >/dev/null 2>&1; then
      install_arch
    elif command -v apt-get >/dev/null 2>&1; then
      install_deb "$([ "$ARCH" = x86_64 ] && echo x86_64 || echo aarch64)"
    elif command -v dnf >/dev/null 2>&1 || command -v zypper >/dev/null 2>&1; then
      install_rpm "$ARCH"
    else
      install_tarball "$ARCH"
    fi
    ;;
  *) die "unsupported system $(uname -s); on Windows use install.ps1" ;;
esac
