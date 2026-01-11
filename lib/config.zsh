#!/usr/bin/env zsh
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#        File:  config.zsh
#
#        Name:  MacSync Config
# Description:  Configuration management for MacSync
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Enable zsh emulation for compatibility
emulate -L zsh

# Config paths (exported for use in other modules)
export MACSYNC_CONFIG_DIR="${HOME}/.macsync"
export MACSYNC_CONFIG_FILE="${MACSYNC_CONFIG_DIR}/config.cfg"
export MACSYNC_DEFAULT_CONFIG="${MACSYNC_ROOT}/config/config.cfg.default"

#######################################
# Initialize config directory and file on first run.
# Creates ~/.macsync/ and copies default config if needed.
# Returns:
#   0 if config exists or was created
#   1 if default config is missing
#######################################
init_config() {
  # Create config directory if needed
  if [[ ! -d "${MACSYNC_CONFIG_DIR}" ]]; then
    mkdir -p "${MACSYNC_CONFIG_DIR}"
  fi

  # Copy default config if user config doesn't exist
  if [[ ! -f "${MACSYNC_CONFIG_FILE}" ]]; then
    if [[ -f "${MACSYNC_DEFAULT_CONFIG}" ]]; then
      cp "${MACSYNC_DEFAULT_CONFIG}" "${MACSYNC_CONFIG_FILE}"
      
      # We need to inform the user, but we should do it cleanly.
      # Ideally, the main program handles the "first run" welcome message,
      # but we'll leave a return code to indicate "just created".
      # For now, we'll keep the output here but make it nicer later if needed.
      echo "${colorGreen:-}${bold:-}Welcome to MacSync!${reset:-}"
      echo ""
      echo "A default config has been created at:"
      echo "  ${colorCyan:-}${MACSYNC_CONFIG_FILE}${reset:-}"
      echo ""
      echo "${colorYellow:-}Please edit this file to configure your sync settings:${reset:-}"
      echo "  1. Set SYNC_FOLDER to your cloud storage path"
      echo "  2. Set BACKUP_FILES to the files you want to sync"
      return 2 # Special code: Config just created
    else
      echo "${colorRed:-}Error: Default config not found at ${MACSYNC_DEFAULT_CONFIG}${reset:-}" >&2
      return 1
    fi
  fi
  return 0
}

#######################################
# Validate required config fields are filled.
# Expands SYNC_FOLDER path and validates parent exists.
# Globals:
#   SYNC_FOLDER
#   _NAME_PC
#   _BACKUP_DEFAULT_FOLDER
#   BACKUP_FILES
# Returns:
#   0 on success
#   1 on failure
#######################################
validate_config() {
  # Check required string variables
  local required_strings=(SYNC_FOLDER _NAME_PC _BACKUP_DEFAULT_FOLDER)
  local missing=false

  for var in "${required_strings[@]}"; do
    if [[ -z "${(P)var}" ]]; then
      echo "${colorRed:-}Error: Config variable '${var}' is empty.${reset:-}" >&2
      missing=true
    fi
  done

  # Check BACKUP_FILES array separately (string check doesn't work for arrays)
  if (( ${#BACKUP_FILES[@]} == 0 )); then
    echo "${colorRed:-}Error: Config variable 'BACKUP_FILES' is empty.${reset:-}" >&2
    missing=true
  fi

  if [[ "$missing" == "true" ]]; then
      echo "Config location: ${MACSYNC_CONFIG_FILE}"
      return 1
  fi

  # Expand SYNC_FOLDER path (handle ~) manually if needed, 
  # though zsh usually handles it if unquoted in assignment.
  # But we want to be safe with the variable content.
  # The :A modifier resolves paths.
  SYNC_FOLDER="${SYNC_FOLDER/#\~/$HOME}" 
  
  # Export it back so other modules see the expanded path
  export SYNC_FOLDER

  # Safety check: Prevent SYNC_FOLDER from being root or home
  # This prevents catastrophic data loss if rm -rf is used on the sync folder
  if [[ "${SYNC_FOLDER}" == "/" || "${SYNC_FOLDER}" == "${HOME}" ]]; then
    echo "${colorRed:-}Error: SYNC_FOLDER cannot be root ('/') or your home directory ('${HOME}').${reset:-}" >&2
    echo "Please set a specific subdirectory for synchronization (e.g., ~/Dropbox/MacSync)."
    return 1
  fi

  # Validate SYNC_FOLDER parent directory exists
  local sync_parent="${SYNC_FOLDER:h}"
  if [[ ! -d "${sync_parent}" ]]; then
    echo "${colorRed:-}Error: Sync folder parent directory does not exist: ${sync_parent}${reset:-}" >&2
    echo "Please create it or update SYNC_FOLDER in config.cfg"
    return 1
  fi

  return 0
}
