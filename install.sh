#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Set the default Homebrew prefix based on the architecture
if [[ $(uname -m) == "arm64" ]]; then
    DEFAULT_HOMEBREW_PREFIX="/opt/homebrew"
else
    DEFAULT_HOMEBREW_PREFIX="/usr/local"
fi
[[ -z $HOMEBREW_PREFIX ]] && HOMEBREW_PREFIX="$DEFAULT_HOMEBREW_PREFIX"

[ "$USER" = "root" ] && abort "Please run this script as yourself, not as a root user."

SHAZAM_ADMIN=${SHAZAM_ADMIN:-0}
if groups | grep -qE "\b(admin)\b"; then SHAZAM_ADMIN=1; else SHAZAM_ADMIN=0; fi
export SHAZAM_ADMIN
SHAZAM_CI=${SHAZAM_CI:=0}
SHAZAM_DEBUG=${SHAZAM_DEBUG:-0}
[[ $1 = "--debug" || -o xtrace ]] && SHAZAM_DEBUG=1
SHAZAM_INTERACTIVE=${SHAZAM_INTERACTIVE:-0}
STDIN_FILE_DESCRIPTOR=0
[ -t "$STDIN_FILE_DESCRIPTOR" ] && SHAZAM_INTERACTIVE=1
SHAZAM_GIT_NAME=${SHAZAM_GIT_NAME:?Variable not set}
SHAZAM_GIT_EMAIL=${SHAZAM_GIT_EMAIL:?Variable not set}
SHAZAM_GITHUB_USER=${SHAZAM_GITHUB_USER:="langaliya-hitarth"}
SHAZAM_REPO_URL="https://github.com/$SHAZAM_GITHUB_USER/dotfiles"
SHAZAM_URL=${SHAZAM_URL:="$SHAZAM_REPO_URL"}
SHAZAM_BRANCH=${SHAZAM_BRANCH:="main"}
SHAZAM_SUCCESS=""
SHAZAM_SUDO=0

sudo_askpass() {
    if [ -n "$SUDO_ASKPASS" ]; then
        sudo --askpass "$@"
    else
        sudo "$@"
    fi
}

cleanup() {
    set +e
    if [ -n "$SUDO_ASKPASS" ]; then
        sudo_askpass rm -rf "$CLT_PLACEHOLDER" "$SUDO_ASKPASS" "$SUDO_ASKPASS_DIR"
        sudo --reset-timestamp
    fi
    if [ -z "$SHAZAM_SUCCESS" ]; then
        if [ -n "$SHAZAM_STEP" ]; then
            echo "!!! $SHAZAM_STEP FAILED" >&2
        else
            echo "!!! FAILED" >&2
        fi
        if [ "$SHAZAM_DEBUG" -eq 0 ]; then
            echo "!!! Run '$0 --debug' for debugging output." >&2
        fi
    fi
}
trap "cleanup" EXIT

if [ "$SHAZAM_DEBUG" -gt 0 ]; then
    set -x
else
    SHAZAM_QUIET_FLAG="-q"
    Q="$SHAZAM_QUIET_FLAG"
fi

clear_debug() {
    set +x
}

reset_debug() {
    if [ "$SHAZAM_DEBUG" -gt 0 ]; then
        set -x
    fi
}

abort() {
    SHAZAM_STEP=""
    echo "!!! $*" >&2
    exit 1
}

escape() {
    printf '%s' "${1//\'/\'}"
}

log_no_sudo() {
    SHAZAM_STEP="$*"
    echo "--> $*"
}

logk() {
    SHAZAM_STEP=""
    echo "OK"
}

logn_no_sudo() {
    SHAZAM_STEP="$*"
    printf -- "--> %s " "$*"
}

logskip() {
    SHAZAM_STEP=""
    echo "SKIPPED"
    echo "$*"
}

