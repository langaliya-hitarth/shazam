#!/bin/bash

# Declare all the app packages and fonts required
declare -a packages=("git" "zsh" "wget" "php" "mysql" "node" "nvm" "composer" "lsd" "postgresql@13")
declare -a applications=("google-chrome" "visual-studio-code" "warp" "raycast" "notion" "todoist" "postman" "dbeaver" "spotify")
declare -a fonts=("font-jetbrains-mono" "font-meslo-lg-nerd-font")

# Install all packages if not installed
for package in "${packages[@]}"
do
    if command -v $package &> /dev/null; then
        echo $package" is already installed\n"
    else
        echo "Installing "$package"...\n"
        if brew install $package ; then
            echo $package" Installed\n"
        else
            echo "Could not install packages \n" && exit
        fi
    fi
done

# Install all applications if not installed
for application in "${applications[@]}"
do
    if brew list --cask | grep -q "^$application\$"; then
        echo "$application is already installed\n"
    else
        brew install --cask "$application"
    fi 
done

# Install all fonts if not installed
if brew tap | grep -q "homebrew/cask-fonts"; then
    echo "homebrew/cask-fonts is already tapped"
else
    brew tap homebrew/cask-fonts
fi

for font in "${fonts[@]}"
do
    if brew list --cask | grep -q "^$font\$"; then
        echo "$font is already installed\n"
    else
        brew install --cask "$font"
    fi 
done

# Backup original .zshrc file in the ~/.config/shazam/backup directory
mkdir -p ~/.config/shazam/backup
if mv -n ~/.zshrc ~/.config/shazam/backup/.$(date +"%Y%m%d")-zshrc-backup; then
    echo "Backed up the current .zshrc to ~/.config/shazam/backup/.$(date +"%Y%m%d")-zshrc-backup\n"
fi

echo "The setup will be installed in '~/.config/shazam'\n"

echo "Installing oh-my-zsh\n"
if [ -d ~/.config/shazam/oh-my-zsh ]; then
    echo "oh-my-zsh is already installed\n"
    git -C ~/.config/shazam/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
elif [ -d ~/.oh-my-zsh ]; then
    echo "oh-my-zsh in already installed at '~/.oh-my-zsh'. Moving it to '~/.config/shazam/oh-my-zsh'"
    export ZSH="$HOME/.config/shazam/oh-my-zsh"
    mv ~/.oh-my-zsh ~/.config/shazam/oh-my-zsh
    git -C ~/.config/shazam/oh-my-zsh remote set-url origin https://github.com/ohmyzsh/ohmyzsh.git
else
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.config/shazam/oh-my-zsh
fi

cp -f config/.aliases ~/.config/shazam/
cp -f config/.shazam ~/.config/shazam/
cp -f config/.zshrc ~/

# this will be used to store .zcompdump zsh completion cache files which normally clutter $HOME
mkdir -p ~/.cache/zsh/

if [ -f ~/.zcompdump ]; then
    mv ~/.zcompdump* ~/.cache/zsh/
fi

if [ -d ~/.config/shazam/oh-my-zsh/plugins/zsh-autosuggestions ]; then
    cd ~/.config/shazam/oh-my-zsh/plugins/zsh-autosuggestions && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.config/shazam/oh-my-zsh/plugins/zsh-autosuggestions
fi

if [ -d ~/.config/shazam/oh-my-zsh/custom/plugins/zsh-syntax-highlighting ]; then
    cd ~/.config/shazam/oh-my-zsh/custom/plugins/zsh-syntax-highlighting && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.config/shazam/oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

if [ -d ~/.config/shazam/oh-my-zsh/custom/plugins/zsh-completions ]; then
    cd ~/.config/shazam/oh-my-zsh/custom/plugins/zsh-completions && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-completions ~/.config/shazam/oh-my-zsh/custom/plugins/zsh-completions
fi

if [ -d ~/.config/shazam/oh-my-zsh/custom/plugins/zsh-history-substring-search ]; then
    cd ~/.config/shazam/oh-my-zsh/custom/plugins/zsh-history-substring-search && git pull
else
    git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search ~/.config/shazam/oh-my-zsh/custom/plugins/zsh-history-substring-search
fi

if [ -d ~/.config/shazam/oh-my-zsh/custom/themes/powerlevel10k ]; then
    cd ~/.config/shazam/oh-my-zsh/custom/themes/powerlevel10k && git pull
else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.config/shazam/oh-my-zsh/custom/themes/powerlevel10k
fi

if chsh -s $(which zsh) && /bin/zsh -i -c 'omz update'; then
    echo "Installation complete, exit terminal and enter a new zsh session\n"
else
    echo "Something is wrong"
fi
exit