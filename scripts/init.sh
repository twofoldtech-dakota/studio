#!/usr/bin/env bash
#
# STUDIO Project Initialization
# ==============================
#
# Creates the required directory structure for STUDIO to function.
# Safe to run multiple times - only creates directories that don't exist.
#
# Usage:
#   ./init.sh                    Initialize with default .studio directory
#   STUDIO_DIR=.my-studio ./init.sh  Initialize with custom directory
#

set -euo pipefail

# Configuration
STUDIO_DIR="${STUDIO_DIR:-.studio}"

# Colors (only if terminal supports them)
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    GREEN='' CYAN='' NC=''
fi

log_init() { echo -e "${CYAN}[STUDIO Init]${NC} $*"; }
log_success() { echo -e "${GREEN}[STUDIO Init]${NC} $*"; }

# Create directory structure
log_init "Initializing STUDIO directory structure..."

mkdir -p "$STUDIO_DIR/tasks"
mkdir -p "$STUDIO_DIR/orchestration"
mkdir -p "$STUDIO_DIR/.cache/summaries"

log_success "STUDIO initialized. Created:"
echo "  - $STUDIO_DIR/tasks/"
echo "  - $STUDIO_DIR/orchestration/"
echo "  - $STUDIO_DIR/.cache/summaries/"