sudo_init() {
    if [ "$SHAZAM_INTERACTIVE" -eq 0 ]; then
        sudo -n -l mkdir &>/dev/null && export SHAZAM_SUDO=1
        return
    fi
    local SUDO_PASSWORD SUDO_PASSWORD_SCRIPT
    if ! sudo --validate --non-interactive &>/dev/null; then
        while true; do
            read -rsp "--> Enter your password (for sudo access):" SUDO_PASSWORD
            echo
            if sudo --validate --stdin 2>/dev/null <<<"$SUDO_PASSWORD"; then
                break
            fi
            unset SUDO_PASSWORD
            echo "!!! Wrong password!" >&2
        done
        clear_debug
        SUDO_PASSWORD_SCRIPT="$(
            cat <<-BASH
				#!/usr/bin/env bash
				echo "$SUDO_PASSWORD"
				BASH
        )"
        unset SUDO_PASSWORD
        SUDO_ASKPASS_DIR="$(mktemp -d)"
        SUDO_ASKPASS="$(mktemp "$SUDO_ASKPASS_DIR"/strap-askpass-XXXXXXXX)"
        chmod 700 "$SUDO_ASKPASS_DIR" "$SUDO_ASKPASS"
        bash -c "cat > '$SUDO_ASKPASS'" <<<"$SUDO_PASSWORD_SCRIPT"
        unset SUDO_PASSWORD_SCRIPT
        SHAZAM_SUDO=1
        reset_debug
        export SHAZAM_SUDO SUDO_ASKPASS
    fi
    echo "SHAZAM_SUDO=$SHAZAM_SUDO"
}

sudo_refresh() {
    clear_debug
    if [ -n "$SUDO_ASKPASS" ]; then
        sudo --askpass --validate
    else
        sudo_init
    fi
    reset_debug
}

log() {
    SHAZAM_STEP="$*"
    sudo_refresh
    echo "--> $*"
}

logn() {
    SHAZAM_STEP="$*"
    sudo_refresh
    printf -- "--> %s " "$*"
}

# Given a list of scripts in the dotfiles repo, run the first one that exists
run_dotfile_scripts() {
    if [ -d "$HOME/.config/shazam" ]; then
        (
            cd "$HOME/.config/shazam"
            for i in "$@"; do
                if [ -f "$i" ] && [ -x "$i" ]; then
                    log_no_sudo "Running dotfiles script $i:"
                    if [ "$SHAZAM_DEBUG" -eq 0 ]; then
                        "$i" 2>/dev/null
                    else
                        "$i"
                    fi
                    break
                fi
            done
        )
    fi
}

# Set up Xcode Command Line Tools
install_xcode_clt() {
    if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
        log "Installing the Xcode Command Line Tools:"
        CLT_STRING=".com.apple.dt.CommandLineTools.installondemand.in-progress"
        CLT_PLACEHOLDER="/tmp/$CLT_STRING"
        sudo_askpass touch "$CLT_PLACEHOLDER"
        CLT_PACKAGE=$(softwareupdate -l |
            grep -B 1 "Command Line Tools" |
            awk -F"*" '/^ *\*/ {print $2}' |
            sed -e 's/^ *Label: //' -e 's/^ *//' |
            sort -V |
            tail -n1)
        sudo_askpass softwareupdate -i "$CLT_PACKAGE"
        sudo_askpass rm -f "$CLT_PLACEHOLDER"
        if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
            if [ "$SHAZAM_INTERACTIVE" -gt 0 ]; then
                echo
                logn "Requesting user install of Xcode Command Line Tools:"
                xcode-select --install
            else
                echo
                abort "Install Xcode Command Line Tools with 'xcode-select --install'."
            fi
        fi
        logk
    fi
}

# shellcheck disable=SC2086
check_xcode_license() {
    if /usr/bin/xcrun clang 2>&1 | grep $Q license; then
        if [ "$SHAZAM_INTERACTIVE" -gt 0 ]; then
            logn "Asking for Xcode license confirmation:"
            sudo_askpass xcodebuild -license
            logk
        else
            abort "Run 'sudo xcodebuild -license' to agree to the Xcode license."
        fi
    fi
}

