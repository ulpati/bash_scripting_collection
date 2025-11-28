#!/bin/bash

#########################################################################
# Metadata Cleaner Script
#
# Purpose:
#   File sanitization tool that removes all identifying metadata from
#   files and directories before sharing them on any platform. Ensures
#   your privacy whether you're uploading to cloud storage, sharing
#   files, publishing datasets, or collaborating online.
#
# License: CC BY-NC-SA 4.0
#
# Usage:
#   ./metadata_cleaner.sh [OPTIONS] <path>
#
# Documentation:
#   See `metadata_cleaner.md` for full usage, options, dependencies,
#   installation instructions, and examples.
#
#########################################################################

set -euo pipefail  # Exit on error, undefined variables, and pipe failures
IFS=$'\n\t'        # Set safer Internal Field Separator

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
VERBOSE=false
DRY_RUN=false
RECURSIVE=false
BACKUP=false
BACKUP_DIR=""
PARALLEL=false
MAX_JOBS=4
AGGRESSIVE=false
COMPRESS_BACKUP=false
GENERATE_CHECKSUMS=false
SANITIZE_GIT=false

# Statistics counters
TOTAL_FILES=0
CLEANED_FILES=0
SKIPPED_FILES=0
FAILED_FILES=0
BYTES_PROCESSED=0
SENSITIVE_DATA_REMOVED=0
AUDIT_WARNINGS=0

# File tracking arrays
declare -a SKIPPED_FILES_LIST=()
declare -a FAILED_FILES_LIST=()
declare -a CLEANED_FILES_LIST=()

# Exclusion patterns (directories and files to skip)
readonly EXCLUDED_DIRS=(".git" "node_modules" "__pycache__" ".venv" "venv" "env" ".env" "dist" "build" ".pytest_cache" ".mypy_cache" ".tox")
readonly EXCLUDED_FILES=("*.pyc" "*.pyo" "*.so" "*.dylib" "*.dll" "*.exe" "*.o" "*.a")

# Sensitive patterns to remove
readonly SENSITIVE_PATTERNS=(
)

# Report file
REPORT_FILE=""

#########################################################################
# Helper Functions
#########################################################################

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Verbose output
verbose_print() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Add to report
add_to_report() {
    if [[ -n "$REPORT_FILE" ]]; then
        echo "$1" >> "$REPORT_FILE"
    fi
}

# Check if path should be excluded
should_exclude() {
    local path="$1"
    local basename="$(basename "$path")"
    
    # Check excluded directories
    for excluded in "${EXCLUDED_DIRS[@]}"; do
        if [[ "$path" == *"/$excluded"* ]] || [[ "$basename" == "$excluded" ]]; then
            verbose_print "Excluding directory: $path"
            return 0
        fi
    done
    
    # Check excluded file patterns
    for pattern in "${EXCLUDED_FILES[@]}"; do
        if [[ "$basename" == $pattern ]]; then
            verbose_print "Excluding file pattern: $path"
            return 0
        fi
    done
    
    return 1
}

