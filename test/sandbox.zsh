#!/usr/bin/env zsh
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#        File:  sandbox.zsh
#
#        Name:  MacSync Sandbox
# Description:  Creates an isolated test environment for manual testing
#
#      Usage:  ./test/sandbox.zsh [command]
#
#    Commands:
#      start   - Create sandbox and enter interactive shell
#      clean   - Remove sandbox environment
#      reset   - Clean and start fresh
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Note: Intentionally not using 'set -e' as it can cause unexpected exits
# in interactive contexts (e.g., subshell with zsh -i)

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
SANDBOX_DIR="/tmp/macsync-sandbox"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

#######################################
# Create sandbox environment
#######################################
create_sandbox() {
  echo "${CYAN}Creating sandbox environment...${NC}"
  
  # Create directories (cloud inside home so ${HOME}/cloud works)
  mkdir -p "${SANDBOX_DIR}/home/cloud"
  
  # Create sample dotfiles
  echo "# Test .zshrc" > "${SANDBOX_DIR}/home/.zshrc"
  echo "# Test .gitconfig" > "${SANDBOX_DIR}/home/.gitconfig"
  mkdir -p "${SANDBOX_DIR}/home/.config/test"
  echo "test config" > "${SANDBOX_DIR}/home/.config/test/settings.cfg"
  
  # Create pre-configured config
  mkdir -p "${SANDBOX_DIR}/home/.macsync"
  cat > "${SANDBOX_DIR}/home/.macsync/config.cfg" << 'EOF'
# Sandbox test config
_NAME_PC="SandboxPC"
_BACKUP_DEFAULT_FOLDER="_Backup/${_NAME_PC}_$(date +'%d-%m-%Y')_$(date +%s)"
SYNC_FOLDER="${HOME}/cloud"
BACKUP_FILES=(.zshrc .gitconfig .config/test)
LOG_ENABLED=true
LOG_FILE="${HOME}/.macsync/macsync.log"
EOF

  echo "${GREEN}✓ Sandbox created at: ${SANDBOX_DIR}${NC}"
}

#######################################
# Enter sandbox shell
#######################################
enter_sandbox() {
  echo ""
  echo "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo "${YELLOW}║                    MACSYNC SANDBOX MODE                      ║${NC}"
  echo "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
  echo "${YELLOW}║  HOME=${SANDBOX_DIR}/home${NC}"
  echo "${YELLOW}║  Cloud=${SANDBOX_DIR}/home/cloud${NC}"
  echo "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
  echo "${YELLOW}║  Commands:                                                   ║${NC}"
  echo "${YELLOW}║    macsync           - Run MacSync                           ║${NC}"
  echo "${YELLOW}║    macsync --dry-run - Preview changes                       ║${NC}"
  echo "${YELLOW}║    ls -la ~/         - View home files                       ║${NC}"
  echo "${YELLOW}║    ls -la ~/cloud/   - View sync folder                      ║${NC}"
  echo "${YELLOW}║    exit              - Leave sandbox                         ║${NC}"
  echo "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  
  # Start subshell with modified HOME
  # Unset DRY_RUN to prevent accidental dry-run mode
  HOME="${SANDBOX_DIR}/home" \
  PATH="${PROJECT_ROOT}/bin:${PATH}" \
  PROMPT="%F{cyan}[sandbox]%f %~ %# " \
  DRY_RUN= \
  zsh -i
}

#######################################
# Clean sandbox
#######################################
clean_sandbox() {
  if [[ -d "${SANDBOX_DIR}" ]]; then
    echo "${YELLOW}Removing sandbox...${NC}"
    rm -rf "${SANDBOX_DIR}"
    echo "${GREEN}✓ Sandbox cleaned${NC}"
  else
    echo "${YELLOW}No sandbox to clean${NC}"
  fi
}

#######################################
# Show usage
#######################################
show_usage() {
  echo "MacSync Sandbox - Isolated testing environment"
  echo ""
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  start   Create sandbox and enter interactive shell (default)"
  echo "  clean   Remove sandbox environment"
  echo "  reset   Clean and start fresh"
  echo ""
  echo "Example:"
  echo "  $0 start   # Enter sandbox"
  echo "  $0 reset   # Start fresh"
}

#######################################
# Main
#######################################
case "${1:-start}" in
  start)
    if [[ ! -d "${SANDBOX_DIR}" ]]; then
      create_sandbox
    else
      echo "${YELLOW}Using existing sandbox at: ${SANDBOX_DIR}${NC}"
    fi
    enter_sandbox
    ;;
  clean)
    clean_sandbox
    ;;
  reset)
    clean_sandbox
    create_sandbox
    enter_sandbox
    ;;
  -h|--help|help)
    show_usage
    ;;
  *)
    echo "${RED}Unknown command: ${1}${NC}"
    show_usage
    exit 1
    ;;
esac
