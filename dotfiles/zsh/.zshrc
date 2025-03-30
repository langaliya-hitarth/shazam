#!/usr/bin/env zsh

# This file is created by shazam setup.
# Your original .zshrc is backed up at ~/.zshrc-backup-%y-%m-%d

export SHAZAM="$HOME/.config/shazam2"
export ZSH="$SHAZAM/.oh-my-zsh"
export POSH="$SHAZAM/.oh-my-posh"
export EZA_CONFIG_DIR="$SHAZAM/eza"
export ZSHPLUGINS="$ZSH/plugins"
export ZSHCUSTOM="$ZSH/custom"

# History Configurations
HISTFILE=~/.config/shazam2/.zsh_history
HISTSIZE=10000
setopt autocd extendedglob globdots histignorespace noautomenu nullglob

if [ "$TERM_PROGRAM" != "Apple_Terminal" ] && [ -d "$HOME/.config/shazam2/.oh-my-posh" ] && [ "$SHELL" = "/bin/zsh" ]; then
  eval "$(oh-my-posh init zsh --config ~/.config/shazam2/.oh-my-posh/theme.toml)"
fi

### homebrew
# if [[ -z $HOMEBREW_PREFIX ]]; then
#   case $(uname) in
#   Darwin)
#     if [[ $(uname -m) == 'arm64' ]]; then
#       HOMEBREW_PREFIX='/opt/homebrew'
#     elif [[ $(uname -m) == 'x86_64' ]]; then
#       HOMEBREW_PREFIX='/usr/local'
#     fi
#     ;;
#   Linux)
#     if [[ -d '/home/linuxbrew/.linuxbrew' ]]; then
#       HOMEBREW_PREFIX='/home/linuxbrew/.linuxbrew'
#     elif [[ -d $HOME/.linuxbrew ]]; then
#       HOMEBREW_PREFIX=$HOME/.linuxbrew
#     fi
#     if [[ -d $HOMEBREW_PREFIX ]]; then
#       PATH=$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH
#     fi
#     ;;
#   esac
# fi
# if [[ -d $HOMEBREW_PREFIX ]]; then
#   eval $($HOMEBREW_PREFIX/bin/brew shellenv)
# fi

plugins=(
  git
  # zsh-nvm
  brew
  copyfile
  copypath
  extract
  fzf
  # zsh-autosuggestions
  # fast-syntax-highlighting
  # you-should-use
  sudo
  # zsh-better-npm-completion
)

source $ZSH/oh-my-zsh.sh

export NVM_DIR="$HOME/.config/shazam2/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

### aliases
source ~/.config/shazam2/dotfiles/zsh/.aliases

source <(zoxide init zsh)

### completions
# if type brew &>/dev/null && [[ -d $HOMEBREW_PREFIX ]]; then
#   fpath+=($HOMEBREW_PREFIX/share/zsh/site-functions)
# fi
zstyle :compinstall filename $HOME/.zshrc
autoload -Uz compinit
compinit
