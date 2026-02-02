#!/usr/bin/env bash
set -euo pipefail

log() { printf "[dotfiles] %s\n" "$*"; }
warn() { printf "[dotfiles][warn] %s\n" "$*" >&2; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d%H%M%S)"
SKIP_BREW="${SKIP_BREW:-${DOTFILES_SKIP_BREW:-}}"

init_submodules() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    git -C "$DOTFILES_DIR" submodule update --init --recursive >/dev/null 2>&1 || warn "submodule init failed"
  fi
}

backup_and_link() {
  local src="$DOTFILES_DIR/$1"
  local dst="$HOME/$2"

  if [[ ! -e "$src" ]]; then
    warn "Source missing: $src"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -e "$dst" || -L "$dst" ]]; then
    # Skip if already the correct symlink
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
      return
    fi
    mkdir -p "$BACKUP_DIR"
    mv "$dst" "$BACKUP_DIR/" 2>/dev/null || rm -rf "$dst"
    log "Backed up $dst to $BACKUP_DIR"
  fi

  ln -sfn "$src" "$dst"
  log "Linked $dst -> $src"
}

ensure_homebrew() {
  if [[ "$(uname)" != "Darwin" ]]; then
    warn "Homebrew install skipped (non-macOS)"
    return
  fi
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
}

install_brew_packages() {
  [[ "$(uname)" == "Darwin" ]] || return
  local pkgs=(
    git
    yarn
    pipx
    nvm
    cmake
    python
  )
  log "Installing Homebrew packages..."
  for pkg in "${pkgs[@]}"; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      continue
    fi
    if ! brew install "$pkg" >/dev/null; then
      warn "Failed to install $pkg"
    fi
  done

  # Bun (optional)
  if ! command -v bun >/dev/null 2>&1; then
    curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1 || warn "bun install failed"
  fi
}

ensure_pipx_uv() {
  if ! command -v pipx >/dev/null 2>&1; then
    warn "pipx not found, skipping uv installation"
    return
  fi

  if ! command -v uv >/dev/null 2>&1; then
    log "Installing uv via pipx..."
    pipx install uv >/dev/null 2>&1 || warn "Failed to install uv via pipx"
  fi
}

install_oh_my_zsh() {
  local bundled="$DOTFILES_DIR/.oh-my-zsh"
  if [[ -d "$bundled" ]]; then
    # Copy instead of symlink
    backup_and_copy "$bundled" "$HOME/.oh-my-zsh"
    log "Copied oh-my-zsh from dotfiles"
    return
  fi
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    return
  fi
  log "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" >/dev/null 2>&1 || \
    warn "oh-my-zsh install failed"
}

backup_and_copy() {
  local src="$1"
  local dst="$2"

  if [[ ! -e "$src" ]]; then
    warn "Source missing: $src"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -e "$dst" || -L "$dst" ]]; then
    # Skip if already the correct symlink
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
      return
    fi
    mkdir -p "$BACKUP_DIR"
    mv "$dst" "$BACKUP_DIR/" 2>/dev/null || rm -rf "$dst"
    log "Backed up $dst to $BACKUP_DIR"
  fi

  # Copy file or directory
  if [[ -d "$src" ]]; then
    cp -r "$src" "$dst"
    log "Copied directory $dst <- $src"
  else
    cp "$src" "$dst"
    log "Copied $dst <- $src"
  fi
}

link_all() {
  local mappings=(
    ".zshrc:.zshrc"
    ".zshenv:.zshenv"
    ".gitconfig:.gitconfig"
  )

  for entry in "${mappings[@]}"; do
    local src="${entry%%:*}"
    local dst="${entry#*:}"
    backup_and_link "$src" "$dst"
  done
}

