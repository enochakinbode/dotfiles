# enochakinbode / dotfiles

Dotfiles for macOS: Zsh, Cursor, and development tools. Configuration files are symlinked into `$HOME` by the bootstrap script, while app-specific configs (Cursor) are copied to their respective locations.

## What's inside
- **Shell:** `.zshrc`, `.zshenv` with oh-my-zsh, nvm setup, and custom PATH configurations
- **Git:** `.gitconfig` with user configuration
- **Cursor IDE:** Settings, keybindings, profiles, and extensions configuration
- **iTerm2:** Terminal preferences stored in `iterm2/` (manual setup required)

## Quick start (fresh machine)
```bash
# clone
git clone https://github.com/enochakinbode/dotfiles.git
cd ~/dotfiles

# run bootstrap (installs packages, oh-my-zsh, symlinks files, sets up Cursor)
./bootstrap.sh
```

Afterwards:
- Restart terminal or `exec zsh` to load the new shell config.
- Cursor configuration will be automatically set up if the application is installed.
- iTerm2 preferences are stored in `iterm2/` but must be manually imported via iTerm2's preferences.

### Environment Variables
- Set `SKIP_BREW=1` or `DOTFILES_SKIP_BREW=1` to skip Homebrew installs (note: currently not fully implemented in bootstrap script).

### Installed Packages
The bootstrap script installs the following via Homebrew:
- `git`, `yarn`, `pipx`, `nvm`, `cmake`, `python`
- `bun` (via official installer)
- `uv` (via pipx)

### Submodules
- `.oh-my-zsh` (ohmyzsh)
- `.config/zsh-custom/plugins/zsh-autosuggestions` (zsh-users)

## Syncing App Configurations

Before committing changes, extract the latest app configurations from your system:

```bash
# Extract Cursor configuration
./extract.sh --cursor

# Or use --all (currently only extracts Cursor)
./extract.sh --all
```

This script copies configurations from:
- **Cursor**: Settings, keybindings, profiles (with RTF-to-JSON conversion), and extensions list (including extensions from all profiles)

When you run `./bootstrap.sh`, it will:
1. Install Homebrew (if not already installed)
2. Install packages via Homebrew: `git`, `yarn`, `pipx`, `nvm`, `cmake`, `python`
3. Install `bun` via official installer
4. Install `uv` via pipx
5. Initialize git submodules (oh-my-zsh, zsh-autosuggestions)
6. Install or link oh-my-zsh
7. Symlink shell configs (`.zshrc`, `.zshenv`, `.gitconfig`) to your home directory
8. Copy Cursor configuration files to their proper locations
9. Install all extensions from `extensions.txt` and from all profile `extensions.json` files

## Notes
- The bootstrap script backs up any existing files it replaces into `~/.dotfiles_backup_<timestamp>`.
- It is macOS-focused (Homebrew). On Linux it will still symlink files but skip package installs.
- Cursor configuration is only set up if the application is detected as installed.
- iTerm2 preferences are stored in `iterm2/` directory but must be manually imported:
  - Open iTerm2 → Preferences → General → Settings → Load preferences from a custom folder or URL
  - Point to `~/.dotfiles/iterm2` folder or copy the files manually
