#!/usr/bin/env bash
# Test helper for MacSync bats tests

# Get the directory of this script
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"

# Path to macsync executable
MACSYNC="${PROJECT_ROOT}/bin/macsync"

# Temporary directory for test configs
TEST_TEMP_DIR=""

# Setup function - called before each test
setup() {
  # Create a temporary directory for test data
  TEST_TEMP_DIR="$(mktemp -d)"
  
  # Create a mock config directory
  export HOME="${TEST_TEMP_DIR}/home"
  mkdir -p "${HOME}/.macsync"
  
  # Create a minimal test config
  # Note: 'EOF' (single-quoted) prevents variable expansion in heredoc.
  # ${HOME} is intentionally literal - zsh expands it when config is sourced.
  cat > "${HOME}/.macsync/config.cfg" << 'EOF'
SYNC_FOLDER="${HOME}/TestSyncFolder"
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC"
BACKUP_FILES=(.testfile)
LOG_ENABLED=false
EOF

  # Create the sync folder
  mkdir -p "${HOME}/TestSyncFolder"
  
  # Create a test file to sync
  echo "test content" > "${HOME}/.testfile"
}

# Teardown function - called after each test
teardown() {
  # Clean up temporary directory
  if [[ -n "${TEST_TEMP_DIR}" && -d "${TEST_TEMP_DIR}" ]]; then
    rm -rf "${TEST_TEMP_DIR}"
  fi
}

#######################################
# Create a test config with customizable options
# Arguments:
#   $1 - sync_folder (default: TestSyncFolder)
#   $2 - backup_files (default: .testfile)
#   $3 - log_enabled (default: false)
#######################################
create_test_config() {
  local sync_folder="${1:-TestSyncFolder}"
  local backup_files="${2:-.testfile}"
  local log_enabled="${3:-false}"
  
  cat > "${HOME}/.macsync/config.cfg" << EOF
SYNC_FOLDER="\${HOME}/${sync_folder}"
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC"
BACKUP_FILES=(${backup_files})
LOG_ENABLED=${log_enabled}
EOF
}

#######################################
# Setup standard sync environment
# Creates config and test file
#######################################
setup_sync_env() {
  create_test_config
  mkdir -p "${HOME}/TestSyncFolder"
  # Remove any existing dotfiles folder for clean slate
  rm -rf "${HOME}/TestSyncFolder/dotfiles"
  echo "test content" > "${HOME}/.testfile"
}

#######################################
# Setup environment for replace/update tests
# Used after first sync to re-test
#######################################
setup_replace_env() {
  # Remove the symlink and create a new regular file
  rm -f "${HOME}/.testfile"
  echo "new test content" > "${HOME}/.testfile"
  
  create_test_config
}

#######################################
# Assert file is a symlink
# Arguments:
#   $1 - File path
#######################################
assert_symlink() {
  [ -L "$1" ] || fail "Expected $1 to be a symlink"
}

#######################################
# Assert file is NOT a symlink
# Arguments:
#   $1 - File path
#######################################
assert_not_symlink() {
  [ ! -L "$1" ] || fail "Expected $1 to NOT be a symlink"
}

#######################################
# Assert file exists
# Arguments:
#   $1 - File path
#######################################
assert_exists() {
  [ -e "$1" ] || fail "Expected $1 to exist"
}

#######################################
# Assert file does not exist
# Arguments:
#   $1 - File path
#######################################
assert_not_exists() {
  [ ! -e "$1" ] || fail "Expected $1 to NOT exist"
}
