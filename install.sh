#!/bin/bash

# Store current stderr redirection
exec 3>&2

# Redirect stderr to /dev/null for the entire script
exec 2>/dev/null

#Get project directory
project_dir="$(pwd)"

declare -a packages=("git" "zsh" "wget" "php" "mysql" "node" "nvm" "composer" "lsd" "postgresql@13")
declare -a applications=("google-chrome" "visual-studio-code" "warp" "raycast" "notion" "todoist" "postman" "dbeaver-community" "spotify")
declare -a fonts=("font-jetbrains-mono" "font-meslo-lg-nerd-font")

echo_message() {
    echo -e "\n$1\n"
}

# Check and install Homebrew
if ! command -v brew &>/dev/null; then
    echo_message "Homebrew is not installed. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo_message "Homebrew is already installed."
fi

# Install required packages
for package in "${packages[@]}"; do
    if ! brew list --formula | grep -q "^$package\$"; then
        echo_message "Installing $package..."
        brew install "$package" || { echo "Could not install packages" && exit; }
        echo_message "$package installed."
    else
        echo_message "$package is already installed."
    fi
done

# Install applications
for application in "${applications[@]}"; do
    cask_info=$(brew info --cask "$application" 2>/dev/null)
    application_name=$(echo "$cask_info" | awk '/Artifacts/{getline; sub(/ \(App\)/,""); sub(/^ */,""); print}')
    if [ -z "$application_name" ] && ! brew list --cask "$application" &>/dev/null; then
        brew install --cask "$application"
        [ "$application" = "visual-studio-code" ] && export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
        echo_message "$application_name installed."
    else
        echo_message "$application_name is already installed."
    fi 
done

# Tap cask fonts
if ! brew tap | grep -q "homebrew/cask-fonts"; then
    brew tap homebrew/cask-fonts
fi

# Install fonts
for font in "${fonts[@]}"; do
    if ! brew list --cask | grep -q "^$font\$"; then
        brew install --cask "$font"
    else
        echo_message "$font is already installed."
    fi 
done

# Check MySQL service status
mysql_service_status=$(brew services list | grep mysql | awk '{print $2}')

# Install MySQL
if [ "$mysql_service_status" != "started" ] && command -v mysql &>/dev/null; then
    # Start MySQL service
    brew services start mysql

    # Secure MySQL installation
    echo_message "Securing MySQL installation..."
    # mysql_secure_installation

    echo_message "MySQL setup complete."

    # Ask the user if they want to restore databases
    exec 2>&3 # Restore stderr redirection
    read -r -p "Do you want to restore your databases? (yes/no): " restore_databases
    exec 3>&- # Close file descriptor 3

    if [[ $restore_databases =~ ^[Yy][Ee][Ss]$ ]]; then
        read -r -p "Enter the file path for the database dump: " db_dump_file
        if [ -f "$db_dump_file" ]; then
            mysql -u root -p < "$db_dump_file"
            echo_message "Database restored successfully."
        else
            echo_message "Error: File not found at $db_dump_file"
        fi
    fi
fi

# Backup original .zshrc file
backup_dir="$HOME/.config/shazam/backup"
mkdir -p "$backup_dir"
if mv -n ~/.zshrc "$backup_dir/.$(date +"%Y%m%d")-zshrc-backup"; then
    echo_message "Backed up the current .zshrc to $backup_dir."
fi

echo_message "The setup will be installed in '~/.config/shazam'."

echo_message "Installing oh-my-zsh."
if [ -d ~/.config/shazam/oh-my-zsh ]; then
    echo_message "oh-my-zsh is already installed."
    git -C ~/.config/shazam/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
elif [ -d ~/.oh-my-zsh ]; then
    echo_message "oh-my-zsh is already installed at '~/.oh-my-zsh'. Moving it to '~/.config/shazam/oh-my-zsh'."
    export ZSH="$HOME/.config/shazam/oh-my-zsh"
    mv ~/.oh-my-zsh ~/.config/shazam/oh-my-zsh
    git -C ~/.config/shazam/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
else
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.config/shazam/oh-my-zsh
fi

# Create ~/.nvm directory if nvm is installed but the directory does not exist
if command -v nvm &>/dev/null && [ ! -d "$HOME/.nvm" ]; then
    mkdir -p "$HOME/.nvm"
fi

# Copy configuration files
cp -f config/.aliases config/.shazam config/.p10k.zsh ~/.config/shazam/
cp -f config/.zshrc ~/

# Move .zcompdump files
mkdir -p ~/.cache/zsh/
[ -f ~/.zcompdump* ] && mv ~/.zcompdump* ~/.cache/zsh/

# Update or clone git repositories
update_or_clone_repository() {
    local repo_path="$1"
    local repo_url="$2"
    local repo_name=$(basename "$repo_path")

    if [ -d "$repo_path" ]; then
        echo_message "Updating $repo_name..."
        cd "$repo_path" && git pull -q
    else
        echo_message "Cloning $repo_name..."
        git clone --depth=1 "$repo_url" "$repo_path"
    fi
}

update_or_clone_repository "$HOME/.config/shazam/oh-my-zsh/plugins/zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
update_or_clone_repository "$HOME/.config/shazam/oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
update_or_clone_repository "$HOME/.config/shazam/oh-my-zsh/custom/plugins/zsh-completions" "https://github.com/zsh-users/zsh-completions"
update_or_clone_repository "$HOME/.config/shazam/oh-my-zsh/custom/plugins/zsh-history-substring-search" "https://github.com/zsh-users/zsh-history-substring-search"
update_or_clone_repository "$HOME/.config/shazam/oh-my-zsh/custom/themes/powerlevel10k" "https://github.com/romkatv/powerlevel10k.git"

echo_message "All plugins and themes are up to date!"

# Install VS Code extensions
extensions_file="$project_dir/vscode/.extensions"

extension_installed() {
    local extension="$1"
    code --list-extensions | grep -q "$1" && return 0 || return 1
}

while IFS= read -r extension || [[ -n "$extension" ]]; do
    if ! extension_installed "$extension"; then
        echo_message "Installing extension: $extension"
        code --install-extension "$extension"
    else
        echo_message "$extension already installed"
    fi
done < "$extensions_file"

# Copy custom VS Code settings
custom_settings_file="$project_dir/vscode/settings.json"
vscode_settings_dir="$HOME/Library/Application Support/Code/User"
if [ -d "$vscode_settings_dir" ]; then
    cp -f "$custom_settings_file" "$vscode_settings_dir"
    echo_message "Copied VS Code settings.json"
fi

# Update oh-my-zsh
if /bin/zsh -c 'source ~/.zshrc && omz update'; then
    echo_message "\nInstallation Complete!"
else
    echo_message "\nSomething went wrong."
fi

exit
