# 🐚 Bash Scripting Collection

![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)
![Bash](https://img.shields.io/badge/bash-%3E%3D4.0-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)

Collection of bash scripts for automation, privacy, security, and productivity.

---

## 📦 Available Scripts

### [metadata_cleaner.sh](./metadata_cleaner.sh)

File sanitization tool for removing identifying metadata from images, documents, notebooks, and common file types before sharing.
Highlights: backups (timestamped), optional compression, aggressive pattern removal and an audit/report mode.

📖 [Documentation](./metadata_cleaner.md)

---

### [publish_repo.sh](./publish_repo.sh)

Create or link a GitHub repository and push the `main` branch. Supports creating a repository via the `gh` CLI (optional) and adding/updating the `origin` remote.

Highlights: creates an initial commit when none exists, can `gh repo create` and push, and will ensure the default branch is `main` before pushing.

📖 [Documentation](./publish_repo.md)

---

## 📂 Repository Structure

```
bash_scripting_collection/
├── README.md                      # Main documentation
├── LICENSE                        # CC BY-NC-SA 4.0 License
├── CONTRIBUTING.md                # Contribution guidelines
├── script_name.sh                 # Executable script
└── script_name.md                 # Script documentation
```

---

## 🚀 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/ulpati/bash_scripting_collection.git
cd bash_scripting_collection

# Make scripts executable
chmod +x *.sh
```

### Using a Script

Each script has its own README with detailed documentation:

```bash
# View script help
./script_name.sh --help

# Read script documentation
cat script_name.md
```
---

## 📖 Documentation

Each script includes:
- 📌 `script_name.sh` - Executable script
- 📌 `script_name.md` - Complete documentation with examples

General repository files:
- 📄 `README.md` - This file (repository overview)
- 📄 `CONTRIBUTING.md` - Contribution guidelines
- 📄 `LICENSE` - CC BY-NC-SA 4.0 License

---

## 🛠️ Development Philosophy

These scripts follow bash best practices:
- ✅ `set -euo pipefail` for safety
- ✅ Comprehensive error handling
- ✅ Input validation and sanitization
- ✅ Clear, descriptive variable names
- ✅ Extensive inline documentation
- ✅ Dry-run modes for safe testing
- ✅ Detailed logging and reporting

---

## 🔒 Security & Privacy

⚠️ **Important**: 
- Always review scripts before execution
- Test in a safe environment first
- Use dry-run mode
- Create backups before modifying important data
- Scripts include validation and safety checks

---

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

---

## 📝 License

This project is licensed under the **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0)** - see the [LICENSE](./LICENSE) file for details.

---

## 🙏 Acknowledgments

 Open source community and contributors