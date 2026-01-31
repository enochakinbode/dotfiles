# enochakinbode / dotfiles

Dotfiles for macOS: Zsh, Cursor, iTerm2, and development tools. All files live in this repo and get symlinked into `$HOME` by the bootstrap script.

## What's inside
- **Shell:** `.zshrc`, `.zshenv` with oh-my-zsh, nvm setup, and custom PATH configurations
- **Git:** `.gitconfig` with user configuration
- **Python toolchain:** `.config/uv/*` configuration
- **Cursor IDE:** Settings, keybindings, profiles, and extensions configuration
- **iTerm2:** Terminal preferences, dynamic profiles, and color presets

## Quick start (fresh machine)
```bash
# clone
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles

# run bootstrap (installs packages, oh-my-zsh, symlinks files, sets up Cursor)
./bootstrap.sh
```

Afterwards:
- Restart terminal or `exec zsh` to load the new shell config.
- Cursor and iTerm2 configurations will be automatically set up if the applications are installed.

### Environment Variables
- Set `SKIP_BREW=1` to skip Homebrew installs (handy when re-linking on an existing machine).

### Submodules
- `.oh-my-zsh` (ohmyzsh)
- `.config/zsh-custom/plugins/zsh-autosuggestions` (zsh-users)

## Syncing App Configurations

Before committing changes, extract the latest app configurations from your system:

```bash
# Extract all app configurations (Cursor, iTerm2)
./extract.sh --all

# Or extract specific apps
./extract.sh --cursor
./extract.sh --iterm
```

This script copies configurations from:
- **Cursor**: Settings, keybindings, profiles (with RTF-to-JSON conversion), and extensions list (including extensions from all profiles)
- **iTerm2**: Preferences, dynamic profiles, and color presets

The extraction script:
- Converts RTF-format JSON files to plain text (macOS sometimes saves JSON as RTF)
- Extracts extension IDs from profile-specific `extensions.json` files and includes them in the main `extensions.txt`
- Excludes `workspaceStorage` and `globalStorage` directories (machine-specific state)

When you run `./bootstrap.sh`, it will:
- Copy all configuration files to their proper locations
- Install all extensions from `extensions.txt` and from all profile `extensions.json` files

## Notes
- The bootstrap script backs up any existing files it replaces into `~/.dotfiles_backup_<timestamp>`.
- It is macOS-focused (Homebrew). On Linux it will still symlink files but skip package installs.
- Cursor and iTerm2 configurations are only set up if the applications are detected as installed.
