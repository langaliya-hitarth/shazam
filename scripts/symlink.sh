#!/usr/bin/env bash
set -euo pipefail # Enable strict error handling

# Constants
readonly HOME_DIR="$HOME"
readonly DOT_DIR="$HOME_DIR/.config/shazam2"
readonly VSCODE_DOT_DIR="$DOT_DIR/vscode"

# Array of files/directories to ignore when symlinking
readonly IGNORE_PATTERNS=(
  ".DS_Store"
  ".git"
  ".gitattributes"
  ".github"
  ".gitignore"
)

symlink_dir_contents() {
  local target_dir="$3/${1##"$2"/}"
  mkdir -p "$target_dir"
  local file
  find "$1" -maxdepth 1 -mindepth 1 -print0 | while IFS= read -r -d '' file; do
    symlink_file "$file" "$2" "$3"
  done
}

symlink_file() {
  ln -nsfF "$1" "$3/${1##"$2"/}"
}

symlink_repo_dotfiles() {
  echo "-> Symlinking dotfiles into Shazam's directory."

  local dotfile
  for dotfile in "$DOT_DIR"/.*; do
    [[ -e "$dotfile" ]] || continue # Skip if file doesn't exist

    # Skip ignored patterns
    local should_ignore=false
    for pattern in "${IGNORE_PATTERNS[@]}"; do
      if [[ "$dotfile" == *"$pattern" ]]; then
        should_ignore=true
        break
      fi
    done

    "$should_ignore" && continue

    if [[ -d "$dotfile" ]]; then
      symlink_dir_contents "$dotfile" "$DOT_DIR" "$HOME_DIR"
    elif [[ -f "$dotfile" ]]; then
      symlink_file "$dotfile" "$DOT_DIR" "$HOME_DIR"
    fi
  done

  ln -nsfF "$DOT_DIR/Brewfile" "$HOME_DIR/.Brewfile"
}

symlink_vscode_settings() {
  echo "-> Symlinking VSCode settings."

  local vscode_base_dir
  case "$(uname -s)" in
  Darwin) vscode_base_dir="$HOME_DIR/Library/Application Support" ;;
  Linux) vscode_base_dir="$HOME_DIR/.config" ;;
  *) echo "-> Error: symlink.sh only supports macOS and Linux." && return 1 ;;
  esac

  local -a editor_dirs=(
    "Code"
    "Cursor"
    "Code - Exploration"
    "Code - Insiders"
    "VSCodium"
  )

  local dir
  for dir in "${editor_dirs[@]}"; do
    local full_path="$vscode_base_dir/$dir"
    [[ -d "$full_path" ]] && symlink_dir_contents "$VSCODE_DOT_DIR/User" "$VSCODE_DOT_DIR" "$full_path"
  done
}

backup_and_symlink_zshrc() {
  echo "-> Backing up and symlinking .zshrc file"

  # Create backups directory if it doesn't exist
  local backup_dir="$DOT_DIR/backups"
  mkdir -p "$backup_dir"

  # Generate timestamp for backup file
  local timestamp=$(date '+%Y%m%d%H%M%S')
  local backup_file="$backup_dir/.zshrc-backup-$timestamp"

  # Backup existing .zshrc if it exists and is not a symlink
  if [[ -f "$HOME_DIR/.zshrc" && ! -L "$HOME_DIR/.zshrc" ]]; then
    cp "$HOME_DIR/.zshrc" "$backup_file"
    echo "-> Backed up existing .zshrc to $backup_file"
  fi

  # Symlink .zshrc
  ln -nsfF "$DOT_DIR/.zshrc" "$HOME_DIR/.zshrc"
  echo "-> Symlinked .zshrc file"
}

main() {
  if [[ ! -d "$DOT_DIR" ]]; then
    echo "-> Error: Shazam's directory not found at $DOT_DIR"
    return 1
  fi

  if symlink_repo_dotfiles && symlink_vscode_settings && backup_and_symlink_zshrc; then
    echo "-> Symlinking successful. Finishing up..."
    return 0
  else
    echo "-> Symlinking unsuccessful."
    return 1
  fi
}

main "$@"
