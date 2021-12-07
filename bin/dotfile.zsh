#!/usr/bin/env zsh
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#        File:  dotfile.zsh
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


# Save the path to the MacSync folder in a variable
ROOT_FOLDER_PROJECT=$PWD


#######################################
# Simple progress bar with a length of 27 dashes :)
#######################################
progressbar() {
    local BAR='---------------------------'
    for i in {1..27}; do
        echo -ne "\r${BAR:0:$i}"
        sleep .03
    done
    echo ""
}

#######################################
# Check if the "dotfiles" folder exists
# Globals:
#   SYNC_FOLDER
# Returns:
#   0 (true) if the folder exists
#   1 (false) if does not exist
#######################################
checkDtofilesFolder() {
    if [[ -d ${SYNC_FOLDER}/dotfiles ]]; then
        return 0
    fi
    return 1
}

#######################################
# We check if the files for synchronization actually exist, written in the variable "BACKUP_FILES = (...)"
# Globals:
#   BACKUP_FILES
#   _BACKUP_VALID_FILES
# Returns:
#   0 (true) if there are files to sync
#   1 (false) if there are no files
#######################################
checkSynchronizedFiles() {
    echo "${colorYellow}${bold}Checking synchronized files${reset}"
    echo "---------------------------"
    _BACKUP_VALID_FILES=() # Write valid files here
    local NOT_VALID_FILES=() # And here are not valid

    for file in "${BACKUP_FILES[@]}"; do
        # Check that the file or folder exists and is not a symlink
        if [[ -e ${file} ]] && ! [[ -L ${file} ]]; then
            _BACKUP_VALID_FILES+=(${file})
            echo "${file} - ${colorGreen}OK${reset}"
        else
            NOT_VALID_FILES+=("${file}")
            echo "${file} - ${colorRed}Not OK${reset}"
        fi
        sleep 0.2
    done

    echo "---------------------------"

    if (( ${#NOT_VALID_FILES[@]} )); then
        echo "🔸 ${colorCian}(${NOT_VALID_FILES[@]})${reset} — Will be skipped. The files do not exist or are symbolic links."
    fi

    if (( ${#_BACKUP_VALID_FILES[@]} )); then
        echo "🔸 List of files to sync: ${colorGreen}(${_BACKUP_VALID_FILES[@]})${reset}"
        progressbar
        return 0
    else
        progressbar
        echo "${colorRed}No files to sync${reset}"
        return 1
    fi
}

#######################################
# Create a folder for backup device files
# Globals:
#   SYNC_FOLDER
#   _BACKUP_DEFAULT_FOLDER
#######################################
createBackupFolder() {
    mkdir -p "${SYNC_FOLDER}/${_BACKUP_DEFAULT_FOLDER}"
}

#######################################
# Create a folder to sync files
# Globals:
#   SYNC_FOLDER
#######################################
createDotfilesFolder() {
    mkdir -p "${SYNC_FOLDER}/dotfiles"
}

#######################################
# Backup the config.cfg file and rename it by adding an underscore
# Globals:
#   ROOT_FOLDER_PROJECT
#   SYNC_FOLDER
#   _BACKUP_DEFAULT_FOLDER
#######################################
backupConfigFile() {
    rsync -aq "${ROOT_FOLDER_PROJECT}/config/config.cfg" "${SYNC_FOLDER}/${_BACKUP_DEFAULT_FOLDER}"
    mv "${SYNC_FOLDER}/${_BACKUP_DEFAULT_FOLDER}/config.cfg" "${SYNC_FOLDER}/${_BACKUP_DEFAULT_FOLDER}/_config.cfg"
}

#######################################
# Backup of original user files specified in the "BACKUP_FILES = (...)" variable
# Globals:
#   SYNC_FOLDER
#   _BACKUP_DEFAULT_FOLDER
# Arguments:
#   [text...] Backup file (path)
#######################################
backupFiles() {
    rsync -aRq ${1} "${SYNC_FOLDER}/${_BACKUP_DEFAULT_FOLDER}"
}

#######################################
# Moving valid files to the sync folder and deleting the originals in the user's home folder
# Valid files are saved by the "checkSynchronizedFiles" function into the "_BACKUP_VALID_FILES" variable
# Globals:
#   SYNC_FOLDER
# Arguments:
#   [text...] File to sync (path)
#######################################
moveFiles() {
    rsync -auRq ${1} "${SYNC_FOLDER}/dotfiles"
    rm -rf ${1}
}

#######################################
# Deleting original files in the user's home folder, if such files are found in the sync folder
# Globals:
#   SYNC_FOLDER
# Arguments:
#   [text...] File to sync (path)
#######################################
deleteSyncedFilesFromMyPC() {
    if [[ -d ${SYNC_FOLDER}/dotfiles/${1} ]] || [[ -f ${SYNC_FOLDER}/dotfiles/${1} ]]; then
        rm -rf ${1}
    fi
}

#######################################
# Creating a symlink to files in the sync folder
# Globals:
#   SYNC_FOLDER
# Arguments:
#   [text...] File to sync (path)
#######################################
creatingSymbolicLinks() {
    ln -s "${SYNC_FOLDER}/dotfiles/${1}" ${1}
}



#######################################
# Algorithm if synchronization on this device starts for the first time
# Globals:
#   _BACKUP_VALID_FILES
#######################################
syncFirst() {
    createDotfilesFolder
    for file in "${_BACKUP_VALID_FILES[@]}"; do
        backupFiles ${file}
        moveFiles ${file}
        creatingSymbolicLinks ${file}
    done
}

#######################################
# Algorithm if you need to completely replace files in the sync folder with new ones
# Globals:
#   SYNC_FOLDER
#   _BACKUP_VALID_FILES
#######################################
syncWithReplace() {
    rm -rf "${SYNC_FOLDER}/dotfiles"
    createDotfilesFolder
    for file in "${_BACKUP_VALID_FILES[@]}"; do
        backupFiles ${file}
        moveFiles ${file}
        creatingSymbolicLinks ${file}
    done
}

#######################################
# Algorithm if you need to update obsolete files in the sync folder with newer ones
# Globals:
#   _BACKUP_VALID_FILES
#######################################
syncWithUpdate() {
    for file in "${_BACKUP_VALID_FILES[@]}"; do
        backupFiles ${file}
        moveFiles ${file}
        creatingSymbolicLinks ${file}
    done
}

#######################################
# Algorithm if you need to connect this device to the sync folder without changing anything in it
# Globals:
#   _BACKUP_VALID_FILES
#######################################
syncWithDownload() {
    for file in "${_BACKUP_VALID_FILES[@]}"; do
        backupFiles ${file}
        deleteSyncedFilesFromMyPC ${file}
        creatingSymbolicLinks ${file}
    done
}




#######################################
# Start file synchronization
# Arguments:
#   [text...] (first_sync, replace, update, download)
#######################################
startSyncDot() {
    # Check if there are valid files for synchronization
    if ! checkSynchronizedFiles; then
        echo "...exit"
        exit
    fi

    createBackupFolder
    backupConfigFile

    case "${1}" in
        "first_sync") echo "Sync..."    ; syncFirst        ;;
        "replace")    echo "Replace..." ; syncWithReplace  ;;
        "update")     echo "Update..."  ; syncWithUpdate   ;;
        "download")   echo "Download..."; syncWithDownload ;;
    esac
    echo "Done!"
}

#######################################
# Selection of synchronization options, if it is not the first time (if the folder of dotfiles exists)
# Globals:
#   SYNC_FOLDER
#######################################
chooseNextStep() {
    echo "${colorYellow}${bold}The '${SYNC_FOLDER}/dotfiles' already exists.${reset}"
    echo "${colorYellow}${bold}How will we connect to the sync folder?${reset}"

    echo "1 — Connect and replace all files in it"
    echo "2 — Connect and update obsolete files"
    echo "3 — Connect only"
    echo "4 - Cancel"
    echo ""

    while true; do
        echo -n "Your reply: "
        read -r res
        echo ""
        case $res in
            [1]) startSyncDot "replace" ; return 0 ;;
            [2]) startSyncDot "update"  ; return 0 ;;
            [3]) startSyncDot "download"; return 0 ;;
            [4]) echo "...Cancel" && exit ;;
        esac
    done
}

#######################################
# Disable file synchronization
# Deleting with a symlink on synchronization files and returning the original files to the user's home folder
# Globals:
#   BACKUP_FILES
#   SYNC_FOLDER
#######################################
disableSyncDot() {
    echo "${colorYellow}${bold}Restoring original files and turning off sync...${reset}"
    echo "---------------------------"
    for file in "${BACKUP_FILES[@]}"; do

        # Check if the file is a symlink and if the original exists in the sync folder
        if [[ -L ${file} ]] && [[ -e ${SYNC_FOLDER}/dotfiles/${file} ]]; then
            rm -rf ${file}
            rsync -aRq "${SYNC_FOLDER}/dotfiles/./${file}" ~
            echo "${file} — ${colorGreen}restored${reset}"
        else
            echo "${file} — ${colorRed}not found in sync folder${reset}"
        fi
        sleep 0.2
    done
    progressbar
    echo "Done!"
}
