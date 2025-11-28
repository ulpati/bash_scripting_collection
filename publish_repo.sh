#!/bin/bash

#########################################################################
# Publish Repository Script
#
# Purpose:
#   Helper script to initialize a Git repository (if needed), add or
#   update the origin remote, optionally create a GitHub repository via
#   the gh CLI, and push the main branch.
#
# License: CC BY-NC-SA 4.0
#
# Usage:
#   ./publish_repo.sh [OPTIONS]
#
# Documentation:
#   See `publish_repo.md` for full usage, options, dependencies,
#   installation instructions, and examples.
#
#########################################################################

set -euo pipefail
IFS=$'\n\t'

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

readonly SCRIPT_NAME="publish_repo.sh"
readonly DEFAULT_BRANCH="main"
 

# Flags / options
DRY_RUN=0
CREATE_REMOTE=0
REMOTE_URL=""
REPO_NAME=""
PUBLIC=0
VERBOSE=false

print_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
print_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
verbose_print() { if [[ "$VERBOSE" == true ]]; then echo -e "${BLUE}[VERBOSE]${NC} $*"; fi }

die() { print_error "$*"; exit 1; }

# Run a command or print it in dry-run mode
run_cmd() {
  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "+ $*"
  else
    eval "$@"
  fi
}

show_help() {
  cat <<EOF
${SCRIPT_NAME} - Initialize / publish repository to GitHub

Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
  --remote URL       Use an existing remote URL ([EMAIL_REMOVED]:USER/REPO.git or https://...)
  --create           Create a GitHub repo using 'gh repo create' (requires gh CLI and auth)
  --name NAME        Repository name to create (used with --create)
  --public           Create public repo when using --create (default is private)
  --dry-run          Print commands without running them
  -v, --verbose      Enable verbose output
  --help, -h         Show this help

Examples:
  # Add or update remote and push
  ./publish_repo.sh --remote [EMAIL_REMOVED]:USERNAME/REPO.git

  # Create a new GitHub repo (requires gh)
  ./publish_repo.sh --create --name my-repo --public

  # Dry run to preview actions
  ./publish_repo.sh --remote [EMAIL_REMOVED]:USER/REPO.git --dry-run

EOF
}

# Parse args
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --remote)
      REMOTE_URL="$2"; shift 2;;
    --create)
      CREATE_REMOTE=1; shift;;
    --name)
      REPO_NAME="$2"; shift 2;;
    --public)
      PUBLIC=1; shift;;
    --dry-run)
      DRY_RUN=1; shift;;
    -v|--verbose)
      VERBOSE=true; shift;;
    --help|-h)
      show_help; exit 0;;
    *) die "Unknown argument: $1";;
  esac
done

# Ensure git is available
command -v git >/dev/null 2>&1 || die "git is not installed"

# Work from the repository root (allow running the script from any cwd)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")"
cd "${REPO_ROOT}"
print_info "Repository root: ${REPO_ROOT}"

# Initialize repository if needed
if [[ ! -d .git ]]; then
  print_info "Initializing git repository..."
  run_cmd "git init"
fi

# Ensure there is at least one commit
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  print_info "No commits found — creating initial commit"
  if [[ ! -f .gitignore ]]; then
    run_cmd "touch .gitignore"
  fi
  run_cmd "git add .gitignore"
  run_cmd "git commit -m 'chore: initial commit (created by ${SCRIPT_NAME})' --no-verify || true"
fi

# Create remote repository using gh if requested
if [[ ${CREATE_REMOTE} -eq 1 ]]; then
  command -v gh >/dev/null 2>&1 || die "GitHub CLI 'gh' not found — install and authenticate or pass --remote"
  if [[ -z "${REPO_NAME}" ]]; then
    die "--name is required when using --create"
  fi
  GH_VISIBILITY="--private"
  if [[ ${PUBLIC} -eq 1 ]]; then
    GH_VISIBILITY="--public"
  fi
  print_info "Creating GitHub repo '${REPO_NAME}' (${GH_VISIBILITY}) with gh..."
  run_cmd "gh repo create ${REPO_NAME} ${GH_VISIBILITY} --source=. --remote=origin --push --confirm"
  print_success "Remote 'origin' created and pushed via gh."
  exit 0
fi

REMOTE_WILL_BE_CONFIGURED=0
# Add or update remote origin when provided
if [[ -n "${REMOTE_URL}" ]]; then
  if git remote get-url origin >/dev/null 2>&1; then
    existing_url=$(git remote get-url origin)
    print_info "Remote 'origin' already exists: ${existing_url}"
    print_info "Updating 'origin' to ${REMOTE_URL}"
    run_cmd "git remote set-url origin ${REMOTE_URL}"
    REMOTE_WILL_BE_CONFIGURED=1
  else
    print_info "Adding remote origin -> ${REMOTE_URL}"
    run_cmd "git remote add origin ${REMOTE_URL}"
    # In dry-run mode the remote won't actually be added; mark as intended
    if [[ ${DRY_RUN} -eq 1 ]]; then
      REMOTE_WILL_BE_CONFIGURED=1
    fi
  fi
fi

# Ensure branch name and push
print_info "Ensuring branch '${DEFAULT_BRANCH}' exists and pushing to origin..."
run_cmd "git branch -M ${DEFAULT_BRANCH} || true"
# Treat remote as configured if:
# - git reports an origin remote, OR
# - we are in dry-run and we have an intended remote (REMOTE_WILL_BE_CONFIGURED=1), OR
# - we are in dry-run and CREATE_REMOTE=1 (gh create would push)
if git remote get-url origin >/dev/null 2>&1 || [[ ${DRY_RUN} -eq 1 && ${REMOTE_WILL_BE_CONFIGURED} -eq 1 ]] || [[ ${DRY_RUN} -eq 1 && ${CREATE_REMOTE} -eq 1 ]]; then
  run_cmd "git add -A"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    # In dry-run we cannot reliably inspect the index; just show the commit command
    run_cmd "git commit -m 'chore: publish repository (auto commit)' --no-verify || true"
  else
    if ! git diff --cached --quiet; then
      run_cmd "git commit -m 'chore: publish repository (auto commit)' --no-verify || true"
    fi
  fi
  run_cmd "git push -u origin ${DEFAULT_BRANCH}"
  print_success "Pushed to origin/${DEFAULT_BRANCH}"
else
  print_warning "No remote configured. Provide --remote URL or use --create with gh to create a GitHub repo."
fi

print_success "Done."
