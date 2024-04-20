#!/bin/bash

# Redirect stderr to /dev/null for the entire script
exec 2>/dev/null

# Get Project Directory
project_dir="$(pwd)"

declare -a packages=("git" "zsh" "wget" "php" "mysql" "node" "nvm" "composer" "lsd" "postgresql@13")
declare -a applications=("google-chrome" "visual-studio-code" "warp" "raycast" "notion" "todoist" "postman" "dbeaver-community" "spotify")
declare -a fonts=("font-jetbrains-mono" "font-meslo-lg-nerd-font")

if ! command -v brew &> /dev/null; then
    echo -e "Homebrew is not installed. Installing...\n"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo -e "Homebrew is already installed.\n"
fi

for package in "${packages[@]}"; do
    if command -v "$package" &> /dev/null; then
        echo -e "$package is already installed \n"
    else
        echo -e "Installing $package...\n"
        brew install "$package" || { echo "Could not install packages" && exit; }
        echo -e "$package Installed\n"
    fi
done

for application in "${applications[@]}"; do
    # Get cask info
    cask_info=$(brew info --cask "$application" 2>/dev/null)

    # Extract the application name from the cask info
    application_name=$(echo "$cask_info" | awk '/Artifacts/{getline; sub(/ \(App\)/,""); sub(/^ */,""); print}')
    if [ -n "$application_name" ]; then
        echo -e "Found $application_name in Applications folder, skipping installation.\n"
    else
        if brew list --cask "$cask_name" &>/dev/null; then
            echo -e "$application_name is already installed \n"
        else
            brew install --cask "$application"
            [ "$application" = "visual-studio-code" ] && export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
            echo -e "$application_name installed\n"
        fi
    fi 
done

if brew tap | grep -q "homebrew/cask-fonts"; then
    echo -e "homebrew/cask-fonts is already tapped \n"
else
    brew tap homebrew/cask-fonts
fi

for font in "${fonts[@]}"; do
    if brew list --cask | grep -q "^$font\$"; then
        echo -e "$font is already installed \n"
    else
        brew install --cask "$font"
    fi 
done

# Backup original .zshrc file in the ~/.config/shazam/backup directory
mkdir -p ~/.config/shazam/backup
if mv -n ~/.zshrc ~/.config/shazam/backup/.$(date +"%Y%m%d")-zshrc-backup; then
    echo -e "Backed up the current .zshrc to ~/.config/shazam/backup/.$(date +"%Y%m%d")-zshrc-backup \n"
fi

echo -e "The setup will be installed in '~/.config/shazam' \n"

echo -e "Installing oh-my-zsh\n"
if [ -d ~/.config/shazam/oh-my-zsh ]; then
    echo -e "oh-my-zsh is already installed \n"
    git -C ~/.config/shazam/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
elif [ -d ~/.oh-my-zsh ]; then
    echo -e "oh-my-zsh in already installed at '~/.oh-my-zsh'. Moving it to '~/.config/shazam/oh-my-zsh' \n"
    export ZSH="$HOME/.config/shazam/oh-my-zsh"
    mv ~/.oh-my-zsh ~/.config/shazam/oh-my-zsh
    git -C ~/.config/shazam/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
else
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.config/shazam/oh-my-zsh
fi

cp -f config/.aliases ~/.config/shazam/
cp -f config/.shazam ~/.config/shazam/
cp -f config/.p10k.zsh ~/.config/shazam/
cp -f config/.zshrc ~/

# this will be used to store .zcompdump zsh completion cache files which normally clutter $HOME
mkdir -p ~/.cache/zsh/

if [ -f ~/.zcompdump* ]; then
    mv ~/.zcompdump* ~/.cache/zsh/
fi

# Function to update or clone a git repository
update_or_clone_repository() {
    local repo_path="$1"
    local repo_url="$2"
    local repo_name=$(basename "$repo_path")

    if [ -d "$repo_path" ]; then
        echo -e "Updating $repo_name...\n"
        cd "$repo_path" && git pull -q
    else
        echo -e "Cloning $repo_name...\n"
        git clone --depth=1 "$repo_url" "$repo_path"
    fi
}

# Update or clone zsh-autosuggestions plugin
update_or_clone_repository "$HOME/.config/shazam/oh-my-zsh/plugins/zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"

# Update or clone zsh-syntax-highlighting plugin
update_or_clone_repository "$HOME/.config/shazam/oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"

# Update or clone zsh-completions plugin
update_or_clone_repository "$HOME/.config/shazam/oh-my-zsh/custom/plugins/zsh-completions" "https://github.com/zsh-users/zsh-completions"

# Update or clone zsh-history-substring-search plugin
update_or_clone_repository "$HOME/.config/shazam/oh-my-zsh/custom/plugins/zsh-history-substring-search" "https://github.com/zsh-users/zsh-history-substring-search"

# Update or clone powerlevel10k theme
update_or_clone_repository "$HOME/.config/shazam/oh-my-zsh/custom/themes/powerlevel10k" "https://github.com/romkatv/powerlevel10k.git"

echo -e "All plugins and themes are up to date!\n"

# Get extensions file
extensions_file="$project_dir/vscode/.extensions"

# Function to check if an extension is installed
extension_installed() {
    local extension="$1"
    code --list-extensions | grep -q "$1" && return 0 || return 1
}

# Install extensions listed in the extensions file
while IFS= read -r extension || [[ -n "$extension" ]]; do
    if extension_installed "$extension"; then
        echo -e "Extension '$extension' is already installed. \n"
    else
        echo -e "Installing extension: $extension"
        code --install-extension "$extension"
    fi
done < "$extensions_file"

# Path to custom settings.json file
custom_settings_file="$project_dir/vscode/settings.json"

# Path to VS Code settings directory
vscode_settings_dir="$HOME/Library/Application Support/Code/User"

# Check if VS Code settings directory exists and copy settings if it does
if [ ! -d "$vscode_settings_dir" ]; then
    echo -e "Error: VS Code settings directory does not exist: $vscode_settings_dir \n"
else
    cp "$custom_settings_file" "$vscode_settings_dir/settings.json"
    echo -e "Copied VS Code settings.json \n"
fi

# Update oh-my-zsh using Zsh
if /bin/zsh -c 'source ~/.zshrc && omz update'; then
    echo -e "\nInstallation Complete!"
else
    echo -e "\nSomething is wrong"
fi

exit