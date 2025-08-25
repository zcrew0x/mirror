#!/usr/bin/env bash
set -e
cd ~

# -------- Colors --------
GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RED="\033[0;31m"; RESET="\033[0m"
info()    { echo -e "${YELLOW}> $1${RESET}"; }
success() { echo -e "${GREEN}✔ $1${RESET}"; }
fail()    { echo -e "${RED}✘ $1${RESET}"; }

# -------- Paths --------
DOWNLOAD_DIR="$HOME/.cache/hyprdots"
LOG_FILE="$HOME/.cache/hyprdotsSetup.log"
METADATA_FILE="$HOME/.config/hyprdots/metadata.json"

SOURCE_LIB_DIR="$DOWNLOAD_DIR/lib"
SOURCE_BIN_DIR="$DOWNLOAD_DIR/bin"
SOURCE_SHARE_DIR="$DOWNLOAD_DIR/share"

TARGET_LIB_DIR="/usr/lib/hyprdots"
TARGET_BIN_DIR="/usr/local/bin"
TARGET_SHARE_DIR="/usr/share/hyprdots"
MAIN_INSTALLER="$TARGET_LIB_DIR/main.py"

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$METADATA_FILE")"
:> "$LOG_FILE"
log(){ echo "[$(date +'%F %T')] [$1] $2" >>"$LOG_FILE"; }

