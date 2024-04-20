# Install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

#Install brew packages
brew install git
brew install php
brew install mysql
brew install node
brew install nvm
brew install composer
brew install wget
brew install lsd
brew install postgresql@13
brew install --cask google-chrome
brew install --cask visual-studio-code
brew install --cask warp
brew install --cask raycast
brew install --cask notion
brew install --cask todoist
brew install --cask postman
brew install --cask dbeaver
brew install --cask spotify

brew cleanup

# Install and configure oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo "Installing powerlevel10k"
git clone https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

echo "Installing zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

echo "Installing zsh-syntax-highlighting"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Check if zshrc file already exists create a backup
if [ -f ~/.zshrc ]
then
	mv ~/.zshrc ~/.zsh-pre-autoinstall
fi

# Copy zshrc file to root
echo "Creating aliases"
cd ./zsh/.aliases ~/
echo "Done!"

echo "Creating zsh config"
cp ./zsh/.zshrc ~/
echo "Done!"

echo "Configure p10k"
if [ ! -f ~/.p10k.zsh ]
then
	p10k configure
else
	cp ./zsh/.p10k.zsh ~/
fi

# Source zshrc
source ~/.zshrc
