# 🛡️ Metadata Cleaner - File Sanitization Tool

![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)
![Bash](https://img.shields.io/badge/bash-%3E%3D4.0-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)

<p align="center">
  <strong>Privacy matters. Clean your metadata!</strong> 🛡️
</p>

## Table of Contents

- [📋 Overview](#overview)
- [✨ Features](#features)
- [📦 Installation](#installation)
- [🚀 Quick Start](#quick-start)
- [📖 Command Reference](#command-reference)
- [💡 Examples](#examples)
- [🔍 What Gets Cleaned](#what-gets-cleaned)
- [📊 Reports & Verification](#reports--verification)
- [🚫 Automatic Exclusions](#automatic-exclusions)
- [🆘 Troubleshooting](#troubleshooting)
- [🤝 Contributing](#contributing)
- [📜 License](#license)
- [👤 Author](#author)

## 📋 Overview

File sanitization tool that removes **all identifying metadata** from files and directories before sharing them on **any platform**. Ensures your privacy whether you're uploading to cloud storage, sharing files, publishing datasets, or collaborating online.

## ✨ Features

### 🎯 Comprehensive Metadata Removal
- **EXIF data** from images (GPS, camera, timestamps)
- **ID3 tags** from audio (artist, album, year)
- **Document metadata** (author, software, dates)
- **Jupyter notebooks** (execution history, outputs)
- **Filesystem attributes** (extended attributes)
- **Text comments** (author, date, modified by)

### 🔒 Sensitive Data Protection (Aggressive Mode)
- Passwords, secrets, API keys, tokens
- Email addresses → `[EMAIL_REMOVED]`
- Absolute paths: `/home/<username>/...` → `/home/user/...`
- Private IPs `192.168.x.x` → `XXX.XXX.XXX.XXX`
- Credentials and authentication data

### 🔍 Post-Sanitization Audit
- **Automatic verification** after cleaning
- Scans for remaining sensitive data
- Generates warnings if issues found
- Confirms safety for public sharing

### 💾 Smart Backup & Compression
- Compressed backups (optional)
- SHA256 checksums (`--checksums`)
- Timestamped backup per run → multiple restore points
- Integrity checks (file/readable/size, notebook JSON)

## 📦 Installation

### Dependencies

#### Required
```bash
# Debian/Ubuntu
sudo apt install -y libimage-exiftool-perl python3
```

#### Optional (recommended)
```bash
# mat2 improves cleaning for documents and archives
sudo apt install -y mat2
```

### Install Script
```bash
# Download
wget https://raw.githubusercontent.com/ulpati/bash_scripting_collection/main/metadata_cleaner.sh

# Make executable
chmod +x metadata_cleaner.sh

# Test
./metadata_cleaner.sh --help
```

## 🚀 Quick Start

### Basic Usage
```bash
# Single file
./metadata_cleaner.sh document.pdf

# Directory (non-recursive)
./metadata_cleaner.sh /path/to/directory

# Recursive cleaning
./metadata_cleaner.sh -r /path/to/directory

# Preview with dry-run
./metadata_cleaner.sh -d -r /path/to/directory
```

## 📖 Command Reference

### Options
```bash
-h, --help             Show help message
-v, --verbose          Enable verbose output
-d, --dry-run          Preview changes without modifying files
-r, --recursive        Process directories recursively
-b, --backup           Create backup before cleaning
--backup-dir <path>    Specify custom backup directory (default: ./metadata_backup)
-c, --compress         Compress backup
-a, --aggressive       Remove sensitive data patterns (aggressive mode)
--sanitize-git         Clean version control metadata (remove remotes, unset local user info)
--checksums            Generate SHA256 hashes (added to report when enabled)
--report <file>        Generate detailed report to specified file
-p, --parallel         Enable parallel processing (uses xargs -P)
-j, --jobs <n>         Number of parallel jobs (default: 4)
```

### 💡 Examples
Use `--dry-run` first to preview changes. Common workflows and practical examples:

```bash
# Preview (recommended)
./metadata_cleaner.sh -d -r /path/to/share

# Safe for sharing (backup + aggressive)
./metadata_cleaner.sh -r -b -a /path/to/share

# Presentation (single file)
./metadata_cleaner.sh -b -a presentation.pptx

# Photos (preview then apply)
./metadata_cleaner.sh -d -r photos/
./metadata_cleaner.sh -r -b -a photos/

# Prepare an academic dataset (preview then apply)
./metadata_cleaner.sh -d -r research_data/
./metadata_cleaner.sh -r -b --backup-dir ./metadata_backup/dataset -c --checksums --report dataset_audit.txt research_data/

# Full project sanitization (sanitize git + report)
./metadata_cleaner.sh -a -b -c --sanitize-git --report sanitization_report.txt my_project/

# Sanitize workspace from a temporary location (avoid modifying working dir)
cp metadata_cleaner.sh /tmp/ && cd /tmp && ./metadata_cleaner.sh -a -c --report report.txt ~/projects/ && rm /tmp/metadata_cleaner.sh

# Backup + Compress + Aggressive + Verify (maximum safety)
./metadata_cleaner.sh -r -b -c -a --sanitize-git --checksums  --report complete_report.txt /path/to/files
```

#### Notes
- `-c` (compress backup) only takes effect when `-b` (backup) is also specified; add `-b` if you want a compressed backup.
- Options that require a value (for example `--report`, `--backup-dir`, `-j`) must be followed immediately by their argument: e.g. `--report report.txt`.
- The target path (file or directory) must come after the options (positional argument). Quote paths that contain spaces: `"/path/with space"`.
- `-d/--dry-run` previews changes and does not run the post-sanitization audit.
- For large datasets, consider parallel processing with `-p -j <n>` (ensure sufficient CPU/IO resources).

- `--backup-dir <path>` implies backup will be created (equivalent to `-b --backup-dir <path>`).

## 🔍 What Gets Cleaned

Images, audio/video, documents, notebooks and many common file types are processed to remove identifying metadata. Key items cleaned include:

- Images (JPG, PNG, TIFF, GIF, WebP): GPS coordinates, camera make/model, software, creation date/time, author information
- Audio/Video (MP3, MP4, AVI, MOV): artist/album/year, recording location, software metadata, timestamps
- Documents (PDF, DOCX, XLSX, ODT): author, organization, software version; note that revision history and some embedded comments may require manual inspection
- Jupyter Notebooks (.ipynb): execution counts, cell outputs, kernel info, session metadata
- All files: filesystem timestamps (set to 2000-01-01), extended attributes (xattrs), and heuristic removal of author/date comments in code/text files

#### Notes / Caveats

- **mat2 (recommended):** The script uses `mat2` when available and falls back to `exiftool` otherwise; `mat2` provides more complete cleaning for documents and archives.
- **Complex metadata may remain:** Some metadata can persist (e.g., revision history and change‑tracking in DOCX, embedded comments in PDFs). For those files, manually inspect or export/print to a new file.
- **ACLs / permissions not removed:** The script does not remove ACLs or change file permissions. Use system tools to handle these (e.g., `setfacl` / `getfacl` on Linux, `icacls` on Windows).
- **Text comment/author removal is heuristic:** Removal of author/date comments in text files uses common patterns and may not eliminate every occurrence embedded in file content.
- **Practical recommendation:** Always run a preview with `--dry-run`, create a backup with `-b`, and verify results after cleaning (for example with `exiftool` and `grep`).

## 📊 Reports & Verification

### Audit Report Includes:
- Files processed/cleaned/skipped/failed
- Sensitive data items removed
- Audit warnings (remaining issues)
- SHA256 checksums (optional)
- Processing time and statistics

### Example Output:
```
========================================
Statistics:
========================================
Total files found:     657
Successfully cleaned:  621
Skipped:              36 (excluded/binary)
Failed:               0
Sensitive data items:  39
Audit warnings:       0 (PASSED)
Data processed:       ~100 MB
Time elapsed:         0m 3s
========================================
```

### Check Audit Results
```bash
# Run cleaning
./metadata_cleaner.sh -r -a --report audit.txt files/

# Check for warnings
grep "AUDIT WARNING" audit.txt

# Verify checksums
grep "SHA256:" audit.txt
```

## 🚫 Automatic Exclusions

These are automatically skipped (not cleaned):
- Development: `.git`, `node_modules`, `__pycache__`, `.venv`, `dist`, `build`
- Binaries: `*.pyc`, `*.so`, `*.dll`, `*.exe`, `*.o`, `*.a`
 - Caches / Temp: `.tox`, `.pytest_cache`, `.mypy_cache`

Note: `.git` is listed above as excluded from normal cleaning to avoid accidental modification of repository internals; use `--sanitize-git` when you explicitly want to remove remotes and local user info from a repository.

## 🆘 Troubleshooting

### Script exits with error
```bash
# Check syntax
bash -n metadata_cleaner.sh

# Run with verbose
./metadata_cleaner.sh -v file.jpg
```

### Audit fails
 - Re-run with `-a` (aggressive) flag to attempt additional removals, then re-check the report.
 - Check the audit report for specific warnings (`grep "AUDIT WARNING" audit.txt`).
 - Manually inspect flagged files listed in the report.
 - False positives: filenames like `password_generator.py` or IP examples in documentation are safe.

Common checks when troubleshooting failures:

```bash
# Verify required commands are available
command -v exiftool python3 >/dev/null || echo "Missing required dependency: exiftool or python3"
# mat2 is optional but recommended
command -v mat2 >/dev/null || echo "Optional tool 'mat2' not found (recommended for documents)"

# Check that the report and backup directories are writable
touch ./metadata_cleaner_test_write && rm ./metadata_cleaner_test_write || echo "No write permission in current directory"

# Check free disk space before creating large backups
df -h . | awk 'NR==2{print "Available:",$4}'

# If backups/compression fail, ensure the target backup dir exists and you have permissions
ls -ld ./metadata_backup || echo "Backup dir ./metadata_backup not found (will be created automatically if writable)"
```

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## 📜 License

This project is licensed under the **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0)** - see the [LICENSE](./LICENSE) file for details.

## 👤 Author: **[ulpati](https://github.com/ulpati)**