create_dir_if_not_exists(){ sudo mkdir -p "$1"; }
remove_files_in_a_dir(){ sudo rm -rf "$1"/* 2>/dev/null || true; }
remove_dir_if_exists(){ [ -d "$1" ] && sudo rm -rf "$1" || true; }

# -------- Dependency install (Ubuntu/apt) --------
installDependencies(){
  info "Installing dependencies (Ubuntu)..."
  sudo apt update
  sudo apt install -y curl git rsync python3 python3-pip python3-rich figlet
  success "Base deps installed."
}

# -------- Download HyprDots (stable -> prerelease -> rolling) --------
downloadStableOrFallback(){
  info "Fetching latest stable release tag..."
  mkdir -p "$DOWNLOAD_DIR"

  # 1) Lấy stable (non-prerelease). Dùng awk để tránh cần jq.
  latest_tag="$(curl -s https://api.github.com/repos/sbalghari/HyprDots/releases \
    | awk '/"prerelease": false/{p=1} p && /"tag_name":/ {gsub(/[",]/,"",$2); print $2; exit}')"

  # 2) Nếu không có stable -> lấy pre-release đầu tiên (mới nhất trong danh sách)
  if [ -z "$latest_tag" ]; then
    info "No stable release found, trying pre-release…"
    latest_tag="$(curl -s https://api.github.com/repos/sbalghari/HyprDots/releases \
      | awk '/"tag_name":/ {gsub(/[",]/,"",$2); print $2; exit}')"
  fi

  # 3) Nếu vẫn rỗng -> fallback rolling
  if [ -z "$latest_tag" ]; then
    info "No release tags found. Falling back to rolling (main)…"
    git clone https://github.com/sbalghari/HyprDots.git "$DOWNLOAD_DIR" >>"$LOG_FILE" 2>&1
    success "Cloned HyprDots (rolling)"
    echo "rolling" > "$DOWNLOAD_DIR/.release_type"
    return
  fi

  success "Using release tag: $latest_tag"
  git clone --branch "$latest_tag" --depth 1 https://github.com/sbalghari/HyprDots.git "$DOWNLOAD_DIR" >>"$LOG_FILE" 2>&1
  echo "tag:$latest_tag" > "$DOWNLOAD_DIR/.release_type"
  success "Cloned HyprDots @$latest_tag"
}

downloadRollingRelease(){
  mkdir -p "$DOWNLOAD_DIR"
  git clone https://github.com/sbalghari/HyprDots.git "$DOWNLOAD_DIR" >>"$LOG_FILE" 2>&1
  echo "rolling" > "$DOWNLOAD_DIR/.release_type"
  success "Cloned HyprDots (rolling)"
}

# -------- Metadata --------
generateMetadata(){
  local release_type="$1"
  local repo_dir="$DOWNLOAD_DIR"
  local installed_at version commit_hash tag

  installed_at=$(date --iso-8601=seconds)
  commit_hash=$(git -C "$repo_dir" rev-parse --short HEAD || echo "unknown")

  if [ "$release_type" = "stable" ]; then
    version=$(git -C "$repo_dir" describe --tags --abbrev=0 2>/dev/null || echo "unknown")
  elif [[ "$release_type" == tag:* ]]; then
    tag="${release_type#tag:}"
    version="$tag"
    release_type="stable"
  else
    tag=$(git -C "$repo_dir" describe --tags --abbrev=0 2>/dev/null || echo "untagged")
    version="${tag}-${commit_hash}"
    release_type="rolling"
  fi

  cat <<EOF | tee "$METADATA_FILE" >/dev/null
{
  "release_type": "$release_type",
  "version": "$version",
  "installed_at": "$installed_at"
}
EOF
  success "Saved metadata: $version"
}

# -------- Copy helper (rsync) --------
copy_dir(){
  local src="$1"; local dst="$2"
  [ -d "$src" ] || { fail "Missing $src"; return 1; }
  sudo rsync -a "$src/" "$dst/"
}

# -------- Setup to system dirs --------
setup(){
  info "Cleaning old targets..."
  remove_files_in_a_dir "$TARGET_BIN_DIR"
  remove_dir_if_exists "$TARGET_LIB_DIR"
  remove_dir_if_exists "$TARGET_SHARE_DIR"

  info "Creating targets..."
  create_dir_if_not_exists "$TARGET_LIB_DIR"
  create_dir_if_not_exists "$TARGET_BIN_DIR"
  create_dir_if_not_exists "$TARGET_SHARE_DIR"

  info "Copying files..."
  copy_dir "$SOURCE_LIB_DIR" "$TARGET_LIB_DIR"
  copy_dir "$SOURCE_BIN_DIR" "$TARGET_BIN_DIR"
  copy_dir "$SOURCE_SHARE_DIR" "$TARGET_SHARE_DIR"
  success "Files installed to system."
}

# -------- Run main installer (python) --------
run_main_installer(){
  if [ -f "$MAIN_INSTALLER" ]; then
    info "Launching main installer..."
    python3 "$MAIN_INSTALLER"
    success "Main installer finished."
  else
    info "No main installer found at $MAIN_INSTALLER (skipping)."
  fi
}

# -------- MAIN --------
header(){
  clear
  command -v figlet >/dev/null && figlet "HyprDots" || true
  echo -e "${GREEN}HyprDots Ubuntu Installer${RESET}"
}

main(){
  installDependencies
  header

  echo
  echo "Choose release to install:"
  echo "  1) Auto (stable → prerelease → rolling)"
  echo "  2) Rolling (always latest from main)"
  read -rp "Enter 1 or 2 [1]: " choice
  choice=${choice:-1}

  [ -d "$DOWNLOAD_DIR" ] && rm -rf "$DOWNLOAD_DIR"

  if [ "$choice" = "2" ]; then
    downloadRollingRelease
  else
    downloadStableOrFallback
  fi

  setup
  # Determine what we actually installed to fill metadata:
  installed_type=$(cat "$DOWNLOAD_DIR/.release_type" 2>/dev/null || echo "rolling")
  generateMetadata "$installed_type"
  run_main_installer

  echo
  read -rp "Reboot now? [y/N]: " rb
  if [[ "$rb" =~ ^[Yy]$ ]]; then
    sudo reboot
  else
    success "Done. You can reboot later."
  fi

  rm -rf "$DOWNLOAD_DIR" || true
}

main