setup_cursor_config() {
  # Check if Cursor is installed
  if ! command -v cursor >/dev/null 2>&1 && [[ ! -d "/Applications/Cursor.app" ]]; then
    warn "Cursor not found, skipping configuration setup"
    return
  fi

  log "Setting up Cursor configuration..."
  
  local source_dir="$DOTFILES_DIR/cursor"
  local cursor_support="$HOME/Library/Application Support/Cursor/User"
  
  if [[ ! -d "$source_dir" ]]; then
    warn "Cursor configuration not found in $source_dir"
    return
  fi
  
  mkdir -p "$cursor_support"
  
  # Copy settings.json
  if [[ -f "$source_dir/settings.json" ]]; then
    backup_and_copy "$source_dir/settings.json" "$cursor_support/settings.json"
  fi
  
  # Copy keybindings.json
  if [[ -f "$source_dir/keybindings.json" ]]; then
    backup_and_copy "$source_dir/keybindings.json" "$cursor_support/keybindings.json"
  fi
  
  # Copy profiles directory
  if [[ -d "$source_dir/profiles" ]]; then
    backup_and_copy "$source_dir/profiles" "$cursor_support/profiles"
  fi
  
  # Copy extensions.json if it exists
  if [[ -f "$source_dir/extensions.json" ]]; then
    backup_and_copy "$source_dir/extensions.json" "$cursor_support/extensions.json"
  fi
  
  # Collect all extensions to install (from extensions.txt and all profile extensions.json files)
  local extensions_to_install=()
  
  # Add extensions from main extensions.txt
  if [[ -f "$source_dir/extensions.txt" ]]; then
    while IFS= read -r extension; do
      [[ -z "$extension" ]] && continue
      extensions_to_install+=("$extension")
    done < "$source_dir/extensions.txt"
  fi
  
  # Extract extension IDs from profile extensions.json files
  if [[ -d "$source_dir/profiles" ]]; then
    for profile_ext_file in "$source_dir/profiles"/*/extensions.json; do
      if [[ -f "$profile_ext_file" ]]; then
        # Extract extension IDs from JSON using Python (more reliable than sed/grep)
        if command -v python3 >/dev/null 2>&1; then
          while IFS= read -r ext_id; do
            [[ -z "$ext_id" ]] && continue
            extensions_to_install+=("$ext_id")
          done < <(python3 -c "import json, sys; data = json.load(sys.stdin); items = data if isinstance(data, list) else [data]; [print(item.get('identifier', {}).get('id', '')) for item in items if item.get('identifier', {}).get('id')]" < "$profile_ext_file" 2>/dev/null)
        else
          # Fallback: simple grep for "id" field (less reliable but works for most cases)
          while IFS= read -r ext_id; do
            [[ -z "$ext_id" ]] && continue
            extensions_to_install+=("$ext_id")
          done < <(grep -oE '"id"\s*:\s*"[^"]+"' "$profile_ext_file" | sed -E 's/.*"id"\s*:\s*"([^"]+)".*/\1/')
        fi
      fi
    done
  fi
  
  # Install all unique extensions
  if [[ ${#extensions_to_install[@]} -gt 0 ]]; then
    log "Installing Cursor extensions (from main and profiles)..."
    # Remove duplicates and install
    printf '%s\n' "${extensions_to_install[@]}" | sort -u | while IFS= read -r extension; do
      [[ -z "$extension" ]] && continue
      cursor --install-extension "$extension" >/dev/null 2>&1 || warn "Failed to install extension: $extension"
    done
    log "Cursor extensions installation complete"
  fi
}


post_notes() {
  cat <<'EON'

[dotfiles] Done.
- Start services: brew services start skhd && brew services start yabai (requires SIP disable + permissions).
- Open a new terminal to let zsh load, or run: exec zsh
- For tmux: prefix is ` (backtick). Reload with `prefix + r`.
EON
}

ensure_homebrew
install_brew_packages
ensure_pipx_uv
init_submodules
install_oh_my_zsh
link_all
setup_cursor_config
post_notes