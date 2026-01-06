#!/usr/bin/env zsh
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#        File:  install.zsh
#
#       Usage:  zsh ./bin/install.zsh
#
#        Name:  MacSync
# Description:  A simple solution to sync your settings and dotfiles.
#
#      Author:  Pilaton
#      GitHub:  https://github.com/Pilaton/MacSync
#        Bugs:  https://github.com/Pilaton/MacSync/issues
#     License:  MIT
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Enable zsh emulation for compatibility
emulate -L zsh

# Check for required dependencies
if ! command -v rsync &> /dev/null; then
  echo "Error: rsync is required but not found. Please install rsync."
  exit 1
fi

# Set colors if "tput" is present in the system
if command -v tput &> /dev/null; then
  bold=$(tput bold)
  colorRed=$(tput setaf 1)
  colorGreen=$(tput setaf 2)
  colorYellow=$(tput setaf 3)
  colorBlue=$(tput setaf 4)
  colorCian=$(tput setaf 6)
  colorWhite=$(tput setaf 7)
  reset=$(tput sgr0)
  # Array of colors for coloring the main logo
  arrayColor=(
    "${colorBlue}"
    "${colorWhite}"
    "${colorRed}"
  )
fi

# Connecting files and switching to the user's home directory. All work is done from it
source ./config/config.cfg
source ./bin/dotfile.zsh
cd ~ || exit



#######################################
# Checking the completeness of important fields in the config.cfg file
# Globals:
#   SYNC_FOLDER
#   _NAME_PC
#   _BACKUP_DEFAULT_FOLDER
#   BACKUP_FILES
# Returns:
#   exit if not all fields are filled
#######################################
checkConfigFile() {
  importantConfigFields=(${#SYNC_FOLDER} ${#_NAME_PC} ${#_BACKUP_DEFAULT_FOLDER} ${#BACKUP_FILES})

  for field in "${importantConfigFields[@]}"; do
    if [[ ${field} == '0' ]]; then
      echo "OOPS..."
      echo "${colorRed}There are empty fields in config.cfg. Please fill them in.${reset}"
      echo "...Exit" && exit
    fi
  done
}
checkConfigFile

#######################################
# Let's initialize synchronization. If synchronization was performed earlier, we offer options
#######################################
initSync() {
  if ! checkDotfilesFolder; then
    startSyncDot "first_sync"
  else
    chooseNextStep
  fi
}

#######################################
# We stop synchronizing files on this device, delete symlinks and return the originals of the files
# Globals:
#   SYNC_FOLDER
#######################################
disableSync() {
  if ! checkDotfilesFolder; then
    echo "${colorRed}Dotfile sync folder not found...${reset}"
    echo "(${SYNC_FOLDER}/dotfiles)"
    echo "...Exit" && exit
  fi

  disableSyncDot
}

#######################################
# The welcome screen and the choice of the next step - sync files or vice versa, disable sync
#######################################
welcomeScreen() {
  printf '                                                                                \n'
  printf '                                                                                \n'
  printf '%s888b     d888                  %s  .d8888b.           %s                  %s  \n' ${arrayColor} ${reset}
  printf '%s8888b   d8888                  %s d88P  Y88b          %s                  %s  \n' ${arrayColor} ${reset}
  printf '%s88888b.d88888                  %s Y88b.               %s                  %s  \n' ${arrayColor} ${reset}
  printf '%s888Y88888P888  8888b.   .d8888b%s  "Y888b.   888  888 %s88888b.   .d8888b %s  \n' ${arrayColor} ${reset}
  printf '%s888 Y888P 888     "88b d88P"   %s     "Y88b. 888  888 %s888 "88b d88P"    %s  \n' ${arrayColor} ${reset}
  printf '%s888  Y8P  888 .d888888 888     %s       "888 888  888 %s888  888 888      %s  \n' ${arrayColor} ${reset}
  printf '%s888   "   888 888  888 Y88b.   %s Y88b  d88P Y88b 888 %s888  888 Y88b.    %s  \n' ${arrayColor} ${reset}
  printf '%s888       888 "Y888888  "Y8888P%s  "Y8888P"   "Y88888 %s888  888  "Y8888P %s  \n' ${arrayColor} ${reset}
  printf '%s                               %s                 888 %s                  %s  \n' ${arrayColor} ${reset}
  printf '%s                               %s            Y8b d88P %s                  %s  \n' ${arrayColor} ${reset}
  printf '%s                               %s             "Y88P"  %s                  %s  \n' ${arrayColor} ${reset}

  echo "${bold}Welcome my friends!${reset}"
  echo "Ready to sync your files? ;)"
  echo ""
  echo "— If you forgot how to work with me, you can see here: https://github.com/Pilaton/MacSync"
  echo "---------------------------"
  echo ""
  echo "${colorYellow}${bold}What do we do? ${reset}"
  echo "1 — Synchronize my files!"
  echo "2 — Disable sync (if enabled)"
  echo "3 — Cancel"
  echo ""

  while true; do
    echo -n "Your reply: "

    read -r reply
    echo ""
    case $reply in
      [1]) initSync    ; return 0 ;;
      [2]) disableSync ; return 0 ;;
      [3]) echo "...Exit" && exit ;;
    esac
  done

}
welcomeScreen