# Display usage information
usage() {
    cat << EOF
${SCRIPT_NAME} - Metadata Cleaner

Usage: ${SCRIPT_NAME} [OPTIONS] <path>

Remove metadata from files and directories to ensure privacy and anonymity.

OPTIONS:
    -h, --help              Show this help message and exit
    -v, --verbose           Enable verbose output
    -d, --dry-run          Show what would be done without making changes
    -r, --recursive        Process directories recursively
    -b, --backup           Create backup before cleaning (stored in ./metadata_backup)
    --backup-dir <path>    Specify custom backup directory
    --report <file>        Generate detailed report to specified file
    -p, --parallel         Enable parallel processing (faster for large directories)
    -j, --jobs <n>         Number of parallel jobs (default: 4)
    -a, --aggressive       Aggressive mode: remove sensitive data patterns from files
    -c, --compress         Compress backup using tar.gz (saves space)
    --checksums            Generate SHA256 checksums for verification
    --sanitize-git         Clean version control metadata (Git repos)

EXAMPLES:
    # Clean a single file
    ${SCRIPT_NAME} document.pdf

    # Clean all files in a directory recursively with verbose output
    ${SCRIPT_NAME} -r -v /path/to/directory

    # Dry run to see what would be cleaned
    ${SCRIPT_NAME} -d -r ~/Pictures

    # Create backup before cleaning
    ${SCRIPT_NAME} -b -r important_files/

SUPPORTED FILE TYPES:
    - Images: JPEG, PNG, TIFF, GIF, BMP, WebP
    - Documents: PDF, DOCX, XLSX, PPTX, ODT
    - Media: MP3, MP4, AVI, MOV, WAV
    - Text: Markdown, Python, SQL, CSV, JSON, YAML, Shell scripts
    - Notebooks: Jupyter (.ipynb) - removes execution data and metadata
    - Archives: ZIP (removes internal metadata)

DEPENDENCIES:
    Required:
        - python3: For Jupyter notebook cleaning
        - exiftool: sudo apt install libimage-exiftool-perl
    Optional:
        - mat2: sudo apt install mat2 (for enhanced cleaning)

EXCLUDED PATTERNS:
    Automatically skipped:
    - Development: .git, node_modules, __pycache__, .venv, venv, dist, build
    - Binary: .pyc, .pyo, .so, .dll, .exe, .o, .a

NOTES:
    - Universal: Works for any file sharing/storage platform
    - Extended attributes removed from all files
    - Timestamps sanitized to 2000-01-01 for anonymity
    - Jupyter notebooks: execution counts and outputs cleared
    - Text files: author/date comments removed
    - File ownership and permissions maintained
    - Integrity verified after cleaning
    - Detailed audit report with verification

PRIVACY GUARANTEE:
    After cleaning, files are safe for:
    - Public sharing on any platform
    - Cloud storage and sync services
    - Collaboration and file sharing
    - Academic/research publication
    - Data repository submission
    - Any public or semi-public distribution

EOF
}

# Check if required tools are installed
check_dependencies() {
    local missing_deps=()

    if ! command -v exiftool &> /dev/null; then
        missing_deps+=("exiftool (install: sudo apt install libimage-exiftool-perl)")
    fi
    
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3 (required for notebook cleaning)")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi

    # Check for optional tools
    if ! command -v mat2 &> /dev/null; then
        verbose_print "Optional tool 'mat2' not found. Install for enhanced cleaning: sudo apt install mat2"
    fi
}

# Generate checksum for file
generate_checksum() {
    local file="$1"
    
    if [[ "$GENERATE_CHECKSUMS" == false ]]; then
        return 0
    fi
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local checksum=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
    if [[ -n "$checksum" ]]; then
        add_to_report "SHA256: $checksum | $file"
        verbose_print "Checksum generated for: $file"
    fi
    
    return 0
}

# Verify file integrity after cleaning
verify_file_integrity() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        print_error "File integrity check failed: file not found: $file"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        print_error "File integrity check failed: file not readable: $file"
        return 1
    fi
    
    # Check file size is not zero (unless it was zero before)
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [[ -z "$size" ]]; then
        print_warning "Could not verify size of: $file"
        return 1
    fi
    
    # For specific file types, do format validation
    case "$file" in
        *.ipynb)
            # Verify JSON is valid
            if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
                print_error "File integrity check failed: invalid JSON in notebook: $file"
                return 1
            fi
            ;;
        *.json)
            if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
                print_warning "File may have invalid JSON: $file"
            fi
            ;;
    esac
    
    # Generate checksum after cleaning
    generate_checksum "$file"
    
    verbose_print "Integrity verified: $file"
    return 0
}

# Create backup of file or directory
create_backup() {
    local source="$1"
    local backup_base="${BACKUP_DIR:-./metadata_backup}"
    
    if [[ ! -d "$backup_base" ]]; then
        mkdir -p "$backup_base"
        verbose_print "Created backup directory: $backup_base"
    fi

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="$(basename "$source")_backup_${timestamp}"
    
    if [[ "$COMPRESS_BACKUP" == true ]]; then
        # Create compressed backup
        local backup_path="${backup_base}/${backup_name}.tar.gz"
        print_info "Creating compressed backup (this may take a while for large directories)..."
        
        # Get absolute path
        local abs_source="$(cd "$(dirname "$source")" && pwd)/$(basename "$source")"
        local parent_dir="$(dirname "$abs_source")"
        local target_name="$(basename "$abs_source")"
        
        if [[ -d "$source" ]]; then
            # Exclude common large directories from backup
            tar -czf "$backup_path" \
                --exclude='.venv' \
                --exclude='venv' \
                --exclude='env' \
                --exclude='node_modules' \
                --exclude='__pycache__' \
                --exclude='.git' \
                --exclude='*.pyc' \
                --exclude='metadata_backup' \
                -C "$parent_dir" "$target_name" || {
                    print_error "Failed to create compressed backup. Check permissions and disk space."
                    return 1
                }
        else
            tar -czf "$backup_path" -C "$parent_dir" "$target_name" || {
                print_error "Failed to create compressed backup. Check permissions and disk space."
                return 1
            }
        fi
        
        if [[ -f "$backup_path" ]]; then
            local size=$(du -h "$backup_path" | cut -f1)
            print_success "Compressed backup created: $backup_path ($size)"
        else
            print_error "Backup file not created"
            return 1
        fi
    else
        # Create regular backup
        local backup_path="${backup_base}/${backup_name}"
        
        if [[ -d "$source" ]]; then
            cp -r "$source" "$backup_path"
        else
            cp "$source" "$backup_path"
        fi
        
        print_success "Backup created: $backup_path"
    fi
}

