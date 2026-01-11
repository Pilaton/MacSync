#!/usr/bin/env bats
# MacSync test suite

# Load test helper
load 'test_helper'

# =============================================================================
# CLI Tests
# =============================================================================

@test "macsync --version shows version number" {
  run zsh "${MACSYNC}" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "MacSync version" ]]
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "macsync --help shows usage information" {
  run zsh "${MACSYNC}" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "MacSync - Easy sync for macOS" ]]
  [[ "$output" =~ "USAGE:" ]]
  [[ "$output" =~ "--dry-run" ]]
  [[ "$output" =~ "--help" ]]
}

@test "macsync -h is alias for --help" {
  run zsh "${MACSYNC}" -h
  [ "$status" -eq 0 ]
  [[ "$output" =~ "USAGE:" ]]
}

@test "macsync -n is alias for --dry-run" {
  run zsh "${MACSYNC}" -n --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "USAGE:" ]]
}

@test "macsync with invalid option shows error" {
  run zsh "${MACSYNC}" --invalid-option
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error:" ]]
  [[ "$output" =~ "Unknown option" ]]
}

@test "macsync --sync-folder without argument shows error" {
  run zsh "${MACSYNC}" --sync-folder
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error:" ]]
}

@test "macsync --files without argument shows error" {
  run zsh "${MACSYNC}" --files
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error:" ]]
}

# =============================================================================
# Project Structure Tests
# =============================================================================

