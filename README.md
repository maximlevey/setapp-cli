# setapp-cli

![macOS](https://img.shields.io/badge/macOS-12%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Install and manage [Setapp](https://setapp.com) apps from the command line. Save your app list to a bundle file, check it into your dotfiles, and restore it on a new Mac -- like Homebrew, but for Setapp.

## Quick start

### Installation

```sh
curl -fsSL https://raw.githubusercontent.com/maximlevey/setapp-cli/main/install.sh | bash
```
### Usage

```
USAGE: setapp-cli <subcommand>

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.

SUBCOMMANDS:
  install                 Install a Setapp app by name.
  remove                  Uninstall a Setapp app.
  reinstall               Uninstall then reinstall a Setapp app.
  list                    List installed Setapp apps.
  check                   Find locally installed apps that are available via Setapp.
  dump                    Save installed Setapp apps to a bundle file.
  bundle                  Manage bundle files for saving and restoring app lists.
```

## Documentation

See the [wiki](https://github.com/maximlevey/setapp-cli/wiki) for full documentation.

## License

[MIT License](LICENSE)

Copyright (c) 2026 Maxim Levey
