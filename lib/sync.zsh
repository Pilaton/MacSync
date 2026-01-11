#!/usr/bin/env zsh
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#        File:  sync.zsh
#
#        Name:  MacSync Sync Module
# Description:  Core synchronization logic
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Enable zsh emulation for compatibility
emulate -L zsh

# Load dependencies if not already loaded (e.g. for unit testing this file in isolation)
# In production, these should be sourced by the main executable.
# source "${MACSYNC_ROOT}/lib/logger.zsh"

#######################################
# Check if the sync folder exists
# Globals:
#   SYNC_FOLDER
#   SYNC_FOLDER_NAME
# Returns:
#   0 (true) if the folder exists
#   1 (false) if does not exist
#######################################
check_dotfiles_folder() {
  [[ -d "${SYNC_FOLDER}/${SYNC_FOLDER_NAME}" ]]
}

#######################################
# Check if files for synchronization exist.
# Categorizes files as: ready to sync, already synced, not found.
# Globals:
#   BACKUP_FILES
#   _BACKUP_VALID_FILES (output)
# Returns:
#   0 if there are files to sync (or already synced)
#   1 if no valid files found at all
#######################################
check_synchronized_files() {
  echo "${colorYellow:-}${bold:-}Checking synchronized files${reset:-}"
  echo "---------------------------"
  _BACKUP_VALID_FILES=()      # Files ready to sync
  local ALREADY_SYNCED=()     # Files that are symlinks (already synced)
  local NOT_FOUND=()          # Files that don't exist

  local sync_path="${SYNC_FOLDER:A}/${SYNC_FOLDER_NAME}"

  for file in "${BACKUP_FILES[@]}"; do
    
    # Resolving symlink target if it is a symlink
    local link_target=""
    if [[ -L "${file}" ]]; then
      # Zsh modifier :A resolves to absolute path (canonicalized)
      link_target="${file:A}"
    fi

    # Check 1: Is it already a correct symlink?
    if [[ -L "${file}" && "${link_target}" == "${sync_path}"* ]]; then
      ALREADY_SYNCED+=("${file}")
      echo "${file} - ${colorCyan:-}Already synced ✓${reset:-}"
    
    # Check 2: Does the file exist (regular or symlink to somewhere else)?
    elif [[ -e "${file}" || -L "${file}" ]]; then
      _BACKUP_VALID_FILES+=("${file}")
      echo "${file} - ${colorGreen:-}Ready to sync${reset:-}"
    
    # Check 3: Not found
    else
      NOT_FOUND+=("${file}")
      echo "${file} - ${colorRed:-}Not found${reset:-}"
    fi
  done

  echo "---------------------------"

  # Summary messages
  if (( ${#ALREADY_SYNCED[@]} )); then
    echo "✓ Already synced: ${colorCyan:-}(${ALREADY_SYNCED[*]})${reset:-}"
  fi

  if (( ${#NOT_FOUND[@]} )); then
    echo "⚠ Not found: ${colorRed:-}(${NOT_FOUND[*]})${reset:-}"
  fi

  if (( ${#_BACKUP_VALID_FILES[@]} )); then
    echo "🔸 Will sync: ${colorGreen:-}(${_BACKUP_VALID_FILES[*]})${reset:-}"
    return 0
  fi
  
  if (( ${#ALREADY_SYNCED[@]} > 0 )); then
     echo "${colorGreen:-}All files are already synced!${reset:-}"
     return 1 # Nothing new to sync, but success
  fi
  
  echo "${colorRed:-}No valid files found for synchronization!${reset:-}"
  return 1
}
#######################################
# Internal: Run rsync with error handling
# Arguments:
#   $@ - rsync arguments
# Returns:
#   0 on success, 1 on failure
#######################################
_run_rsync() {
   local output
   # Capture both stdout and stderr
   if ! output=$(rsync "$@" 2>&1); then
     echo "${colorRed:-}rsync detailed error:${reset:-}"
     echo "${output}"
     return 1
   fi
   return 0
}

#######################################
# Create backup folder for device files.
#######################################
create_backup_folder() {
  local backup_path="${SYNC_FOLDER}/${_BACKUP_DEFAULT_FOLDER}"
  
  if is_dry_run; then
    print_dry_run "create backup folder: ${backup_path}"
    log_info "[DRY-RUN] Would create backup folder: ${backup_path}"
    return 0
  fi
  
  mkdir -p "${backup_path}" || {
    log_error "Failed to create backup folder: ${backup_path}"
    echo "${colorRed:-}Error creating backup folder${reset:-}"
    return 1
  }
  log_info "Created backup folder: ${backup_path}"
}

#######################################
# Create sync folder for dotfiles.
#######################################
create_dotfiles_folder() {
  local dotfiles_path="${SYNC_FOLDER}/${SYNC_FOLDER_NAME}"
  
  if is_dry_run; then
    print_dry_run "create sync folder: ${dotfiles_path}"
    log_info "[DRY-RUN] Would create sync folder"
    return 0
  fi
  
  mkdir -p "${dotfiles_path}" || {
    log_error "Failed to create sync folder: ${dotfiles_path}"
    echo "${colorRed:-}Error creating sync folder${reset:-}"
    return 1
  }
  log_info "Created sync folder: ${dotfiles_path}"
}

#######################################
# Backup user file to backup folder.
# Arguments:
#   $1 - File path to backup
#######################################
backup_file() {
  local file="${1}"
  local backup_path="${SYNC_FOLDER}/${_BACKUP_DEFAULT_FOLDER}"
  
  if is_dry_run; then
    print_dry_run "backup: ${file} → ${backup_path}/"
    log_info "[DRY-RUN] Would backup: ${file}"
    return 0
  fi
  
  if ! _run_rsync -aRq "${file}" "${backup_path}"; then
    log_error "Failed to backup: ${file}"
    echo "${colorRed:-}Error backing up ${file}${reset:-}"
    return 1
  fi
  
  log_info "Backed up: ${file}"
  print_verbose "Backed up: ${file}"
}

#######################################
# Backup config.cfg to backup folder with underscore prefix.
#######################################
backup_config_file() {
  local config_source="${MACSYNC_CONFIG_FILE:-${HOME}/.macsync/config.cfg}"
  
  if is_dry_run; then
    print_dry_run "backup ${config_source} → ${SYNC_FOLDER}/${_BACKUP_DEFAULT_FOLDER}/_config.cfg"
    log_info "[DRY-RUN] Would backup config.cfg"
    return 0
  fi
  
  if ! _run_rsync -aq "${config_source}" "${SYNC_FOLDER}/${_BACKUP_DEFAULT_FOLDER}"; then
    log_error "Failed to backup config: ${config_source}"
    echo "${colorRed:-}Error backing up config${reset:-}"
    return 1
  fi
  
  if ! mv "${SYNC_FOLDER}/${_BACKUP_DEFAULT_FOLDER}/config.cfg" "${SYNC_FOLDER}/${_BACKUP_DEFAULT_FOLDER}/_config.cfg"; then
    log_error "Failed to rename config backup"
    echo "${colorRed:-}Error renaming config backup${reset:-}"
    return 1
  fi
  log_info "Backed up config.cfg"
}

#######################################
# Move file to sync folder and remove original.
# Arguments:
#   $1 - File path to move
#######################################
move_file() {
  local file="${1}"
  local target_dir="${SYNC_FOLDER}/${SYNC_FOLDER_NAME}"
  
  if is_dry_run; then
    print_dry_run "move: ${file} → ${target_dir}/"
    log_info "[DRY-RUN] Would move: ${file}"
    return 0
  fi
  
  # IMPORTANT: For "move" (used in Update/Replace), we MUST ensure the local file
  # overwrites the backup file, even if the backup is newer. 
  # We do NOT use '-u' (update) here because rsync -u skips newer destination files.
  # If we skip copying, the subsequent rm -rf will delete the local file without backing it up!
  if ! _run_rsync -aRq "${file}" "${target_dir}"; then
    log_error "Failed to move: ${file}"
    echo "${colorRed:-}Error moving ${file}${reset:-}"
    return 1
  fi
  
  # Verify file was copied before removing original
  if [[ -e "${target_dir}/${file}" ]]; then
    if [[ -n "${file}" ]] && ! rm -rf "${file}"; then
      log_error "Failed to remove original file: ${file}"
      echo "${colorRed:-}Error: Failed to remove ${file}${reset:-}"
      return 1
    fi
    log_info "Moved: ${file} → ${SYNC_FOLDER_NAME}/"
    print_verbose "Moved: ${file}"
  else
    log_error "Verification failed: ${file} not found in sync folder after rsync"
    echo "${colorRed:-}Error: ${file} not verified in sync folder${reset:-}"
    return 1
  fi
}
#######################################
# Create symlink to file in sync folder.
# FORCE creates the symlink, assuming backup was already done.
# Arguments:
#   $1 - File path for symlink
#######################################
create_symlink() {
  local file="${1}"
  local target="${SYNC_FOLDER}/${SYNC_FOLDER_NAME}/${file}"
  
  # Validate target exists before creating symlink
  if [[ ! -e "${target}" ]]; then
    # Warn but don't fail hard, as standard 'ln -s' allows broken links, 
    # but for our purpose it's likely an error.
    log_warn "Target for symlink does not exist: ${target}"
    echo "${file} — ${colorYellow:-}warning: target missing${reset:-}"
  fi
  
  if is_dry_run; then
    print_dry_run "create symlink: ${file} → ${target}"
    log_info "[DRY-RUN] Would create symlink: ${file}"
    return 0
  fi
  
  # Ensure parent directory exists
  local parent_dir="${file:h}"
  if [[ "${parent_dir}" != "." && ! -d "${parent_dir}" ]]; then
    mkdir -p "${parent_dir}"
  fi

  # Force create symlink (-f removes existing destination file)
  if ! ln -fs "${target}" "${file}"; then
    log_error "Failed to create symlink: ${file}"
    echo "${colorRed:-}Error creating symlink ${file}${reset:-}"
    return 1
  fi
  
  log_info "Created symlink: ${file}"
  print_verbose "Symlink: ${file} → ${target}"
}

#######################################
# Execute synchronization workflow based on mode.
# Arguments:
#   $1 - Mode (first_sync, replace, update, download)
#######################################
sync_files() {
  local mode="${1}"
  
  # Check if there are valid files for synchronization
  if ! check_synchronized_files; then
    echo "...exit"
    return 1
  fi

  create_backup_folder || return 1
  backup_config_file || return 1

  local dotfiles_path="${SYNC_FOLDER}/${SYNC_FOLDER_NAME}"

  # Mode-specific setup
  case "${mode}" in
    "first_sync")
      print_msg "Sync..."
      create_dotfiles_folder || return 1
      ;;
    "replace")
      print_msg "Replace..."
      if is_dry_run; then
        print_dry_run "delete and recreate: ${dotfiles_path}"
        log_info "[DRY-RUN] Would delete ${dotfiles_path}"
      else
        if [[ -n "${dotfiles_path}" ]] && [[ -d "${dotfiles_path}" ]]; then
          if ! rm -rf "${dotfiles_path}"; then
            log_error "Failed to delete ${dotfiles_path}"
            echo "${colorRed:-}Error: Failed to delete sync folder${reset:-}"
            return 1
          fi
          log_info "Deleted ${dotfiles_path} for replacement"
        fi
      fi
      create_dotfiles_folder || return 1
      ;;
    "update")
      print_msg "Update..."
      # No special setup needed
      ;;
    "download")
      print_msg "Download..."
      # No special setup needed
      ;;
  esac

  # Iterate over files
  for file in "${_BACKUP_VALID_FILES[@]}"; do
    
    # Common action: Backup
    # Check return code! If backup fails, DO NOT PROCEED.
    if ! backup_file "${file}"; then
       echo "${colorRed:-}Skipping ${file} due to backup failure.${reset:-}"
       continue
    fi
    
    # Mode-specific actions
    case "${mode}" in
      "first_sync"|"replace"|"update")
        if move_file "${file}"; then
          create_symlink "${file}"
        fi
        ;;
      "download")
        # For download, we don't delete first. create_symlink handles the atomic swap.
        create_symlink "${file}"
        ;;
    esac
  done
  
  print_msg "Done!"
  return 0
}

#######################################
# Disable sync and restore original files.
#######################################
disable_sync_files() {
  echo "${colorYellow:-}${bold:-}Restoring original files and turning off sync...${reset:-}"
  echo "---------------------------"
  
  local dotfiles_path="${SYNC_FOLDER}/${SYNC_FOLDER_NAME}"

  for file in "${BACKUP_FILES[@]}"; do

    # Check if the file is a symlink
    if [[ -L "${file}" ]]; then
      # Check if the original exists in the sync folder
      if [[ -e "${dotfiles_path}/${file}" ]]; then
        if is_dry_run; then
          print_dry_run "restore: ${file} from sync folder"
          log_info "[DRY-RUN] Would restore: ${file}"
        else
          # Remove the symlink safely
          if [[ -n "${file}" ]] && [[ -L "${file}" ]]; then
            if ! rm -f "${file}"; then
              log_error "Failed to remove symlink: ${file}"
              echo "${file} — ${colorRed:-}remove failed${reset:-}"
              continue
            fi
          fi
          
          # Create parent directory if needed
          local parent_dir="${file:h}"
          if [[ "${parent_dir}" != "." && "${parent_dir}" != "${file}" ]]; then
            mkdir -p "${parent_dir}"
          fi
          
          # Copy file/folder from sync folder to home (follow symlinks)
          if ! cp -RL "${dotfiles_path}/${file}" "${file}"; then
            log_error "Failed to restore: ${file}"
            echo "${file} — ${colorRed:-}restore failed${reset:-}"
          else
            log_info "Restored: ${file}"
            echo "${file} — ${colorGreen:-}restored${reset:-}"
          fi
        fi
      else
        echo "${file} — ${colorRed:-}not found in sync folder${reset:-}"
      fi
    else
      # File is not a symlink - already a regular file
      echo "${file} — ${colorCyan:-}skipped (not synced)${reset:-}"
    fi
  done
  
  print_msg "Done!"
}