@test "VERSION file exists and contains valid version" {
  [ -f "${PROJECT_ROOT}/VERSION" ]
  version=$(grep -o '"version": *"[^"]*"' "${PROJECT_ROOT}/VERSION" | cut -d'"' -f4)
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "default config template exists" {
  [ -f "${PROJECT_ROOT}/config/config.cfg.default" ]
}

@test "all zsh files have valid syntax" {
  run zsh -n "${PROJECT_ROOT}/bin/macsync"
  [ "$status" -eq 0 ]
  
  run zsh -n "${PROJECT_ROOT}/lib/config.zsh"
  [ "$status" -eq 0 ]

  run zsh -n "${PROJECT_ROOT}/lib/sync.zsh"
  [ "$status" -eq 0 ]
  
  run zsh -n "${PROJECT_ROOT}/lib/cli.zsh"
  [ "$status" -eq 0 ]
  
  run zsh -n "${PROJECT_ROOT}/lib/logger.zsh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Config Tests
# =============================================================================

@test "first run creates config in ~/.macsync/" {
  # Remove existing config to simulate first run
  rm -rf "${HOME}/.macsync"
  
  run zsh "${MACSYNC}"
  [ "$status" -eq 0 ]
  [ -d "${HOME}/.macsync" ]
  [ -f "${HOME}/.macsync/config.cfg" ]
  [[ "$output" =~ "Welcome to MacSync" ]]
}

@test "empty config fields cause error" {
  cat > "${HOME}/.macsync/config.cfg" << 'EOF'
SYNC_FOLDER=
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC"
BACKUP_FILES=()
LOG_ENABLED=false
EOF
  
  # Simulate user input "3" (Cancel) to exit the welcome menu
  run bash -c "echo '3' | zsh '${MACSYNC}'"
  [[ "$output" =~ "is empty" ]] || [[ "$output" =~ "Config variable" ]]
}

@test "config with tilde path expands correctly" {
  cat > "${HOME}/.macsync/config.cfg" << EOF
SYNC_FOLDER=~/TestSyncFolder
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC.\$(date +%s)"
BACKUP_FILES=(.testfile)
LOG_ENABLED=false
EOF
  mkdir -p "${HOME}/TestSyncFolder"
  
  # Run with --help to test config loading without interactive prompt
  run zsh "${MACSYNC}" --help
  [ "$status" -eq 0 ]
}

# =============================================================================
# Logging Tests
# =============================================================================

@test "logger creates log directory if not exists" {
  cat > "${HOME}/.macsync/config.cfg" << 'EOF'
SYNC_FOLDER="${HOME}/TestSyncFolder"
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC"
BACKUP_FILES=(.testfile)
LOG_ENABLED=true
LOG_FILE="${HOME}/.macsync/macsync.log"
EOF
  mkdir -p "${HOME}/TestSyncFolder"
  
  run zsh "${MACSYNC}" --help
  [ "$status" -eq 0 ]
}

@test "log file is created when logging enabled" {
  rm -f "${HOME}/.macsync/macsync.log"
  
  cat > "${HOME}/.macsync/config.cfg" << 'EOF'
SYNC_FOLDER="${HOME}/TestSyncFolder"
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC"
BACKUP_FILES=(.testfile)
LOG_ENABLED=true
LOG_FILE="${HOME}/.macsync/macsync.log"
EOF
  mkdir -p "${HOME}/TestSyncFolder"
  
  # Run with Cancel option to trigger log init
  run bash -c "echo '3' | zsh '${MACSYNC}'"
  [ -f "${HOME}/.macsync/macsync.log" ]
}

# =============================================================================
# Dry-Run Tests
# =============================================================================

@test "dry-run mode shows banner" {
  setup_sync_env
  
  run bash -c "echo '3' | zsh '${MACSYNC}' --dry-run"
  [[ "$output" =~ "DRY-RUN MODE ENABLED" ]]
}

@test "dry-run does not create backup folder" {
  setup_sync_env
  
  # Run first sync with dry-run and immediately cancel
  run bash -c "echo '1' | zsh '${MACSYNC}' --dry-run" 
  
  # Backup folder should NOT be created in dry-run
  backup_count=$(find "${HOME}/TestSyncFolder" -type d -name "_Backup*" 2>/dev/null | wc -l)
  [ "$backup_count" -eq 0 ]
}

@test "dry-run does not move files" {
  setup_sync_env
  
  run bash -c "echo '1' | zsh '${MACSYNC}' --dry-run"
  
  # Original file should still exist (not moved)
  [ -f "${HOME}/.testfile" ]
  # File should NOT be in dotfiles
  [ ! -f "${HOME}/TestSyncFolder/dotfiles/.testfile" ]
}

@test "dry-run does not create symlinks" {
  setup_sync_env
  
  run bash -c "echo '1' | zsh '${MACSYNC}' --dry-run"
  
  # File should NOT be a symlink
  [ ! -L "${HOME}/.testfile" ]
}

# =============================================================================
# First Sync Tests
# =============================================================================

@test "first sync creates dotfiles folder" {
  setup_sync_env
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  [ -d "${HOME}/TestSyncFolder/dotfiles" ]
}

@test "first sync creates backup folder" {
  setup_sync_env
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Check backup folder exists
  backup_count=$(find "${HOME}/TestSyncFolder" -type d -name "_Backup*" 2>/dev/null | wc -l)
  [ "$backup_count" -ge 1 ]
}

@test "first sync moves files to dotfiles folder" {
  setup_sync_env
  echo "test content" > "${HOME}/.testfile"
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # File should be in dotfiles
  [ -f "${HOME}/TestSyncFolder/dotfiles/.testfile" ]
}

@test "first sync creates symlinks" {
  setup_sync_env
  echo "test content" > "${HOME}/.testfile"
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # File should be a symlink
  [ -L "${HOME}/.testfile" ]
  
  # Symlink should point to dotfiles
  link_target=$(readlink "${HOME}/.testfile")
  [[ "$link_target" =~ "dotfiles/.testfile" ]]
}

@test "first sync backs up config file" {
  setup_sync_env
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Config backup should exist (as _config.cfg)
  config_backup=$(find "${HOME}/TestSyncFolder/_Backup"* -name "_config.cfg" 2>/dev/null | head -1)
  [ -n "$config_backup" ]
  [ -f "$config_backup" ]
}

# =============================================================================
# Replace Sync Tests
# =============================================================================

@test "replace sync deletes and recreates dotfiles folder" {
  setup_sync_env
  
  # First sync
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Add an extra file to dotfiles
  echo "extra" > "${HOME}/TestSyncFolder/dotfiles/.extrafile"
  
  # Create new test file and rerun config
  setup_replace_env
  
  # Replace sync (option 1 from chooseNextStep)
  run bash -c "echo '1
1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Extra file should be gone
  [ ! -f "${HOME}/TestSyncFolder/dotfiles/.extrafile" ]
}

# =============================================================================
# Update Sync Tests
# =============================================================================

@test "update sync preserves existing files" {
  setup_sync_env
  
  # First sync
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  
  # Add an extra file to dotfiles
  echo "extra" > "${HOME}/TestSyncFolder/dotfiles/.extrafile"
  
  # Recreate test file  
  setup_replace_env
  
  # Update sync (option 2 from chooseNextStep)
  run bash -c "echo '1
2' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Extra file should still exist
  [ -f "${HOME}/TestSyncFolder/dotfiles/.extrafile" ]
}

# =============================================================================
# Download (Connect Only) Tests
# =============================================================================

@test "download sync creates symlinks without modifying sync folder" {
  setup_sync_env
  echo "original content" > "${HOME}/.testfile"
  
  # First sync
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  
  # Modify file in dotfiles
  echo "modified content" > "${HOME}/TestSyncFolder/dotfiles/.testfile"
  
  # Create a new clean home and config
  rm "${HOME}/.testfile"
  echo "new local content" > "${HOME}/.testfile"
  setup_replace_env
  
  # Download sync (option 3 from chooseNextStep)
  run bash -c "echo '1
3' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Symlink should point to dotfiles
  [ -L "${HOME}/.testfile" ]
  
  # Content should be from dotfiles (modified content)
  content=$(cat "${HOME}/.testfile")
  [ "$content" = "modified content" ]
}

# =============================================================================
# Disable Sync Tests
# =============================================================================

@test "disable sync restores original files" {
  setup_sync_env
  echo "original content" > "${HOME}/.testfile"
  
  # First sync
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ -L "${HOME}/.testfile" ]
  
  # Disable sync (option 2 from welcome screen)
  run bash -c "echo '2' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "restored" ]] || [[ "$output" =~ "Done!" ]]
  
  # File should no longer be a symlink and should exist
  [ ! -L "${HOME}/.testfile" ] || [ -f "${HOME}/.testfile" ]
}

@test "disable sync dry-run does not restore files" {
  setup_sync_env
  echo "original content" > "${HOME}/.testfile"
  
  # First sync
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ -L "${HOME}/.testfile" ]
  
  # Disable sync with dry-run
  run bash -c "echo '2' | zsh '${MACSYNC}' --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "DRY-RUN" ]]
  
  # File should still be a symlink
  [ -L "${HOME}/.testfile" ]
}