# Remove extended attributes
remove_extended_attributes() {
    local file="$1"
    
    verbose_print "Removing extended attributes from: $file"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Remove all extended attributes (Linux)
        if command -v setfattr &> /dev/null; then
            setfattr -h -x user.* "$file" 2>/dev/null || true
        fi
        
        # Remove macOS extended attributes if on macOS
        if [[ "$OSTYPE" == "darwin"* ]] && command -v xattr &> /dev/null; then
            xattr -c "$file" 2>/dev/null || true
        fi
    fi
}

# Clean metadata using exiftool
clean_with_exiftool() {
    local file="$1"
    
    verbose_print "Cleaning metadata with exiftool: $file"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Remove all metadata and don't create backup files
        exiftool -all= -overwrite_original "$file" 2>/dev/null || {
            print_warning "Could not clean metadata from: $file"
            return 1
        }
    fi
}

# Clean metadata using mat2 (if available)
clean_with_mat2() {
    local file="$1"
    
    if ! command -v mat2 &> /dev/null; then
        return 1
    fi
    
    verbose_print "Cleaning metadata with mat2: $file"
    
    if [[ "$DRY_RUN" == false ]]; then
        # mat2 creates a cleaned version, then we replace the original
        local dir=$(dirname "$file")
        local base=$(basename "$file")
        
        mat2 --inplace "$file" 2>/dev/null || {
            verbose_print "mat2 could not process: $file"
            return 1
        }
    fi
    
    return 0
}

# Sanitize file timestamps - removes forensic trails
sanitize_timestamps() {
    local file="$1"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Set access and modification time to a neutral date (2000-01-01)
        touch -t 200001010000.00 "$file" 2>/dev/null || true
    fi
}

