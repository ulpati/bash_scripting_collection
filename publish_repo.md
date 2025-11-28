# 🚀 Publish Repo — Publish repository helper

![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)
![Bash](https://img.shields.io/badge/bash-%3E%3D4.0-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)

<p align="center"><strong>Publish or link a GitHub repository with ease</strong> 🚀</p>

## Table of Contents

- [📋 Overview](#overview)
- [✨ Features](#features)
- [📦 Installation](#installation)
- [🚀 Quick Start](#quick-start)
- [📖 Command Reference](#command-reference)
- [🧭 Behavior](#behavior)
- [💡 Examples](#examples)
- [🆘 Troubleshooting](#troubleshooting)
- [🤝 Contributing](#contributing)
- [📜 License](#license)
- [👤 Author](#author)

## 📋 Overview

Helper script to initialize a Git repository (if needed), add or
update the `origin` remote, optionally create a GitHub repository via the `gh`
CLI, and push the `main` branch.

## ✨ Features

- Initialize a Git repository when none exists
- Add or update the `origin` remote (SSH or HTTPS)
- Create a GitHub repository using `gh repo create` (optional)
- Rename the default branch to `main` and push
- `--dry-run` preview mode (no changes)
- `--verbose` for detailed output
 
## 📦 Installation

### Dependencies

#### Required
```bash
# Git is required to create commits and push
sudo apt install -y git
```

#### Optional (for creating GitHub repos)
```bash
# GitHub CLI (optional) — required only for --create
sudo apt install -y gh
# Authenticate before using: gh auth login
```

### Install Script
```bash
# Download
wget https://raw.githubusercontent.com/ulpati/bash_scripting_collection/main/publish_repo.sh

# Make executable
chmod +x publish_repo.sh

# Test
./publish_repo.sh --help
```
## 🚀 Quick Start

### Usage highlights

Run a quick dry-run to preview actions; see the **Examples** section for common commands.

```bash
# Preview actions without changing anything
./publish_repo.sh --dry-run
```

## 📖 Command Reference

### Options
```bash
--remote <URL>       Use an existing remote URL (SSH or HTTPS)
--create             Create a GitHub repo using `gh` (requires --name)
--name <NAME>        Repository name to create (used with --create)
--public             Create repository as public (default: private)
--dry-run            Print commands without executing them
-v, --verbose        Verbose output
-h, --help           Show help
```

## 🧭 Behavior

- If no commits exist the script creates an initial commit (it will create a minimal `.gitignore` if one is missing).
- The script will stage changes and may create an automatic commit before pushing (message used by the script: `chore: publish repository (auto commit)`). Use `--dry-run` to preview the commit and push commands without executing them.
- Before pushing the script ensures the repository uses `main` as the default branch and will push the branch and set the upstream on the remote.
- When `--create` is used the script delegates repository creation to the GitHub CLI (`gh`) which can create the remote and push the local repo (requires `gh` installed and authenticated).
- If no remote is configured and `--create` is not used, the script will not push and will print a warning — provide `--remote` or use `--create` to publish.

Note: To avoid automatic commits, commit your changes manually before running the script.

## 💡 Examples

```bash
# Add a remote and push (live)
./publish_repo.sh --remote [EMAIL_REMOVED]:USERNAME/my-project.git

# Create a public repository named 'my-project' (uses gh)
./publish_repo.sh --create --name my-project --public

# Preview actions without changing anything
./publish_repo.sh --remote [EMAIL_REMOVED]:USERNAME/my-project.git --dry-run
```

#### Notes
- `--remote` accepts SSH or HTTPS remote URLs.
- `--dry-run` prints the commands the script would run without executing them.
- Provide option values immediately after the option (e.g. `--name my-repo`).
- The script runs in the current working directory; ensure you are in the correct repository root when running it.



## 🆘 Troubleshooting

- "git is not installed": install via your package manager (e.g., `sudo apt install git`).
- "gh is not installed": install `gh` if you plan to use `--create` and run `gh auth login`.
- Authentication errors when pushing: ensure you have correct SSH keys or HTTPS credentials configured for the remote.
- If push fails: confirm you have permissions for the remote repository, and check network connectivity.

### Quick checks
```bash
# Check required commands
command -v git >/dev/null || echo "git not found: sudo apt install git"
command -v gh >/dev/null || echo "gh (optional) not found: sudo apt install gh"

# Check current remote
git remote -v || echo "Not a git repository or no remotes configured"

# Dry run to preview what will happen
./publish_repo.sh --dry-run
```

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## 📜 License

This project is licensed under the **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0)** - see the [LICENSE](./LICENSE) file for details.

## 👤 Author: **[ulpati](https://github.com/ulpati)**