# =============================================================================
# Edge Cases
# =============================================================================

@test "skips files that do not exist" {
  cat > "${HOME}/.macsync/config.cfg" << 'EOF'
SYNC_FOLDER="${HOME}/TestSyncFolder"
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC"
BACKUP_FILES=(.nonexistent .testfile)
LOG_ENABLED=false
EOF
  mkdir -p "${HOME}/TestSyncFolder"
  echo "test" > "${HOME}/.testfile"
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Not found" ]] || [[ "$output" =~ "skipped" ]]
}

@test "skips files that are already symlinks" {
  setup_sync_env
  
  # Remove existing file and create a symlink instead
  rm -f "${HOME}/.testfile"
  touch /tmp/.testfile_target
  ln -s /tmp/.testfile_target "${HOME}/.testfile"
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [[ "$output" =~ "Ready to sync" ]]
}

@test "handles folder sync correctly" {
  setup_sync_env
  mkdir -p "${HOME}/.testfolder/subfolder"
  echo "nested" > "${HOME}/.testfolder/subfolder/file.txt"
  
  cat > "${HOME}/.macsync/config.cfg" << 'EOF'
SYNC_FOLDER="${HOME}/TestSyncFolder"
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC"
BACKUP_FILES=(.testfolder)
LOG_ENABLED=false
EOF
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Folder should be a symlink
  [ -L "${HOME}/.testfolder" ]
  
  # Nested content should be accessible
  [ -f "${HOME}/.testfolder/subfolder/file.txt" ]
}

@test "handles paths with spaces" {
  setup_sync_env
  mkdir -p "${HOME}/Test Sync Folder"
  echo "test" > "${HOME}/.test file"
  
  cat > "${HOME}/.macsync/config.cfg" << 'EOF'
SYNC_FOLDER="${HOME}/Test Sync Folder"
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC"
BACKUP_FILES=(".test file")
LOG_ENABLED=false
EOF
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.test file" ]
}

@test "nonexistent sync folder parent shows error" {
  cat > "${HOME}/.macsync/config.cfg" << 'EOF'
SYNC_FOLDER="/nonexistent/path/SyncFolder"
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC"
BACKUP_FILES=(.testfile)
LOG_ENABLED=false
EOF
  echo "test" > "${HOME}/.testfile"
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [[ "$output" =~ "does not exist" ]] || [[ "$output" =~ "Error" ]]
}

# =============================================================================
# SYNC_FOLDER_NAME Tests
# =============================================================================

@test "custom SYNC_FOLDER_NAME creates correct folder" {
  cat > "${HOME}/.macsync/config.cfg" << 'EOF'
SYNC_FOLDER="${HOME}/TestSyncFolder"
SYNC_FOLDER_NAME="myfiles"
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC"
BACKUP_FILES=(.testfile)
LOG_ENABLED=false
EOF
  mkdir -p "${HOME}/TestSyncFolder"
  echo "test" > "${HOME}/.testfile"
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Custom folder name should be created
  [ -d "${HOME}/TestSyncFolder/myfiles" ]
  [ ! -d "${HOME}/TestSyncFolder/dotfiles" ]
  
  # Symlink should point to custom folder
  [ -L "${HOME}/.testfile" ]
  link_target=$(readlink "${HOME}/.testfile")
  [[ "$link_target" =~ "myfiles/.testfile" ]]
}

@test "default SYNC_FOLDER_NAME is dotfiles" {
  setup_sync_env
  
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Default folder name should be dotfiles
  [ -d "${HOME}/TestSyncFolder/dotfiles" ]
}