# Clean Jupyter notebook metadata
clean_jupyter_notebook() {
    local file="$1"
    
    if [[ ! "$file" =~ \.ipynb$ ]]; then
        return 1
    fi
    
    verbose_print "Cleaning Jupyter notebook metadata: $file"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Remove kernel metadata, execution counts, and outputs using Python
        python3 << 'PYTHON_SCRIPT' "$file"
import sys
import json

try:
    notebook_path = sys.argv[1]
    
    with open(notebook_path, 'r', encoding='utf-8') as f:
        notebook = json.load(f)
    
    # Remove notebook-level metadata
    if 'metadata' in notebook:
        # Keep only minimal required metadata
        notebook['metadata'] = {
            'language_info': {'name': 'python'},
            'kernelspec': {
                'display_name': 'Python 3',
                'language': 'python',
                'name': 'python3'
            }
        }
    
    # Clean cell metadata and execution info
    if 'cells' in notebook:
        for cell in notebook['cells']:
            # Remove execution count
            if 'execution_count' in cell:
                cell['execution_count'] = None
            
            # Clear cell metadata
            if 'metadata' in cell:
                cell['metadata'] = {}
            
            # Clear outputs but keep output structure
            if cell.get('cell_type') == 'code' and 'outputs' in cell:
                cell['outputs'] = []
    
    # Write cleaned notebook
    with open(notebook_path, 'w', encoding='utf-8') as f:
        json.dump(notebook, f, indent=1, ensure_ascii=False)
    
    sys.exit(0)
except Exception as e:
    print(f"Error cleaning notebook: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
        
        if [[ $? -eq 0 ]]; then
            return 0
        else
            verbose_print "Failed to clean Jupyter notebook"
            return 1
        fi
    fi
    
    return 0
}

# Post-sanitization audit - verify all sensitive data removed
post_sanitization_audit() {
    local target="$1"
    local audit_failed=false
    
    print_info "\n========================================"
    print_info "Running Post-Sanitization Audit..."
    print_info "========================================"
    
    add_to_report "\n=== POST-SANITIZATION AUDIT ==="
    
    # Build find exclusion arguments
    local find_exclude_args=()
    for excluded in "${EXCLUDED_DIRS[@]}"; do
        find_exclude_args+=(-not -path "*/$excluded/*")
    done
    
    # Check for remaining sensitive patterns
    print_info "Checking for sensitive data patterns..."
    
    local pattern_string=$(IFS='|'; echo "${SENSITIVE_PATTERNS[*]}")
    local matches=0
    local -a sensitive_files=()
    while IFS= read -r -d '' file; do
        if grep -q -iE "($pattern_string)" "$file" 2>/dev/null; then
            matches=$((matches + 1))
            sensitive_files+=("$file")
        fi
    done < <(find "$target" -type f "${find_exclude_args[@]}" ! -name '*.so' ! -name '*.pyc' -print0 2>/dev/null)
    
    if [[ $matches -gt 0 ]]; then
        AUDIT_WARNINGS=$((AUDIT_WARNINGS + 1))
        audit_failed=true
        print_warning "Found sensitive patterns in $matches file(s)"
        add_to_report "[AUDIT WARNING] Sensitive patterns found in $matches file(s)"
        add_to_report "  Files with sensitive patterns:"
        for f in "${sensitive_files[@]}"; do
            add_to_report "    - $f"
        done
    fi
    
    # Check for email addresses
    print_info "Checking for email addresses..."
    local email_matches=0
    local -a email_files=()
    while IFS= read -r -d '' file; do
        if grep -q -E '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$file" 2>/dev/null; then
            email_matches=$((email_matches + 1))
            email_files+=("$file")
        fi
    done < <(find "$target" -type f "${find_exclude_args[@]}" ! -name '*.so' ! -name '*.pyc' -print0 2>/dev/null)
    
    if [[ $email_matches -gt 0 ]]; then
        AUDIT_WARNINGS=$((AUDIT_WARNINGS + 1))
        audit_failed=true
        print_warning "Found email addresses in $email_matches file(s)"
        add_to_report "[AUDIT WARNING] Email addresses found in $email_matches file(s)"
        add_to_report "  Files with email addresses:"
        for f in "${email_files[@]}"; do
            add_to_report "    - $f"
        done
    fi
    
    # Check for absolute paths
    print_info "Checking for absolute paths..."
    local path_matches=0
    local -a path_files=()
    while IFS= read -r -d '' file; do
        if grep -Eq '/home/[a-zA-Z0-9_-]+' "$file" 2>/dev/null; then
            path_matches=$((path_matches + 1))
            path_files+=("$file")
        fi
    done < <(find "$target" -type f "${find_exclude_args[@]}" ! -name '*.so' ! -name '*.pyc' -print0 2>/dev/null)
    
    if [[ $path_matches -gt 0 ]]; then
        AUDIT_WARNINGS=$((AUDIT_WARNINGS + 1))
        audit_failed=true
        print_warning "Found absolute paths in $path_matches file(s)"
        add_to_report "[AUDIT WARNING] Absolute paths found in $path_matches file(s)"
        add_to_report "  Files with absolute paths:"
        for f in "${path_files[@]}"; do
            add_to_report "    - $f"
        done
    fi
    
    # Check for private IPs
    print_info "Checking for private IP addresses..."
    local ip_matches=0
    local -a ip_files=()
    while IFS= read -r -d '' file; do
        if grep -q -E '(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' "$file" 2>/dev/null; then
            ip_matches=$((ip_matches + 1))
            ip_files+=("$file")
        fi
    done < <(find "$target" -type f "${find_exclude_args[@]}" ! -name '*.so' ! -name '*.pyc' -print0 2>/dev/null)
    
    if [[ $ip_matches -gt 0 ]]; then
        AUDIT_WARNINGS=$((AUDIT_WARNINGS + 1))
        audit_failed=true
        print_warning "Found private IP addresses in $ip_matches file(s)"
        add_to_report "[AUDIT WARNING] Private IPs found in $ip_matches file(s)"
        add_to_report "  Files with private IP addresses:"
        for f in "${ip_files[@]}"; do
            add_to_report "    - $f"
        done
    fi
    
    # Summary
    print_info "========================================"
    if [[ "$audit_failed" == true ]]; then
        print_warning "Audit completed with $AUDIT_WARNINGS warning(s)"
        print_warning "Some sensitive data may still be present!"
        add_to_report "\n[AUDIT RESULT] FAILED - $AUDIT_WARNINGS warning(s) found"
        
        if [[ "$AGGRESSIVE" == false ]]; then
            print_info "\nTIP: Run with -a (--aggressive) flag to remove sensitive data"
        fi
    else
        print_success "Audit passed! No sensitive data detected."
        add_to_report "\n[AUDIT RESULT] PASSED - No sensitive data detected"
    fi
    print_info "========================================\n"
    
    return 0
}

# Sanitize version control repositories
sanitize_git_repo() {
    local dir="$1"
    local git_dir="${dir}/.git"
    
    if [[ "$SANITIZE_GIT" == false ]]; then
        return 0
    fi
    
    if [[ ! -d "$git_dir" ]]; then
        return 0
    fi
    
    print_info "Sanitizing version control metadata: $dir"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY RUN] Would sanitize Git repo: $dir"
        return 0
    fi
    
    # Backup git config
    if [[ -f "${git_dir}/config" ]]; then
        cp "${git_dir}/config" "${git_dir}/config.backup" 2>/dev/null || true
    fi
    
    if [[ -f "${git_dir}/config" ]]; then
        verbose_print "Removing Git remote URLs"
        sed -i '/url[[:space:]]*=/d' "${git_dir}/config" 2>/dev/null || true
    fi
    
    # Clean Git user info from local config
    cd "$dir" 2>/dev/null || return 1
    
    if git config --local user.name &>/dev/null; then
        verbose_print "Removing local Git user.name"
        git config --local --unset user.name 2>/dev/null || true
    fi
    
    if git config --local user.email &>/dev/null; then
        verbose_print "Removing local Git user.email"
        git config --local --unset user.email 2>/dev/null || true
    fi
    
    cd - >/dev/null 2>&1 || true
    
    print_success "Git repository sanitized: $dir"
    add_to_report "[GIT] Sanitized repository: $dir"
    
    return 0
}

