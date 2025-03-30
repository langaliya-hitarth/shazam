#!/usr/bin/env bash
### ---------------------- Install VSCode extensions ---------------------- ###
# CLI: https://code.visualstudio.com/docs/editor/extension-marketplace

check_open_vsx() {
  if ! type curl &>/dev/null || ! (
    type fx || type jq
  ) &>/dev/null; then
    printf "curl and jq or antonmedv/fx required to check extension version.\n"
    return
  fi
  local local_version open_vsx_version response url
  extension_name=$(printf %s "$2" | cut -d @ -f 1)
  local_version=$(printf %s "$2" | cut -d @ -f 2)
  url="https://open-vsx.org/api/$(echo "$extension_name" | tr '.' '/')"
  response=$(curl -fs "$url" -H "accept: application/json")
  if type fx &>/dev/null; then
    open_vsx_version=$(printf %s "$response" | fx .version)
  elif type jq &>/dev/null; then
    open_vsx_version=$(printf %s "$response" | jq -r .version)
  fi
  if [ "$local_version" = "$open_vsx_version" ]; then
    printf "Extension '%s' up-to-date with Open VSX.\n" "$2"
  else
    printf "Updating to %s\n" "$extension_name@$open_vsx_version"
    $1 --install-extension "$extension_name@$open_vsx_version" --force
  fi
}

install_extensions() {
  printf "\nInstalling extensions for %s...\n\n" "$1"
  local extension_info extension_name extensions installed
  extensions="$HOME/.config/shazam/vscode/.extensions"

  installed=("$($1 --list-extensions --show-versions)")
  while read -r extension; do
    # Skip empty lines or comments
    [[ -z "$extension" || "$extension" =~ ^# ]] && continue

    extension_name=$(printf %s "$extension" | cut -d @ -f 1)
    if [ "$extension" = "$extension_name" ]; then
      extension_info=$(printf %s "${installed[@]}" | grep "$extension_name@")
    else
      extension_info=$(printf %s "${installed[@]}" | grep "$extension")
    fi
    if [ -n "$extension_info" ]; then
      printf "Extension '%s' installed.\n" "$extension_info"
      if [ "$1" = "codium" ]; then check_open_vsx "$1" "$extension_info"; fi
    else
      $1 --install-extension "$extension"
    fi
  done <"$extensions"
}

user_settings() {
  printf "\nCopying settings for %s...\n" "$1"
  local custom_settings_file="$HOME/.config/shazam/vscode/settings.json"
  local vscode_settings_dir="$HOME/Library/Application Support/$1/User"

  if [ -d "$vscode_settings_dir" ]; then
    cp -f "$custom_settings_file" "$vscode_settings_dir" &&
      echo_message "Copied settings.json for $1"
  else
    echo_message "$1 settings directory does not exist: $vscode_settings_dir"
  fi
}

if [ -z "$1" ]; then
  printf "\nError: No argument was provided. Please specify ≥1 editor.\n"
  exit 1
fi

for i in "$@"; do
  case $i in
  code) : "Visual Studio Code" ;;
  cursor) : "Cursor" ;;
  code-exploration) : "Visual Studio Code - Exploration" ;;
  code-insiders) : "Visual Studio Code - Insiders" ;;
  codium) : "VSCodium" ;;
  esac
  MACOS_BIN="/Applications/$_.app/Contents/Resources/app/bin"
  if type "$i" &>/dev/null; then
    printf "\n%s command on PATH.\n" "$i"
  elif [ "$(uname -s)" = "Darwin" ] && [ -d "$MACOS_BIN" ]; then
    export PATH="$MACOS_BIN:$PATH"
    printf "\n%s command loaded onto PATH.\n" "$i"
  fi
  if ! type "$i" &>/dev/null; then
    printf "\nError: %s command not on PATH.\n" "$i" >&2
    # TODO: Cursor extension installs not working
    if [ "$i" = "cursor" ]; then
      printf "\nHomebrew Cask should symlink %s to %s.\n" "$MACOS_BIN/code" "$i" >&2
    fi
    exit 1
  elif install_extensions "$i"; then
    user_settings "$_"
    printf "\nSettings updated and extensions successfully installed for %s.\n" "$i"
  else
    printf "\nError: extensions not successfully installed for %s.\n" "$i"
  fi
done
