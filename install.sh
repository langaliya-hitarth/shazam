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
SHAZAM_GIT_NAME=${SHAZAM_GIT_NAME:="Hitarth Langaliya"}
SHAZAM_GIT_EMAIL=${SHAZAM_GIT_EMAIL:="dev.hlangaliya@gmail.com"}
SHAZAM_GITHUB_USER=${SHAZAM_GITHUB_USER:="langaliya-hitarth"}
SHAZAM_REPO_URL="https://github.com/$SHAZAM_GITHUB_USER/dotfiles"
SHAZAM_URL=${SHAZAM_URL:="$SHAZAM_REPO_URL"}
SHAZAM_BRANCH=${SHAZAM_BRANCH:="main"}
SHAZAM_SUCCESS=""
SHAZAM_SUDO=0
MACOS=1

# Color definitions
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[0;37m'
readonly COLOR_BOLD='\033[1m'

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
        log "Cleaning up temporary sudo access files..."
        sudo_askpass rm -rf "$CLT_PLACEHOLDER" "$SUDO_ASKPASS" "$SUDO_ASKPASS_DIR"
        sudo --reset-timestamp
    fi
    if [ -z "$SHAZAM_SUCCESS" ]; then
        if [ -n "$SHAZAM_STEP" ]; then
            logerr "Process failed during step: $SHAZAM_STEP"
        else
            logerr "Installation process failed"
        fi
        if [ "$SHAZAM_DEBUG" -eq 0 ]; then
            logwarn "For detailed error information, please run the script with '--debug' flag"
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
    if [ "$SHAZAM_DEBUG" -gt 0 ]; then
        echo -e "${COLOR_CYAN}[DEBUG]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    else
        echo -e "${COLOR_BLUE}==> ${COLOR_BOLD}${*}${COLOR_RESET}"
    fi
}

logk() {
    SHAZAM_STEP=""
    if [ "$SHAZAM_DEBUG" -gt 0 ]; then
        echo -e "${COLOR_GREEN}[DEBUG]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - ✓ Operation completed successfully" >&2
    else
        echo -e "${COLOR_GREEN}✓ Operation completed successfully${COLOR_RESET}"
    fi
}

logn_no_sudo() {
    SHAZAM_STEP="$*"
    if [ "$SHAZAM_DEBUG" -gt 0 ]; then
        echo -ne "${COLOR_CYAN}[DEBUG]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $* " >&2
    else
        printf -- "${COLOR_BLUE}==> ${COLOR_BOLD}%s${COLOR_RESET} " "$*"
    fi
}

logskip() {
    SHAZAM_STEP=""
    if [ "$SHAZAM_DEBUG" -gt 0 ]; then
        echo -e "${COLOR_YELLOW}[DEBUG]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - SKIPPED: $*" >&2
    else
        echo -e "${COLOR_YELLOW}⏭  Operation skipped${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   Reason: ${*}${COLOR_RESET}"
    fi
}

logerr() {
    SHAZAM_STEP=""
    if [ "$SHAZAM_DEBUG" -gt 0 ]; then
        echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    else
        echo -e "${COLOR_RED}❌ Error: ${*}${COLOR_RESET}" >&2
    fi
}

logwarn() {
    SHAZAM_STEP=""
    if [ "$SHAZAM_DEBUG" -gt 0 ]; then
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    else
        echo -e "${COLOR_YELLOW}⚠️  Warning: ${*}${COLOR_RESET}" >&2
    fi
}