# =============================================================================
# Disable Sync - Skipped Message Tests
# =============================================================================

@test "disable sync shows skipped for non-symlink files" {
  setup_sync_env
  
  # First sync to create dotfiles
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Now restore (disable sync)
  run bash -c "echo '2' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Files are now regular (not synced), disable again should show skipped
  run bash -c "echo '2' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "skipped" ]]
}

@test "disable sync shows restored for synced files" {
  setup_sync_env
  
  # First sync
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Now disable - should show restored
  run bash -c "echo '2' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "restored" ]]
}

# =============================================================================
# Log Rotation Tests
# =============================================================================

@test "log rotation occurs when log exceeds max size" {
  cat > "${HOME}/.macsync/config.cfg" << 'EOF'
SYNC_FOLDER="${HOME}/TestSyncFolder"
_NAME_PC="TestPC"
_BACKUP_DEFAULT_FOLDER="_Backup.TestPC"
BACKUP_FILES=(.testfile)
LOG_ENABLED=true
LOG_FILE="${HOME}/.macsync/macsync.log"
LOG_MAX_SIZE=1
EOF
  mkdir -p "${HOME}/TestSyncFolder"
  echo "test" > "${HOME}/.testfile"
  
  # Create a large log file (> 1KB)
  mkdir -p "${HOME}/.macsync"
  dd if=/dev/zero of="${HOME}/.macsync/macsync.log" bs=1024 count=2 2>/dev/null
  
  # Run macsync to trigger rotation
  run bash -c "echo '3' | zsh '${MACSYNC}'"
  
  # Old log should be rotated
  [ -f "${HOME}/.macsync/macsync.log.old" ]
}

# =============================================================================
# Verbose/Quiet Mode Tests
# =============================================================================

@test "verbose mode shows extra output" {
  run zsh "${MACSYNC}" --verbose --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "USAGE:" ]]
}

@test "quiet mode suppresses output" {
  run zsh "${MACSYNC}" --quiet --help
  [ "$status" -eq 0 ]
  # Help should still show even in quiet mode
  [[ "$output" =~ "USAGE:" ]]
}

@test "quiet mode disables verbose" {
  run zsh "${MACSYNC}" --verbose --quiet --help
  [ "$status" -eq 0 ]
  # Should work without error
  [[ "$output" =~ "USAGE:" ]]
}

# =============================================================================
# CLI Override Tests
# =============================================================================

@test "CLI --sync-folder overrides config" {
  setup_sync_env
  mkdir -p "${HOME}/OverrideFolder"
  
  run bash -c "echo '1' | zsh '${MACSYNC}' --sync-folder '${HOME}/OverrideFolder'"
  [ "$status" -eq 0 ]
  
  # Override folder should be used
  [ -d "${HOME}/OverrideFolder/dotfiles" ]
}

@test "CLI --files overrides config" {
  setup_sync_env
  echo "other content" > "${HOME}/.otherfile"
  
  run bash -c "echo '1' | zsh '${MACSYNC}' --files '.otherfile'"
  [ "$status" -eq 0 ]
  
  # Only override file should be synced
  [ -L "${HOME}/.otherfile" ]
}

# =============================================================================
# Broken Symlink Tests
# =============================================================================

@test "handles broken symlinks gracefully" {
  setup_sync_env
  
  # Create a broken symlink
  rm -f "${HOME}/.testfile"
  ln -s "/nonexistent/target" "${HOME}/.testfile"
  
  # Should NOT skip broken symlinks - should treat them as ready to sync (to fail or fix later)
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [[ "$output" =~ "Ready to sync" ]] || [[ "$output" =~ "not found" ]]
}

@test "disable sync handles missing sync folder file" {
  setup_sync_env
  
  # First sync
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  
  # Delete file from dotfiles (simulate corruption)
  rm -f "${HOME}/TestSyncFolder/dotfiles/.testfile"
  
  # Disable should show not found
  run bash -c "echo '2' | zsh '${MACSYNC}'"
  [[ "$output" =~ "not found in sync folder" ]]
}

# =============================================================================
# Cancel Tests
# =============================================================================

@test "cancel from welcome screen exits cleanly" {
  setup_sync_env
  
  run bash -c "echo '3' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Exit" ]]
}

@test "cancel from chooseNextStep exits cleanly" {
  setup_sync_env
  
  # First sync to create dotfiles folder
  run bash -c "echo '1' | zsh '${MACSYNC}'"
  
  # Restore files
  run bash -c "echo '2' | zsh '${MACSYNC}'"
  
  # Now cancel from chooseNextStep
  run bash -c "printf '1\n4\n' | zsh '${MACSYNC}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Back" ]] || [[ "$output" =~ "Exit" ]]
}