check_software_updates() {
    logn "Checking for software updates:"
    # shellcheck disable=SC2086
    if softwareupdate -l 2>&1 | grep $Q "No new software available."; then
        logk
    else
        if [ "$MACOS" -gt 0 ] && [ "$SHAZAM_CI" -eq 0 ]; then
            echo
            log "Installing software updates:"
            sudo_askpass softwareupdate --install --all
            check_xcode_license
        else
            logskip "Skipping software updates."
        fi
        logk
    fi
}

if [ "$MACOS" -gt 0 ] && [ "$SHAZAM_ADMIN" -gt 0 ]; then
    install_xcode_clt
    check_xcode_license
    check_software_updates
else
    logskip "Xcode Command-Line Tools install and license check skipped."
fi

configure_git() {
    logn_no_sudo "Configuring Git:"
    # These calls to `git config` are needed for CI use cases in which certain
    # aspects of the `.gitconfig` cannot be used (like signing commits with SSH).
    # Permission denied errors may occur when Git attempts to read
    # [`$XDG_CONFIG_HOME/git/attributes`](https://git-scm.com/docs/gitattributes)
    # or [`$XDG_CONFIG_HOME/git/ignore`](https://git-scm.com/docs/gitignore).
    # These files may be located in `/home/runner/.config` on GitHub Actions
    # runners and inaccessible if a non-root user is running this script.
    if [ "$SHAZAM_CI" -gt 0 ]; then
        export XDG_CONFIG_HOME="$HOME/.config"
        mkdir -p "$XDG_CONFIG_HOME" && chmod -R 775 "$XDG_CONFIG_HOME"
        if ! git config --global core.attributesfile >/dev/null; then
            touch "$XDG_CONFIG_HOME/.gitattributes"
            git config --global core.attributesfile "$XDG_CONFIG_HOME/.gitattributes"
        fi
        if ! git config --global core.excludesfile >/dev/null; then
            touch "$XDG_CONFIG_HOME/.gitignore_global"
            git config --global core.excludesfile "$XDG_CONFIG_HOME/.gitignore_global"
        fi
    fi
    if [ -n "$SHAZAM_GIT_NAME" ] && ! git config --global user.name >/dev/null; then
        git config --global user.name "$SHAZAM_GIT_NAME"
    fi
    if [ -n "$SHAZAM_GIT_EMAIL" ] && ! git config --global user.email >/dev/null; then
        git config --global user.email "$SHAZAM_GIT_EMAIL"
    fi
    if [ -n "$SHAZAM_GITHUB_USER" ] &&
        [ "$(git config --global github.user)" != "$SHAZAM_GITHUB_USER" ]; then
        git config --global github.user "$SHAZAM_GITHUB_USER"
    fi

    # Set up GitHub HTTPS credentials
    # shellcheck disable=SC2086
    if [ -n "$SHAZAM_GITHUB_USER" ] && [ -n "$SHAZAM_GITHUB_TOKEN" ]; then
        PROTOCOL="protocol=https\\nhost=github.com"
        printf "%s\\n" "$PROTOCOL" | git credential reject
        printf "%s\\nusername=%s\\npassword=%s\\n" \
            "$PROTOCOL" "$SHAZAM_GITHUB_USER" "$SHAZAM_GITHUB_TOKEN" |
            git credential approve
    else
        logskip "Skipping Git credential setup."
    fi
    logk
}

# The first call to `configure_git` is needed for cloning the dotfiles repo.
configure_git

# Set up dotfiles
# shellcheck disable=SC2086
if [ ! -d "$HOME/.config/shazam" ]; then
    if [ -z "$SHAZAM_URL" ] || [ -z "$SHAZAM_BRANCH" ]; then
        abort "Please set SHAZAM_URL and SHAZAM_BRANCH."
    fi
    log_no_sudo "Cloning $SHAZAM_URL to $HOME/.config/shazam."
    git clone $Q "$SHAZAM_URL" "$HOME/.config/shazam"