sudo_init() {
    if [ "$SHAZAM_INTERACTIVE" -eq 0 ]; then
        sudo -n -l mkdir &>/dev/null && export SHAZAM_SUDO=1
        echo "Checked sudo permissions without interaction. SHAZAM_SUDO set to $SHAZAM_SUDO."
        return
    fi
    local SUDO_PASSWORD SUDO_PASSWORD_SCRIPT
    if ! sudo --validate --non-interactive &>/dev/null; then
        echo "Sudo validation failed. Prompting for password."
        while true; do
            read -rsp "--> Enter your password (for sudo access):" SUDO_PASSWORD
            echo
            if sudo --validate --stdin 2>/dev/null <<<"$SUDO_PASSWORD"; then
                echo "Sudo validation successful."
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
        echo "SUDO_ASKPASS set and SHAZAM_SUDO updated to $SHAZAM_SUDO."
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
    if [ "$SHAZAM_DEBUG" -gt 0 ]; then
        echo -e "${COLOR_CYAN}[DEBUG]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    else
        echo -e "${COLOR_BLUE}==> ${COLOR_BOLD}${*}${COLOR_RESET}"
    fi
}

logn() {
    SHAZAM_STEP="$*"
    sudo_refresh
    if [ "$SHAZAM_DEBUG" -gt 0 ]; then
        echo -ne "${COLOR_CYAN}[DEBUG]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $* " >&2
    else
        printf -- "${COLOR_BLUE}==> ${COLOR_BOLD}%s${COLOR_RESET} " "$*"
    fi
}

readonly HOME_DIR="$HOME"
readonly DOT_DIR="$HOME_DIR/.config/shazam2"
readonly VSCODE_DOT_DIR="$DOT_DIR/dotfiles/vscode"

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

    # local dotfile
    # for dotfile in "$DOT_DIR"/.*; do
    #     [[ -e "$dotfile" ]] || continue # Skip if file doesn't exist

    #     # Skip ignored patterns
    #     local should_ignore=false
    #     for pattern in "${IGNORE_PATTERNS[@]}"; do
    #         if [[ "$dotfile" == *"$pattern" ]]; then
    #             should_ignore=true
    #             break
    #         fi
    #     done

    #     "$should_ignore" && continue

    #     if [[ -d "$dotfile" ]]; then
    #         symlink_dir_contents "$dotfile" "$DOT_DIR" "$HOME_DIR"
    #     elif [[ -f "$dotfile" ]]; then
    #         symlink_file "$dotfile" "$DOT_DIR" "$HOME_DIR"
    #     fi
    # done

    ln -nsfF "$DOT_DIR/dotfiles/brew/.Brewfile" "$HOME/.Brewfile"
}

symlink_vscode_settings() {
    log "Configuring VSCode settings and extensions..."
    local vscode_base_dir="$HOME/Library/Application Support"

    local -a editor_dirs=(
        "Code"
        "Cursor"
        "Code - Exploration"
        "Code - Insiders"
        "VSCodium"
    )

    local dir
    for dir in "${editor_dirs[@]}"; do
        logn "Setting up configuration for $dir..."
        local full_path="$vscode_base_dir/$dir/User"
        if [[ -d "$full_path" ]]; then
            symlink_dir_contents "$VSCODE_DOT_DIR/settings" "$VSCODE_DOT_DIR" "$full_path"
            logk
        else
            logskip "$dir is not installed on this system"
        fi
    done
}