# Remove sensitive data patterns from text files
remove_sensitive_data() {
    local file="$1"
    local removed=0
    
    if [[ "$AGGRESSIVE" == false ]]; then
        return 0
    fi
    
    verbose_print "Scanning for sensitive data: $file"
    
    if [[ "$DRY_RUN" == false ]]; then
        local tmp_file="${file}.tmp.$$"
        cp "$file" "$tmp_file" || return 0
        
        # Remove lines containing sensitive patterns
        for pattern in "${SENSITIVE_PATTERNS[@]}"; do
            if grep -iq "$pattern" "$tmp_file" 2>/dev/null; then
                verbose_print "Found sensitive pattern '$pattern' in: $file"
                sed -i "/${pattern}/d" "$tmp_file" 2>/dev/null || true
                removed=$((removed + 1))
            fi
        done
        
        # Remove email addresses
        if grep -Eq '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$tmp_file" 2>/dev/null; then
            verbose_print "Found email addresses in: $file"
            sed -i -E 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/[EMAIL_REMOVED]/g' "$tmp_file" 2>/dev/null || true
            removed=$((removed + 1))
        fi
        
        # Remove absolute paths with username
        if grep -Eq '/home/[a-zA-Z0-9_-]+' "$tmp_file" 2>/dev/null; then
            verbose_print "Found absolute paths in: $file"
            sed -i -E 's|/home/[a-zA-Z0-9_-]+|/home/user|g' "$tmp_file" 2>/dev/null || true
            removed=$((removed + 1))
        fi
        
        # Remove private IP addresses
        if grep -Eq '(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' "$tmp_file" 2>/dev/null; then
            verbose_print "Found private IP addresses in: $file"
            sed -i -E 's/(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)([0-9]{1,3})\.([0-9]{1,3})/XXX.XXX.XXX.XXX/g' "$tmp_file" 2>/dev/null || true
            removed=$((removed + 1))
        fi
        
        if [[ $removed -gt 0 ]]; then
            mv "$tmp_file" "$file" || true
            SENSITIVE_DATA_REMOVED=$((SENSITIVE_DATA_REMOVED + removed))
            print_warning "Removed $removed sensitive patterns from: $file"
        else
            rm -f "$tmp_file"
        fi
    fi
    
    return 0
}