fi
shazam_branch_name="${SHAZAM_BRANCH##*/}"
log_no_sudo "Checking out $shazam_branch_name in $HOME/.config/shazam."
# shellcheck disable=SC2086
(
    cd "$HOME/.config/shazam"
    git stash
    git fetch $Q
    git checkout "$shazam_branch_name"
    git pull $Q --rebase --autostash
)
run_dotfile_scripts scripts/symlink.sh
# The second call to `configure_git` is needed for CI use cases in which some
# aspects of the `.gitconfig` cannot be used after cloning the dotfiles repo.
configure_git
logk

install_homebrew() {
    logn "Installing Homebrew:"
    HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
    [ -n "$HOMEBREW_PREFIX" ] || HOMEBREW_PREFIX="$DEFAULT_HOMEBREW_PREFIX"
    [ -d "$HOMEBREW_PREFIX" ] || sudo_askpass mkdir -p "$HOMEBREW_PREFIX"
    sudo_askpass chown -R "root:wheel" "$HOMEBREW_PREFIX" 2>/dev/null || true
    (
        cd "$HOMEBREW_PREFIX"
        sudo_askpass mkdir -p \
            Cellar Caskroom Frameworks bin etc include lib opt sbin share var
        sudo_askpass chown "$USER:admin" \
            Cellar Caskroom Frameworks bin etc include lib opt sbin share var
    )
    HOMEBREW_REPOSITORY="$(brew --repository 2>/dev/null || true)"
    [ -n "$HOMEBREW_REPOSITORY" ] || HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX/Homebrew"
    [ -d "$HOMEBREW_REPOSITORY" ] || sudo_askpass mkdir -p "$HOMEBREW_REPOSITORY"
    sudo_askpass chown -R "root:wheel" "$HOMEBREW_REPOSITORY" 2>/dev/null || true
    if [ "$HOMEBREW_PREFIX" != "$HOMEBREW_REPOSITORY" ]; then
        ln -sf "$HOMEBREW_REPOSITORY/bin/brew" "$HOMEBREW_PREFIX/bin/brew"
    fi
    export GIT_DIR="$HOMEBREW_REPOSITORY/.git" GIT_WORK_TREE="$HOMEBREW_REPOSITORY"
    git init $Q
    git config remote.origin.url "https://github.com/Homebrew/brew"
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git fetch $Q --tags --force
    git reset $Q --hard origin/HEAD
    unset GIT_DIR GIT_WORK_TREE
    logk
    export PATH="$HOMEBREW_PREFIX/bin:$PATH"
    logn "Updating Homebrew:"
    brew update
    logk
}