symlink_zshrc() {
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

# Given a list of scripts in the dotfiles repo, run the first one that exists
run_dotfile_scripts() {
    if [ -d "$HOME/.config/shazam2" ]; then
        (
            cd "$HOME/.config/shazam2"
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
        log "Installing Xcode Command Line Tools - This may take a few minutes..."
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
                logn "Xcode Command Line Tools not found. Initiating interactive installation..."
                xcode-select --install
            else
                echo
                abort "Xcode Command Line Tools installation failed. Please run 'xcode-select --install' manually."
            fi
        fi
        logk
    else
        logskip "Xcode Command Line Tools are already installed"
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

# if [ "$MACOS" -gt 0 ] && [ "$SHAZAM_ADMIN" -gt 0 ]; then
#     install_xcode_clt
#     check_xcode_license
#     check_software_updates
# else
#     logskip "Xcode Command-Line Tools install and license check skipped."
# fi

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
# configure_git

# Set up dotfiles
# shellcheck disable=SC2086
if [ ! -d "$HOME/.config/shazam2" ]; then
    if [ -z "$SHAZAM_URL" ] || [ -z "$SHAZAM_BRANCH" ]; then
        abort "Please set SHAZAM_URL and SHAZAM_BRANCH."
    fi
    log_no_sudo "Cloning $SHAZAM_URL to $HOME/.config/shazam2."
    git clone $Q "$SHAZAM_URL" "$HOME/.config/shazam2"
fi
shazam_branch_name="${SHAZAM_BRANCH##*/}"
log_no_sudo "Checking out $shazam_branch_name in $HOME/.config/shazam2."
# shellcheck disable=SC2086
(
    cd "$HOME/.config/shazam2"
    git stash
    git fetch $Q
    git checkout "$shazam_branch_name"
    git pull $Q --rebase --autostash
)

if symlink_repo_dotfiles; then
    echo "-> Symlinking successful. Finishing up..."
else
    echo "-> Symlinking unsuccessful."
fi

# run_dotfile_scripts scripts/symlink.sh
# The second call to `configure_git` is needed for CI use cases in which some
# aspects of the `.gitconfig` cannot be used after cloning the dotfiles repo.
# configure_git
# logk

install_homebrew() {
    log "Preparing Homebrew installation - Setting up directories and permissions..."
    HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
    [ -n "$HOMEBREW_PREFIX" ] || HOMEBREW_PREFIX="$DEFAULT_HOMEBREW_PREFIX"

    if [ ! -d "$HOMEBREW_PREFIX" ]; then
        logn "Creating Homebrew directory at $HOMEBREW_PREFIX..."
        sudo_askpass mkdir -p "$HOMEBREW_PREFIX"
        logk
    fi

    logn "Setting up Homebrew directory permissions..."
    sudo_askpass chown -R "root:wheel" "$HOMEBREW_PREFIX" 2>/dev/null || true
    logk

    log "Creating required Homebrew subdirectories..."
    (
        cd "$HOMEBREW_PREFIX"
        sudo_askpass mkdir -p \
            Cellar Caskroom Frameworks bin etc include lib opt sbin share var
        sudo_askpass chown "$USER:admin" \
            Cellar Caskroom Frameworks bin etc include lib opt sbin share var
    )
    logk

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
    [ "$SHAZAM_CI" -gt 0 ] && set_up_brew_skips
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
        github_user="${SHAZAM_GITHUB_USER:-langaliya-hitarth}"
        brewfile_domain="https://raw.githubusercontent.com"
        brewfile_path="$github_user/shazam/$git_branch/Brewfile"
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
if [ "$SHAZAM_SUDO" -eq 0 ]; then
    sudo_init || logskip "Skipping Homebrew installation (requires sudo)."
fi

if type brew &>/dev/null; then
    logskip "Homebrew is already installed."
else
    if [ "$SHAZAM_SUDO" -gt 0 ]; then
        # Prevent "Permission denied" errors on Homebrew directories
        log "Updating permissions on Homebrew directories"
        sudo_askpass mkdir -p "$HOMEBREW_PREFIX/"{Caskroom,Cellar,Frameworks}
        sudo_askpass chmod -R 775 "$HOMEBREW_PREFIX/"{Caskroom,Cellar,Frameworks}
        sudo_askpass chown -R "$USER" "$HOMEBREW_PREFIX" 2>/dev/null || true
        logk
        log "Installing Homebrew on macOS"
        script_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
        NONINTERACTIVE=$SHAZAM_CI \
            /usr/bin/env bash -c "$(curl -fsSL $script_url)" || install_homebrew
        logk
        run_brew_installs || abort "Homebrew installs were not successful."
        brew cleanup
    fi
fi

### Configure macOS
# if [ "$SHAZAM_ADMIN" -gt 0 ]; then
#     chmod +x "$HOME"/.config/shazam2/scripts/macSettings.sh
#     "$HOME"/.config/shazam2/scripts/macSettings.sh
# else
#     echo "Not admin. Skipping macos.sh. Set \$SHAZAM_ADMIN to run macos.sh."
# fi

# Symlink VSCode settings
# if symlink_vscode_settings; then
#     echo "-> Symlinking VSCode settings successful. Finishing up..."
# else
#     echo "-> Symlinking VSCode settings unsuccessful."
# fi

### Install VSCode extensions
# TODO: Cursor extension installs not working
# for i in {code,code-exploration,code-insiders,code-server,codium}; do
#     chmod +x "$HOME"/.config/shazam2/scripts/vscode.sh
#     "$HOME"/.config/shazam2/scripts/vscode.sh "$i"
# done

# Install nvm
# Create ~/.nvm directory if nvm is installed but the directory does not exist
# echo "Installing nvm..."
# export NVM_DIR="$HOME/.config/shazam2/.nvm" && (
#     git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
#     cd "$NVM_DIR"
#     git checkout $(git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1))
# ) && \. "$NVM_DIR/nvm.sh"

# echo "Installing node..."
# nvm install node --silent
# echo "Node version $(node -v) installed"

### Set shell
if [ "$SHAZAM_SUDO" -gt 0 ]; then
    case $SHELL in
    *zsh) echo "Shell is already set to Zsh." ;;
    *)
        if type zsh &>/dev/null; then
            echo "--> Changing shell to Zsh. Sudo required."
            sudo chsh -s "$(type -P zsh)" "$USER"
        else
            echo "Zsh not found."
        fi
        ;;
    esac
else
    echo "Not sudo. Shell not changed. Set \$SHAZAM_SUDO to change shell."
fi

### Install Oh My Posh
# if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
#     if [ -d "$HOME/.config/shazam2/dotfiles/oh-my-posh" ]; then
#         if [[ "$SHELL" == "/bin/zsh" ]]; then
#             eval "$(oh-my-posh init zsh --config ~/.config/shazam2/dotfiles/oh-my-posh/theme.toml)"
#         else
#             echo "Warning: Shell is not Zsh. Oh My Posh initialization skipped."
#         fi
#     else
#         echo "Warning: Oh My Posh directory does not exist. Initialization skipped."
#     fi
# fi

## Install Oh My ZSH
if [ -d "$HOME/.config/shazam2/.oh-my-zsh" ]; then
    echo "Oh My ZSH is already installed."
else
    echo "Installing Oh My ZSH..."
    sh -c "ZSH='$HOME/.config/shazam2/.oh-my-zsh' $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Initialize and update git submodules if .gitmodules exists
if [ -f "$HOME/.config/shazam2/dotfiles/git/.gitmodules" ]; then
    echo "Found .gitmodules file. Initializing and updating git submodules..."
    cd "$HOME/.config/shazam2"
    git submodule init
    git submodule update --init --recursive
    echo "Git submodules updated successfully."
else
    echo "No .gitmodules file found. Skipping submodule initialization."
fi

source ~/.zshrc

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
# if [ -d ~/.config/shazam2/oh-my-zsh ]; then
#     echo_message "oh-my-zsh is already installed."
#     git -C ~/.config/shazam2/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
# elif [ -d ~/.oh-my-zsh ]; then
#     echo_message "oh-my-zsh is already installed at '~/.oh-my-zsh'. Moving it to '~/.config/shazam2/oh-my-zsh'."
#     export ZSH="$HOME/.config/shazam2/oh-my-zsh"
#     mv ~/.oh-my-zsh ~/.config/shazam2/oh-my-zsh
#     git -C ~/.config/shazam2/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
# else
#     git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.config/shazam2/oh-my-zsh
# fi

# # Move .zcompdump files
# mkdir -p ~/.cache/zsh/
# [ -f ~/.zcompdump* ] && mv ~/.zcompdump* ~/.cache/zsh/

# echo_message "All plugins and themes are up to date!"
