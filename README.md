# Shazam!

## Overview

Shazam! is a bash script designed to automate the setup of your development environment on macOS. It installs various packages, applications, fonts, and configures settings to streamline your development workflow.

## Features

- **Package Management:** Installs essential packages via Homebrew.
- **Application Installation:** Installs commonly used applications via Homebrew Cask.
- **Font Management:** Installs developer-friendly fonts via Homebrew Cask Fonts.
- **MySQL Setup:** Installs MySQL server and provides an option to restore databases.
- **oh-my-zsh Installation:** Sets up oh-my-zsh with custom configurations.
- **Plugin Management:** Installs popular zsh plugins.
- **VS Code Setup:** Installs VS Code extensions and copies custom settings.

## Usage

1. Clone this repository:

    ```bash
    git clone https://github.com/yourusername/Shazam.git
    ```

2. Navigate to the project directory:

    ```bash
    cd Shazam
    ```

3. Run the setup script:

    ```bash
    ./shazam.sh
    ```

    Follow the on-screen prompts for any additional setup steps.

## Requirements

- macOS
- [Homebrew](https://brew.sh/)
- Git (Installed by default on macOS)
- Internet connection (for downloading packages and applications)

## Configuration

The script can be configured by editing the following arrays:

- `packages`: List of essential packages to install.
- `applications`: List of applications to install via Homebrew Cask.
- `fonts`: List of fonts to install via Homebrew Cask Fonts.

Additionally, you can customize VS Code extensions by editing the `.extensions` file and VS Code settings by modifying the `settings.json` file in the `vscode` directory.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