set_up_brew_skips() {
    local brewfile_path casks ci_skips mas_ids mas_prefix
    log_no_sudo "Setting up Homebrew Bundle formula installs to skip."
    ci_skips="awscli black jupyterlab mkvtoolnix zsh-completions"
    [ "$SHAZAM_CI" -gt 0 ] && HOMEBREW_BUNDLE_BREW_SKIP="$ci_skips"
    if [ -f "$HOME/.Brewfile" ]; then
        brewfile_path="$HOME/.Brewfile"
    elif [ -f "Brewfile" ]; then
        brewfile_path="Brewfile"
    else
        abort "No Brewfile found"
    fi
    log_no_sudo "Setting up Homebrew Bundle cask installs to skip."
    if [ "$MACOS" -gt 0 ] && [ "$brewfile_path" == "$HOME/.Brewfile" ]; then
        casks="$(brew bundle list --global --cask --quiet | tr '\n' ' ')"
    elif [ "$MACOS" -gt 0 ] && [ "$brewfile_path" == "Brewfile" ]; then
        casks="$(brew bundle list --cask --quiet | tr '\n' ' ')"
    else
        log_no_sudo "Cask commands are only supported on macOS."
    fi
    HOMEBREW_BUNDLE_CASK_SKIP="${casks%% }"
    log_no_sudo "Setting up Homebrew Bundle Mac App Store (mas) installs to skip."
    mas_ids=""
    mas_prefix='*mas*, id: '
    while read -r brewfile_line; do
        # shellcheck disable=SC2295
        [[ $brewfile_line == *$mas_prefix* ]] && mas_ids+="${brewfile_line##$mas_prefix} "
    done <"$brewfile_path"
    HOMEBREW_BUNDLE_MAS_SKIP="${mas_ids%% }"
    log_no_sudo "HOMEBREW_BUNDLE_BREW_SKIP='$HOMEBREW_BUNDLE_BREW_SKIP'"
    log_no_sudo "HOMEBREW_BUNDLE_CASK_SKIP='$HOMEBREW_BUNDLE_CASK_SKIP'"
    log_no_sudo "HOMEBREW_BUNDLE_MAS_SKIP='$HOMEBREW_BUNDLE_MAS_SKIP'"
    export HOMEBREW_BUNDLE_BREW_SKIP="$HOMEBREW_BUNDLE_BREW_SKIP"
    export HOMEBREW_BUNDLE_CASK_SKIP="$HOMEBREW_BUNDLE_CASK_SKIP"
    export HOMEBREW_BUNDLE_MAS_SKIP="$HOMEBREW_BUNDLE_MAS_SKIP"
}

run_brew_installs() {
    local brewfile_domain brewfile_path brewfile_url git_branch github_user
    if ! type brew &>/dev/null; then
        log "brew command not in shell environment. Attempting to load."
        eval "$("$HOMEBREW_PREFIX"/bin/brew shellenv)"
        type brew &>/dev/null && logk || return 1
    fi
    # Disable Homebrew Analytics: https://docs.brew.sh/Analytics
    brew analytics off
    [ "$SHAZAM_CI" -gt 0 ] || [ "$LINUX" -gt 0 ] && set_up_brew_skips
    [ "$LINUX" -gt 0 ] && brew install gcc # "We recommend that you install GCC"
    log "Running Homebrew installs."
    if [ -f "$HOME/.Brewfile" ]; then
        log "Installing from $HOME/.Brewfile with Brew Bundle."
        brew bundle check --global || brew bundle --global
        logk
    elif [ -f "Brewfile" ]; then
        log "Installing from local Brewfile with Brew Bundle."
        brew bundle check || brew bundle
        logk
    else
        [ -z "$SHAZAM_DOTFILES_BRANCH" ] && SHAZAM_DOTFILES_BRANCH=HEAD
        git_branch="${SHAZAM_DOTFILES_BRANCH##*/}"
        github_user="${SHAZAM_GITHUB_USER:-br3ndonland}"
        brewfile_domain="https://raw.githubusercontent.com"
        brewfile_path="$github_user/dotfiles/$git_branch/Brewfile"
        brewfile_url="$brewfile_domain/$brewfile_path"
        log "Installing from $brewfile_url with Brew Bundle."
        curl -fsSL "$brewfile_url" | brew bundle --file=-
        logk
    fi
    # Tap a custom Homebrew tap
    if [ -n "$CUSTOM_HOMEBREW_TAP" ]; then
        read -ra CUSTOM_HOMEBREW_TAP <<<"$CUSTOM_HOMEBREW_TAP"
        log "Running 'brew tap ${CUSTOM_HOMEBREW_TAP[*]}':"
        brew tap "${CUSTOM_HOMEBREW_TAP[@]}"
        logk
    fi
    # Run a custom Brew command
    if [ -n "$CUSTOM_BREW_COMMAND" ]; then
        log "Executing 'brew $CUSTOM_BREW_COMMAND':"
        # shellcheck disable=SC2086
        brew $CUSTOM_BREW_COMMAND
        logk
    fi
}

