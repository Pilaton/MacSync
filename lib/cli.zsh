#!/usr/bin/env zsh
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#        File:  cli.zsh
#
#        Name:  MacSync
# Description:  Command-line argument parser
#
#      Author:  Pilaton
#      GitHub:  https://github.com/Pilaton/MacSync
#        Bugs:  https://github.com/Pilaton/MacSync/issues
#     License:  MIT
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Enable zsh emulation for compatibility
emulate -L zsh

# CLI flags (defaults)
DRY_RUN=false
VERBOSE=false
QUIET=false
SHOW_HELP=false
SHOW_VERSION=false

# CLI overrides (empty = use config)
CLI_SYNC_FOLDER=""
CLI_BACKUP_FILES=()

#######################################
# Check if running in dry-run mode
# Returns:
#   0 if dry-run is enabled, 1 otherwise
#######################################
is_dry_run() {
  [[ "${DRY_RUN:-false}" == "true" ]]
}

#######################################
# Parse command-line arguments
# Arguments:
#   $@ - All command-line arguments
# Globals:
#   DRY_RUN, VERBOSE, QUIET, SHOW_HELP, SHOW_VERSION
#   CLI_SYNC_FOLDER, CLI_BACKUP_FILES
#######################################
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      -n|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      -q|--quiet)
        QUIET=true
        shift
        ;;
      -h|--help)
        SHOW_HELP=true
        shift
        ;;
      --version)
        SHOW_VERSION=true
        shift
        ;;
      -s|--sync-folder)
        if [[ -n "${2}" && "${2}" != -* ]]; then
          CLI_SYNC_FOLDER="${2:A}"
          shift 2
        else
          echo "${colorRed:-}Error: --sync-folder requires a path argument${reset:-}" >&2
          exit 1
        fi
        ;;
      -f|--files)
        if [[ -n "${2}" && "${2}" != -* ]]; then
          # Split comma-separated list into array
          # Keep paths relative (not absolute) since macsync does cd ~ first
          IFS=',' read -rA CLI_BACKUP_FILES <<< "${2}"
          shift 2
        else
          echo "${colorRed:-}Error: --files requires a comma-separated list${reset:-}" >&2
          exit 1
        fi
        ;;
      -*)
        echo "${colorRed:-}Error: Unknown option: ${1}${reset:-}" >&2
        echo "Use --help to see available options." >&2
        exit 1
        ;;
      *)
        # Positional argument (ignore for now)
        shift
        ;;
    esac
  done

  # Quiet mode disables verbose
  if [[ "${QUIET}" == "true" ]]; then
    VERBOSE=false
  fi
}

#######################################
# Apply CLI overrides to config variables
# Globals:
#   CLI_SYNC_FOLDER, CLI_BACKUP_FILES
#   SYNC_FOLDER, BACKUP_FILES
#######################################
apply_cli_overrides() {
  if [[ -n "${CLI_SYNC_FOLDER}" ]]; then
    SYNC_FOLDER="${CLI_SYNC_FOLDER}"
  fi

  if (( ${#CLI_BACKUP_FILES[@]} > 0 )); then
    BACKUP_FILES=("${CLI_BACKUP_FILES[@]}")
  fi
}

#######################################
# Show help message
#######################################
show_help() {
  cat << 'EOF'
MacSync - Easy sync for macOS

USAGE:
    macsync [OPTIONS]

OPTIONS:
    -n, --dry-run           Preview changes without applying them
    -v, --verbose           Enable verbose output
    -q, --quiet             Minimal output (suppress non-essential messages)
    -s, --sync-folder PATH  Override sync folder path
    -f, --files LIST        Override files to sync (comma-separated)
    -h, --help              Show this help message
        --version           Show version information

EXAMPLES:
    macsync --dry-run                         # Preview changes
    macsync --sync-folder ~/Dropbox/MySync    # Custom sync folder
    macsync --files ".zshrc,.gitconfig"       # Sync specific files

CONFIG:
    ~/.macsync/config.cfg                     # User configuration

For more information, visit: https://github.com/Pilaton/MacSync
EOF
}

#######################################
# Show version information
#######################################
show_version() {
  local version="unknown"
  
  # Read version from VERSION file
  if [[ -f "${MACSYNC_ROOT:-}/VERSION" ]]; then
    # Use Zsh optimized file reading ($<file) and parameter expansion for trimming
    version=${$(<"${MACSYNC_ROOT}/VERSION")//[[:space:]]/}
  fi

  echo "MacSync version ${version}"
}

#######################################
# Print message respecting quiet mode
# Arguments:
#   $1 - Message
# Globals:
#   QUIET
#######################################
print_msg() {
  [[ "${QUIET}" == "true" ]] && return 0
  echo "${1}"
}

#######################################
# Print verbose message
# Arguments:
#   $1 - Message
# Globals:
#   VERBOSE
#######################################
print_verbose() {
  [[ "${VERBOSE}" != "true" ]] && return 0
  echo "${colorCyan:-}[VERBOSE]${reset:-} ${1}"
}

#######################################
# Print dry-run prefix for actions
# Arguments:
#   $1 - Action description
# Globals:
#   DRY_RUN
#######################################
print_dry_run() {
  if is_dry_run; then
    echo "${colorYellow:-}[DRY-RUN]${reset:-} Would ${1}"
  fi
}
