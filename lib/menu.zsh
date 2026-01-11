#!/usr/bin/env zsh
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#        File:  menu.zsh
#
#        Name:  MacSync Menu
# Description:  Interactive arrow-key menu for terminal
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Menu configuration
typeset -g MENU_SELECTED=0
typeset -g MENU_RESULT=""

#######################################
# Display an interactive menu with arrow key navigation
# Arguments:
#   $1 - Prompt text
#   $@ - Menu options (remaining arguments)
# Outputs:
#   Sets MENU_RESULT to the selected option (1-indexed)
# Returns:
#   0 on selection, 1 on cancel (Escape/q)
#######################################
menu_select() {
  local prompt="$1"
  shift
  local -a options=("$@")
  local num_options=${#options[@]}
  local selected=0
  local key=""
  local _menu_drawn=""
  
  # Detect if stdin is not a TTY (piped input)
  if [[ ! -t 0 ]]; then
    # Non-interactive mode: simple output and line-based read
    echo "${prompt}"
    local i=1
    for opt in "${options[@]}"; do
      echo "  $i. $opt"
      ((i++))
    done
    
    # Read a line from stdin and take first character
    # This allows multi-line input like "1\n2" for sequential menus
    local line=""
    IFS= read -r line || line=""
    key="${line:0:1}"
    
    # Handle numeric input (1-9)
    case "$key" in
      [1-9])
        local num_key=$((key))
        if (( num_key >= 1 && num_key <= num_options )); then
          MENU_RESULT=$num_key
          MENU_SELECTED=$((num_key - 1))
          return 0
        fi
        ;;
      q|Q)
        MENU_RESULT=0
        return 1
        ;;
      *)
        # Empty or invalid input — return error
        MENU_RESULT=0
        return 1
        ;;
    esac
  fi
  
  # Interactive mode: full terminal UI
  
  # Hide cursor
  printf '\e[?25l'
  
  # Ensure cursor is shown on exit (save previous trap)
  local _old_trap=$(trap -p EXIT)
  trap 'printf "\e[?25h"' EXIT INT TERM
  
  # Helper to restore trap and show cursor
  _menu_cleanup() {
    printf '\e[?25h'
    trap - EXIT INT TERM
    [[ -n "$_old_trap" ]] && eval "$_old_trap"
  }
  
  # Draw menu
  _menu_draw() {
    # Move cursor up to redraw (only after first draw)
    if [[ -n "$_menu_drawn" ]]; then
      printf '\e[%dA' "$((num_options + 1))"
    fi
    _menu_drawn=1
    
    # Print prompt (clear line first)
    printf '\e[2K%s\n' "${prompt}"
    
    # Print options with numbers
    local i=0
    for opt in "${options[@]}"; do
      printf '\e[2K'  # Clear line
      if (( i == selected )); then
        printf '%s▸ %d. %s%s\n' "${colorGreen:-}" "$((i + 1))" "$opt" "${reset:-}"
      else
        printf '  %d. %s\n' "$((i + 1))" "$opt"
      fi
      ((i++))
    done
  }
  
  # Initial draw
  _menu_draw
  
  # Read keys
  while true; do
    # Read single character (with timeout for escape sequences)
    read -r -s -k 1 key 2>/dev/null
    
    case "$key" in
      # Arrow keys (escape sequences)
      $'\e')
        read -r -s -k 2 -t 0.1 key 2>/dev/null
        case "$key" in
          '[A'|'OA') # Up arrow
            ((selected--))
            (( selected < 0 )) && selected=$((num_options - 1))
            ;;
          '[B'|'OB') # Down arrow
            ((selected++))
            (( selected >= num_options )) && selected=0
            ;;
        esac
        ;;
      # Vim-style navigation
      'k'|'K')
        ((selected--))
        (( selected < 0 )) && selected=$((num_options - 1))
        ;;
      'j'|'J')
        ((selected++))
        (( selected >= num_options )) && selected=0
        ;;
      # Enter - select
      ''|$'\n')
        # Move to prompt line and show selection inline
        printf '\e[%dA' "$((num_options + 1))"
        printf '\e[2K%s %s%s%s\n' "${prompt}" "${colorGreen:-}" "${options[$((selected + 1))]}" "${reset:-}"
        # Move cursor past the menu area
        printf '\e[%dB' "$num_options"
        _menu_cleanup
        MENU_RESULT=$((selected + 1))
        MENU_SELECTED=$selected
        return 0
        ;;
      # Quit
      'q'|'Q')
        _menu_cleanup
        MENU_RESULT=0
        return 1
        ;;
      # Numeric selection (1-9)
      [1-9])
        local num_key=$((key))
        if (( num_key >= 1 && num_key <= num_options )); then
          selected=$((num_key - 1))
          printf '\e[%dA' "$((num_options + 1))"
          printf '\e[2K%s %s%s%s\n' "${prompt}" "${colorGreen:-}" "${options[$num_key]}" "${reset:-}"
          printf '\e[%dB' "$num_options"
          _menu_cleanup
          MENU_RESULT=$num_key
          MENU_SELECTED=$selected
          return 0
        fi
        ;;
    esac
    
    _menu_draw
  done
}