# Install Homebrew
# https://docs.brew.sh/Installation
# https://docs.brew.sh/Homebrew-on-Linux
# Homebrew installs require `sudo`, but not necessarily admin
# https://docs.brew.sh/FAQ#why-does-homebrew-say-sudo-is-bad
# https://github.com/Homebrew/install/issues/312
# https://github.com/Homebrew/install/pull/315/files
if [ "$SHAZAM_SUDO" -eq 0 ]; then
    sudo_init || logskip "Skipping Homebrew installation (requires sudo)."
fi
if [ "$SHAZAM_SUDO" -gt 0 ]; then
    # Prevent "Permission denied" errors on Homebrew directories
    log "Updating permissions on Homebrew directories"
    sudo_askpass mkdir -p "$HOMEBREW_PREFIX/"{Caskroom,Cellar,Frameworks}
    sudo_askpass chmod -R 775 "$HOMEBREW_PREFIX/"{Caskroom,Cellar,Frameworks}
    sudo_askpass chown -R "$USER" "$HOMEBREW_PREFIX" 2>/dev/null || true
    logk
    if [ "$MACOS" -gt 0 ]; then
        log "Installing Homebrew on macOS"
        script_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
        NONINTERACTIVE=$SHAZAM_CI \
            /usr/bin/env bash -c "$(curl -fsSL $script_url)" || install_homebrew
        logk
    elif [ "$LINUX" -gt 0 ]; then
        # https://docs.brew.sh/Homebrew-on-Linux
        log "Installing Homebrew on Linux"
        run_dotfile_scripts scripts/linuxbrew.sh
        logk
    else
        abort "Unsupported operating system $OS"
    fi
    run_brew_installs || abort "Homebrew installs were not successful."
    brew cleanup
fi

### Configure macOS
if [ "${MACOS:-0}" -gt 0 ] || [ "$(uname)" = "Darwin" ]; then
    if [ "$SHAZAM_ADMIN" -gt 0 ]; then
        "$HOME"/.config/shazam/scripts/macSettings.sh
    else
        echo "Not admin. Skipping macos.sh. Set \$SHAZAM_ADMIN to run macos.sh."
    fi
fi

### Install VSCode extensions
# TODO: Cursor extension installs not working
for i in {code,code-exploration,code-insiders,code-server,codium}; do
    "$HOME"/.config/shazam/scripts/vscode.sh "$i"
done

#Get project directory
# echo_message "The setup will be installed in '~/.config/shazam'."
# project_dir="$(pwd)"
# SHAZAM="$HOME/.config/shazam"

# echo_message() {
#     BOLD='\033[1;90m'
#     PURPLE='\033[0;34m' # Oh-My-Zsh color
#     NC='\033[0m'        # No Color

#     echo -e "${BOLD}${PURPLE}\n$1${NC}\n"
# }

# # Backup original .zshrc file
# echo_message "Backing up the current .zshrc file..."
# backup_dir="$SHAZAM/backup"
# mkdir -p "$backup_dir"
# if mv -n ~/.zshrc "$backup_dir/.$(date +"%Y%m%d")-zshrc-backup"; then
#     echo_message "Backed up the current .zshrc to $backup_dir."
# fi

# # Copy configuration files
# echo_message "Copying configuration files..."
# cp -f config/.zshrc ~/
# cp -f -r config/.aliases config/.shazam config/.ghostty config/.oh-my-posh ~/.config/shazam/

# # Check and install Homebrew
# if ! command -v brew &>/dev/null; then
#     echo_message "Homebrew is not installed. Installing..."
#     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#     eval "$(/opt/homebrew/bin/brew shellenv)"
# else
#     echo_message "Homebrew is already installed."
# fi

# # Read packages from Brewfile
# echo_message "Installing packages from Brewfile..."
# brewfile="./Brewfile"
# if [ -f "$brewfile" ]; then
#     # Extract brew packages from Brewfile, ignoring comments and empty lines
#     brew bundle install --file="$brewfile"
# else
#     echo_message "Error: Brewfile not found at $brewfile"
#     exit 1
# fi

