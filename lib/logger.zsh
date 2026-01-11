#!/usr/bin/env zsh
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#        File:  logger.zsh
#
#        Name:  MacSync
# Description:  Logging module with automatic rotation
#
#      Author:  Pilaton
#      GitHub:  https://github.com/Pilaton/MacSync
#        Bugs:  https://github.com/Pilaton/MacSync/issues
#     License:  MIT
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Enable zsh emulation for compatibility
emulate -L zsh

# Load datetime module for fast timestamps
zmodload zsh/datetime

# Default logging configuration
: "${LOG_ENABLED:=true}"
: "${LOG_FILE:=${HOME}/.macsync/macsync.log}"
: "${LOG_MAX_SIZE:=500}"  # KB

# Internal state
_LOG_INITIALIZED=false

# Cache OS for cross-platform stat (avoid forking uname repeatedly)
: "${_MACSYNC_OS:=$(uname)}"

#######################################
# Initialize logging system
# Creates log directory and rotates if needed
# Globals:
#   LOG_ENABLED
#   LOG_FILE
#   _LOG_INITIALIZED
#######################################
log_init() {
  [[ "${LOG_ENABLED}" != "true" ]] && return 0
  [[ "${_LOG_INITIALIZED}" == "true" ]] && return 0

  local log_dir="${LOG_FILE:h}"
  
  # Create log directory if it doesn't exist
  if [[ ! -d "${log_dir}" ]]; then
    mkdir -p "${log_dir}" 2>/dev/null || {
      echo "${colorRed:-}Warning: Could not create log directory: ${log_dir}${reset:-}" >&2
      LOG_ENABLED=false
      return 1
    }
  fi

  # Rotate log if needed
  _log_rotate

  # Mark as initialized
  _LOG_INITIALIZED=true

  # Log session start
  log_info "=========================================="
  log_info "MacSync session started"
  log_info "Log file: ${LOG_FILE}"
}

#######################################
# Rotate log file if it exceeds maximum size
# Globals:
#   LOG_FILE
#   LOG_MAX_SIZE
#######################################
_log_rotate() {
  [[ ! -f "${LOG_FILE}" ]] && return 0

  local file_size_kb
  # Use stat with fallback for cross-platform compatibility (macOS vs Linux)
  if [[ "${_MACSYNC_OS}" == "Darwin" ]]; then
    file_size_kb=$(( $(stat -f%z "${LOG_FILE}" 2>/dev/null || echo 0) / 1024 ))
  else
    file_size_kb=$(( $(stat -c%s "${LOG_FILE}" 2>/dev/null || echo 0) / 1024 ))
  fi

  if (( file_size_kb >= LOG_MAX_SIZE )); then
    # Remove old backup if exists
    [[ -f "${LOG_FILE}.old" ]] && rm -f "${LOG_FILE}.old"
    
    # Rotate current log to .old
    mv "${LOG_FILE}" "${LOG_FILE}.old" 2>/dev/null
    
    # Create new empty log
    touch "${LOG_FILE}"
  fi
}

#######################################
# Write a log entry
# Arguments:
#   $1 - Log level (INFO, WARN, ERROR)
#   $2 - Message
# Globals:
#   LOG_ENABLED
#   LOG_FILE
#######################################
_log_write() {
  [[ "${LOG_ENABLED}" != "true" ]] && return 0
  
  local level="${1}"
  local message="${2}"
  local timestamp
  
  # Use zsh/datetime for faster timestamp generation without forking 'date'
  strftime -s timestamp '%Y-%m-%d %H:%M:%S' $EPOCHSECONDS

  echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}" 2>/dev/null
}

#######################################
# Log info message
# Arguments:
#   $1 - Message
#######################################
log_info() {
  _log_write "INFO" "${1}"
}

#######################################
# Log warning message
# Arguments:
#   $1 - Message
#######################################
log_warn() {
  _log_write "WARN" "${1}"
}

#######################################
# Log error message
# Arguments:
#   $1 - Message
#######################################
log_error() {
  _log_write "ERROR" "${1}"
}

#######################################
# Log debug message (only in verbose mode)
# Arguments:
#   $1 - Message
# Globals:
#   VERBOSE
#######################################
log_debug() {
  [[ "${VERBOSE:-false}" != "true" ]] && return 0
  _log_write "DEBUG" "${1}"
}

#######################################
# Log session end
#######################################
log_end() {
  [[ "${LOG_ENABLED}" != "true" ]] && return 0
  log_info "MacSync session ended"
  log_info "=========================================="
}
