#!/usr/bin/env bash
set -euo pipefail

log() { printf "[dotfiles] %s\n" "$*"; }
warn() { printf "[dotfiles][warn] %s\n" "$*" >&2; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Extract flags
EXTRACT_ALL=false
EXTRACT_CURSOR=false
EXTRACT_OH_MY_ZSH=false

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        EXTRACT_ALL=true
        shift
        ;;
      --cursor)
        EXTRACT_CURSOR=true
        shift
        ;;
      --oh-my-zsh)
        EXTRACT_OH_MY_ZSH=true
        shift
        ;;
      *)
        warn "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  # If --all is set, enable all extractions
  if [[ "$EXTRACT_ALL" == "true" ]]; then
    EXTRACT_CURSOR=true
    EXTRACT_OH_MY_ZSH=true
  fi
}

extract_cursor_config() {
  log "Extracting Cursor configuration..."
  
  local cursor_support="$HOME/Library/Application Support/Cursor/User"
  local target_dir="$DOTFILES_DIR/cursor"
  
  if [[ ! -d "$cursor_support" ]]; then
    warn "Cursor configuration not found at $cursor_support"
    return
  fi
  
  mkdir -p "$target_dir"
  
  # Copy settings.json, converting RTF to plain text if needed
  if [[ -f "$cursor_support/settings.json" ]]; then
    if file "$cursor_support/settings.json" | grep -q "Rich Text Format"; then
      textutil -convert txt -stdout "$cursor_support/settings.json" > "$target_dir/settings.json" 2>/dev/null || \
      cp "$cursor_support/settings.json" "$target_dir/settings.json"
      log "Converted and copied Cursor settings.json (RTF -> JSON)"
    else
      cp "$cursor_support/settings.json" "$target_dir/settings.json"
      log "Copied Cursor settings.json"
    fi
  fi
  
  # Copy keybindings.json, converting RTF to plain text if needed
  if [[ -f "$cursor_support/keybindings.json" ]]; then
    if file "$cursor_support/keybindings.json" | grep -q "Rich Text Format"; then
      textutil -convert txt -stdout "$cursor_support/keybindings.json" > "$target_dir/keybindings.json" 2>/dev/null || \
      cp "$cursor_support/keybindings.json" "$target_dir/keybindings.json"
      log "Converted and copied Cursor keybindings.json (RTF -> JSON)"
    else
      cp "$cursor_support/keybindings.json" "$target_dir/keybindings.json"
      log "Copied Cursor keybindings.json"
    fi
  fi
  
  # Copy profiles.json (user profiles configuration)
  if [[ -f "$cursor_support/profiles.json" ]]; then
    cp "$cursor_support/profiles.json" "$target_dir/profiles.json"
    log "Copied Cursor profiles.json"
  fi
  
  # Copy profiles directory (profile-specific settings)
  if [[ -d "$cursor_support/profiles" ]]; then
    mkdir -p "$target_dir/profiles"
    # Copy each profile directory, converting RTF files to plain text and excluding globalStorage
    for profile_dir in "$cursor_support/profiles"/*; do
      if [[ -d "$profile_dir" ]]; then
        local profile_name="$(basename "$profile_dir")"
        mkdir -p "$target_dir/profiles/$profile_name"
        
        # Copy settings.json, converting RTF to plain text if needed
        if [[ -f "$profile_dir/settings.json" ]]; then
          if file "$profile_dir/settings.json" | grep -q "Rich Text Format"; then
            # Convert RTF to plain text using textutil (macOS built-in)
            textutil -convert txt -stdout "$profile_dir/settings.json" > "$target_dir/profiles/$profile_name/settings.json" 2>/dev/null || \
            cp "$profile_dir/settings.json" "$target_dir/profiles/$profile_name/settings.json"
            log "Converted and copied profile $profile_name settings.json (RTF -> JSON)"
          else
            cp "$profile_dir/settings.json" "$target_dir/profiles/$profile_name/settings.json"
            log "Copied profile $profile_name settings.json"
          fi
        fi
        
        # Copy extensions.json if it exists
        if [[ -f "$profile_dir/extensions.json" ]]; then
          if file "$profile_dir/extensions.json" | grep -q "Rich Text Format"; then
            textutil -convert txt -stdout "$profile_dir/extensions.json" > "$target_dir/profiles/$profile_name/extensions.json" 2>/dev/null || \
            cp "$profile_dir/extensions.json" "$target_dir/profiles/$profile_name/extensions.json"
            log "Converted and copied profile $profile_name extensions.json (RTF -> JSON)"
          else
            cp "$profile_dir/extensions.json" "$target_dir/profiles/$profile_name/extensions.json"
            log "Copied profile $profile_name extensions.json"
          fi
        fi
        
        # Copy keybindings.json if it exists
        if [[ -f "$profile_dir/keybindings.json" ]]; then
          if file "$profile_dir/keybindings.json" | grep -q "Rich Text Format"; then
            textutil -convert txt -stdout "$profile_dir/keybindings.json" > "$target_dir/profiles/$profile_name/keybindings.json" 2>/dev/null || \
            cp "$profile_dir/keybindings.json" "$target_dir/profiles/$profile_name/keybindings.json"
            log "Converted and copied profile $profile_name keybindings.json (RTF -> JSON)"
          else
            cp "$profile_dir/keybindings.json" "$target_dir/profiles/$profile_name/keybindings.json"
            log "Copied profile $profile_name keybindings.json"
          fi
        fi
        
        # Note: globalStorage is intentionally skipped (machine-specific state)
      fi
    done
    log "Copied Cursor profiles directory"
  fi
  
  # Copy extensions list if it exists
  if [[ -f "$cursor_support/extensions.json" ]]; then
    cp "$cursor_support/extensions.json" "$target_dir/extensions.json"
    log "Copied Cursor extensions.json"
  fi
  
  # Export list of installed extensions
  local extensions_file="$target_dir/extensions.txt"
  if command -v cursor >/dev/null 2>&1; then
    cursor --list-extensions > "$extensions_file" 2>/dev/null && log "Exported Cursor extensions list" || warn "Failed to export Cursor extensions list"
  fi
  
  # Also extract extension IDs from profile extensions.json files and add to extensions.txt
  if [[ -d "$target_dir/profiles" ]]; then
    local profile_extensions=()
    for profile_ext_file in "$target_dir/profiles"/*/extensions.json; do
      if [[ -f "$profile_ext_file" ]]; then
        # Extract extension IDs from JSON
        if command -v python3 >/dev/null 2>&1; then
          while IFS= read -r ext_id; do
            [[ -z "$ext_id" ]] && continue
            profile_extensions+=("$ext_id")
          done < <(python3 -c "import json, sys; data = json.load(sys.stdin); items = data if isinstance(data, list) else [data]; [print(item.get('identifier', {}).get('id', '')) for item in items if item.get('identifier', {}).get('id')]" < "$profile_ext_file" 2>/dev/null)
        else
          # Fallback: simple grep
          while IFS= read -r ext_id; do
            [[ -z "$ext_id" ]] && continue
            profile_extensions+=("$ext_id")
          done < <(grep -oE '"id"\s*:\s*"[^"]+"' "$profile_ext_file" | sed -E 's/.*"id"\s*:\s*"([^"]+)".*/\1/')
        fi
      fi
    done
    
    # Append profile extensions to extensions.txt (removing duplicates)
    if [[ ${#profile_extensions[@]} -gt 0 ]]; then
      {
        [[ -f "$extensions_file" ]] && cat "$extensions_file"
        printf '%s\n' "${profile_extensions[@]}"
      } | sort -u > "$extensions_file.tmp" && mv "$extensions_file.tmp" "$extensions_file"
      log "Added profile extensions to extensions.txt"
    fi
  fi
  
  # Note: workspaceStorage is intentionally skipped as it's workspace-specific and machine-specific
}

extract_oh_my_zsh() {
  log "Extracting oh-my-zsh configuration..."
  
  local source_dir="$HOME/.oh-my-zsh"
  local target_dir="$DOTFILES_DIR/.oh-my-zsh"
  
  if [[ ! -d "$source_dir" ]]; then
    warn "oh-my-zsh not found at $source_dir"
    return
  fi
  
  log "Copying oh-my-zsh directory (this may take a moment)..."
  # Remove existing target if it exists
  if [[ -d "$target_dir" ]]; then
    rm -rf "$target_dir"
  fi
  
  # Copy the entire directory, excluding .git if it's a submodule
  if [[ -d "$source_dir/.git" ]]; then
    # If it's a git repo, copy but exclude .git
    rsync -a --exclude='.git' "$source_dir/" "$target_dir/" 2>/dev/null || {
      cp -r "$source_dir" "$target_dir"
      rm -rf "$target_dir/.git" 2>/dev/null
    }
    log "Copied oh-my-zsh (excluding .git)"
  else
    cp -r "$source_dir" "$target_dir"
    log "Copied oh-my-zsh directory"
  fi
  
  log "oh-my-zsh extraction complete"
}

extract_configs() {
  if [[ "$EXTRACT_CURSOR" == "true" ]]; then
    extract_cursor_config
  fi
  
  if [[ "$EXTRACT_OH_MY_ZSH" == "true" ]]; then
    extract_oh_my_zsh
  fi
  
  if [[ "$EXTRACT_ALL" == "true" || "$EXTRACT_CURSOR" == "true" || "$EXTRACT_OH_MY_ZSH" == "true" ]]; then
    log "Configuration extraction complete!"
  else
    warn "No extraction flags provided. Use --all, --cursor, or --oh-my-zsh"
    exit 1
  fi
}

# Parse arguments and extract configurations
parse_args "$@"
extract_configs