# # Install nvm
# # Create ~/.nvm directory if nvm is installed but the directory does not exist
# echo_message "Installing nvm..."
# export NVM_DIR="$SHAZAM/.nvm" && (
#     git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
#     cd "$NVM_DIR"
#     git checkout $(git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1))
# ) && \. "$NVM_DIR/nvm.sh"

# echo_message "Installing node..."
# nvm install --lts

# # Read npm packages from .npm file
# npm_file="../brew/.npm"
# if [ -f "$npm_file" ]; then
#     # Read npm packages into array, ignoring empty lines and comments
#     mapfile -t npm_packages < <(grep -v '^#' "$npm_file" | grep -v '^$')
# else
#     echo_message "Error: NPM packages file not found at $npm_file"
#     exit 1
# fi

# # Check MySQL service status
# mysql_service_status=$(brew services list | grep mysql | awk '{print $2}')

# # Install MySQL
# if [ "$mysql_service_status" != "started" ] && command -v mysql &>/dev/null; then
#     # Start MySQL service
#     brew services start mysql

#     # Secure MySQL installation
#     echo_message "Securing MySQL installation..."
#     # mysql_secure_installation

#     echo_message "MySQL setup complete."

#     # Ask the user if they want to restore databases
#     exec 2>&3 # Restore stderr redirection
#     read -r -p "Do you want to restore your databases? (yes/no): " restore_databases
#     exec 3>&- # Close file descriptor 3

#     if [[ $restore_databases =~ ^[Yy][Ee][Ss]$ ]]; then
#         read -r -p "Enter the file path for the database dump: " db_dump_file
#         if [ -f "$db_dump_file" ]; then
#             mysql -u root -p <"$db_dump_file"
#             echo_message "Database restored successfully."
#         else
#             echo_message "Error: File not found at $db_dump_file"
#         fi
#     fi
# fi

# echo_message "Installing oh-my-zsh."
# if [ -d ~/.config/shazam/oh-my-zsh ]; then
#     echo_message "oh-my-zsh is already installed."
#     git -C ~/.config/shazam/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
# elif [ -d ~/.oh-my-zsh ]; then
#     echo_message "oh-my-zsh is already installed at '~/.oh-my-zsh'. Moving it to '~/.config/shazam/oh-my-zsh'."
#     export ZSH="$HOME/.config/shazam/oh-my-zsh"
#     mv ~/.oh-my-zsh ~/.config/shazam/oh-my-zsh
#     git -C ~/.config/shazam/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
# else
#     git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.config/shazam/oh-my-zsh
# fi

# # Move .zcompdump files
# mkdir -p ~/.cache/zsh/
# [ -f ~/.zcompdump* ] && mv ~/.zcompdump* ~/.cache/zsh/

# echo_message "All plugins and themes are up to date!"

# # Install Cursor extensions
# extensions_file="$project_dir/vscode/.extensions"

# extension_installed() {
#     local extension="$1"
#     code --list-extensions | grep -q "$1" && return 0 || return 1
# }

# while IFS= read -r extension || [[ -n "$extension" ]]; do
#     if ! extension_installed "$extension"; then
#         echo_message "Installing extension: $extension"
#         code --install-extension "$extension"
#     else
#         echo_message "$extension already installed"
#     fi
# done <"$extensions_file"

# # Copy custom Cursor settings
# custom_settings_file="$project_dir/vscode/settings.json"
# vscode_settings_dir="$HOME/Library/Application Support/Cursor/User"
# if [ -d "$vscode_settings_dir" ]; then
#     cp -f "$custom_settings_file" "$vscode_settings_dir"
#     echo_message "Copied Cursor settings.json"
# fi

# # Update oh-my-zsh
# if /bin/zsh -c 'source ~/.zshrc && omz update'; then
#     echo_message "\nInstallation Complete!"
# else
#     echo_message "\nWarning: Something went wrong."
# fi

# exit