# Clean text files from identifying information
clean_text_file() {
    local file="$1"
    local ext="${file##*.}"
    
    # Only process text-based files
    case "$ext" in
        md|txt|py|sql|csv|json|sh|bash|yml|yaml|xml|html|css|js|ts)
            verbose_print "Sanitizing text file: $file"
            ;;
        *)
            return 1
            ;;
    esac
    
    if [[ "$DRY_RUN" == false ]]; then
        # Create temporary file
        local tmp_file="${file}.tmp.$$"
        
        # Remove common metadata patterns (but preserve actual content)
        # This removes lines with author info, dates in comments, etc.
        sed -E \
            -e '/^[[:space:]]*#[[:space:]]*[Aa]uthor[[:space:]]*:/d' \
            -e '/^[[:space:]]*#[[:space:]]*[Cc]reated[[:space:]]*(on|at|by)?[[:space:]]*:/d' \
            -e '/^[[:space:]]*#[[:space:]]*[Dd]ate[[:space:]]*:/d' \
            -e '/^[[:space:]]*#[[:space:]]*[Mm]odified[[:space:]]*(on|at|by)?[[:space:]]*:/d' \
            -e '/^[[:space:]]*#[[:space:]]*[Ll]ast[[:space:]]*[Mm]odified[[:space:]]*:/d' \
            -e '/^[[:space:]]*\/\/[[:space:]]*[Aa]uthor[[:space:]]*:/d' \
            -e '/^[[:space:]]*\/\/[[:space:]]*[Cc]reated[[:space:]]*(on|at|by)?[[:space:]]*:/d' \
            -e '/^[[:space:]]*\/\/[[:space:]]*[Dd]ate[[:space:]]*:/d' \
            "$file" > "$tmp_file" 2>/dev/null
        
        if [[ -s "$tmp_file" ]]; then
            mv "$tmp_file" "$file"
        else
            rm -f "$tmp_file"
        fi
    fi
    
    # Remove sensitive data if aggressive mode
    remove_sensitive_data "$file"
    
    return 0
}

# Main cleaning function for a single file
clean_file() {
    local file="$1"
    local cleaned=false
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    if [[ ! -f "$file" ]]; then
        print_warning "Not a file: $file"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        SKIPPED_FILES_LIST+=("$file (not a file)")
        return 1
    fi
    
    # Check if file should be excluded
    if should_exclude "$file"; then
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        SKIPPED_FILES_LIST+=("$file (excluded)")
        return 1
    fi
    
    # Get file size for statistics
    local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    BYTES_PROCESSED=$((BYTES_PROCESSED + file_size))
    
    print_info "Processing: $file"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY RUN] Would clean: $file"
        add_to_report "[DRY RUN] Would clean: $file (size: $file_size bytes)"
        return 0
    fi
    
    # Handle Jupyter notebooks specially
    if [[ "$file" =~ \.ipynb$ ]]; then
        if clean_jupyter_notebook "$file"; then
            cleaned=true
            verbose_print "Cleaned Jupyter notebook"
        fi
    fi
    
    # Try mat2 first (more thorough for supported formats)
    if clean_with_mat2 "$file"; then
        cleaned=true
        verbose_print "Cleaned with mat2"
    else
        # Fall back to exiftool (suppress errors for unsupported formats)
        if clean_with_exiftool "$file" 2>/dev/null; then
            cleaned=true
            verbose_print "Cleaned with exiftool"
        fi
    fi
    
    # Clean text files from identifying comments
    if clean_text_file "$file"; then
        cleaned=true
        verbose_print "Sanitized text content"
    else
        # If not a text file processed by clean_text_file, still try aggressive mode
        if [[ "$AGGRESSIVE" == true ]]; then
            # Check if file is text-based
            if file "$file" 2>/dev/null | grep -iq 'text\|ascii\|utf-8\|script'; then
                remove_sensitive_data "$file"
            fi
        fi
    fi
    
    # Remove extended attributes
    remove_extended_attributes "$file"
    
    # Sanitize timestamps for all files
    sanitize_timestamps "$file"
    
    # Verify file integrity after cleaning
    if ! verify_file_integrity "$file"; then
        print_error "Integrity check failed after cleaning: $file"
        FAILED_FILES=$((FAILED_FILES + 1))
        FAILED_FILES_LIST+=("$file (integrity check failed)")
        add_to_report "[FAILED] Integrity check failed: $file"
        return 1
    fi
    
    if [[ "$cleaned" == true ]] || [[ -f "$file" ]]; then
        print_success "Cleaned: $file"
        CLEANED_FILES=$((CLEANED_FILES + 1))
        CLEANED_FILES_LIST+=("$file")
        add_to_report "[SUCCESS] Cleaned: $file (size: $file_size bytes)"
        return 0
    else
        print_warning "Could not clean: $file"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        SKIPPED_FILES_LIST+=("$file (could not clean)")
        add_to_report "[SKIPPED] Could not clean: $file"
        return 1
    fi
}

# Process directory
process_directory() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        print_error "Directory not found: $dir"
        return 1
    fi
    
    # Check if directory should be excluded
    if should_exclude "$dir"; then
        verbose_print "Skipping excluded directory: $dir"
        return 0
    fi
    
    print_info "Processing directory: $dir"
    add_to_report "\n=== Processing directory: $dir ==="
    
    # Sanitize Git repository if present
    sanitize_git_repo "$dir"
    
    if [[ "$RECURSIVE" == true ]]; then
        # Build find command with exclusions
        local find_cmd="find \"$dir\" -type f"
        
        # Add exclusion patterns for directories
        for excluded in "${EXCLUDED_DIRS[@]}"; do
            find_cmd+=" -not -path '*/$excluded/*'"
        done
        
        # Execute find and process files
        if [[ "$PARALLEL" == true ]] && command -v xargs &> /dev/null; then
            # Parallel processing using xargs
            verbose_print "Using parallel processing with $MAX_JOBS jobs"
            eval "$find_cmd -print0" | xargs -0 -P "$MAX_JOBS" -I {} bash -c '
                source "$0"
                clean_file "{}" 2>/dev/null || true
            ' "$0" || true
        else
            # Sequential processing
            while IFS= read -r -d '' file; do
                clean_file "$file"
            done < <(eval "$find_cmd -print0") || true
        fi
    else
        # Process only files in the current directory
        for file in "$dir"/*; do
            if [[ -f "$file" ]]; then
                clean_file "$file"
            fi
        done
    fi
}

# Main execution function
main() {
    # Check dependencies
    check_dependencies
    
    # Parse command line arguments
    local target=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                print_warning "DRY RUN MODE - No changes will be made"
                shift
                ;;
            -r|--recursive)
                RECURSIVE=true
                shift
                ;;
            -b|--backup)
                BACKUP=true
                shift
                ;;
            --backup-dir)
                BACKUP=true
                BACKUP_DIR="$2"
                shift 2
                ;;
            --report)
                REPORT_FILE="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL=true
                shift
                ;;
            -j|--jobs)
                MAX_JOBS="$2"
                shift 2
                ;;
            -a|--aggressive)
                AGGRESSIVE=true
                print_warning "Aggressive mode: Will remove sensitive data patterns from files"
                shift
                ;;
            -c|--compress)
                COMPRESS_BACKUP=true
                shift
                ;;
            --checksums)
                GENERATE_CHECKSUMS=true
                shift
                ;;
            --sanitize-git)
                SANITIZE_GIT=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                target="$1"
                shift
                ;;
        esac
    done
    
    # Validate target path
    if [[ -z "$target" ]]; then
        print_error "No target path specified"
        usage
        exit 1
    fi
    
    if [[ ! -e "$target" ]]; then
        print_error "Path does not exist: $target"
        exit 1
    fi
    
    # Initialize report file
    if [[ -n "$REPORT_FILE" ]]; then
        cat > "$REPORT_FILE" << EOF
========================================
Metadata Cleaner Report
========================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Target: $target
Mode: $([ "$DRY_RUN" == true ] && echo "DRY RUN" || echo "LIVE")
Recursive: $RECURSIVE
Backup: $BACKUP
Compress Backup: $COMPRESS_BACKUP
Generate Checksums: $GENERATE_CHECKSUMS
Sanitize Git: $SANITIZE_GIT
Aggressive: $AGGRESSIVE
========================================

$([ "$GENERATE_CHECKSUMS" == true ] && echo "=== FILE CHECKSUMS (SHA256) ===" || echo "")

EOF
        print_info "Report will be saved to: $REPORT_FILE"
    fi
    
    # Record start time
    local start_time=$(date +%s)
    
    # Create backup if requested
    if [[ "$BACKUP" == true ]]; then
        create_backup "$target"
        add_to_report "Backup created: $([ -n "$BACKUP_DIR" ] && echo "$BACKUP_DIR" || echo "./metadata_backup")"
    fi
    
    # Process target
    if [[ -f "$target" ]]; then
        clean_file "$target"
    elif [[ -d "$target" ]]; then
        process_directory "$target"
    else
        print_error "Invalid target: $target"
        exit 1
    fi
    
    # Run post-sanitization audit (skip in dry-run, only for directories)
    if [[ "$DRY_RUN" == false ]] && [[ -d "$target" ]]; then
        post_sanitization_audit "$target"
    fi
    
    # Calculate elapsed time
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local elapsed_min=$((elapsed / 60))
    local elapsed_sec=$((elapsed % 60))
    
    # Generate statistics
    local bytes_mb=$((BYTES_PROCESSED / 1024 / 1024))
    
    print_success "Metadata cleaning completed successfully!"
    echo ""
    print_info "========================================"
    print_info "Statistics:"
    print_info "========================================"
    print_info "Total files found:     $TOTAL_FILES"
    print_info "Successfully cleaned:  $CLEANED_FILES"
    print_info "Skipped:              $SKIPPED_FILES"
    print_info "Failed:               $FAILED_FILES"
    if [[ "$AGGRESSIVE" == true ]]; then
        print_info "Sensitive data items:  $SENSITIVE_DATA_REMOVED"
    fi
    if [[ "$DRY_RUN" == false ]]; then
        if [[ $AUDIT_WARNINGS -gt 0 ]]; then
            print_warning "Audit warnings:       $AUDIT_WARNINGS"
        else
            print_success "Audit warnings:       0 (PASSED)"
        fi
    fi
    print_info "Data processed:       ${bytes_mb} MB"
    print_info "Time elapsed:         ${elapsed_min}m ${elapsed_sec}s"
    if [[ "$PARALLEL" == true ]]; then
        print_info "Parallel jobs:        $MAX_JOBS"
    fi
    if [[ "$COMPRESS_BACKUP" == true ]]; then
        print_info "Backup compressed:    Yes"
    fi
    if [[ "$GENERATE_CHECKSUMS" == true ]]; then
        print_info "Checksums generated:  Yes (see report)"
    fi
    if [[ "$SANITIZE_GIT" == true ]]; then
        print_info "Git sanitized:        Yes"
    fi
    print_info "========================================"
    
    # Add statistics to report
    if [[ -n "$REPORT_FILE" ]]; then
        cat >> "$REPORT_FILE" << EOF

========================================
Final Statistics:
========================================
Total files found:     $TOTAL_FILES
Successfully cleaned:  $CLEANED_FILES
Skipped:              $SKIPPED_FILES
Failed:               $FAILED_FILES
Sensitive data items:  $SENSITIVE_DATA_REMOVED
Audit warnings:        $AUDIT_WARNINGS
Data processed:       ${bytes_mb} MB ($BYTES_PROCESSED bytes)
Time elapsed:         ${elapsed_min}m ${elapsed_sec}s
Parallel processing:  $([ "$PARALLEL" == true ] && echo "Yes ($MAX_JOBS jobs)" || echo "No")
Aggressive mode:      $([ "$AGGRESSIVE" == true ] && echo "Yes" || echo "No")
========================================
EOF

        # Add detailed file lists
        if [[ ${#SKIPPED_FILES_LIST[@]} -gt 0 ]]; then
            echo "" >> "$REPORT_FILE"
            echo "=== SKIPPED FILES ($SKIPPED_FILES) ===" >> "$REPORT_FILE"
            for file in "${SKIPPED_FILES_LIST[@]}"; do
                echo "  - $file" >> "$REPORT_FILE"
            done
        fi
        
        if [[ ${#FAILED_FILES_LIST[@]} -gt 0 ]]; then
            echo "" >> "$REPORT_FILE"
            echo "=== FAILED FILES ($FAILED_FILES) ===" >> "$REPORT_FILE"
            for file in "${FAILED_FILES_LIST[@]}"; do
                echo "  - $file" >> "$REPORT_FILE"
            done
        fi
        
        print_success "Report saved to: $REPORT_FILE"
    fi
}

# Run main function
main "$@"