#!/usr/bin/env bash
# Simple UI helpers inspired by Mole.
set -euo pipefail

MC_COLOR_RESET="\033[0m"
MC_COLOR_BOLD="\033[1m"
MC_COLOR_GREEN="\033[32m"
MC_COLOR_YELLOW="\033[33m"
MC_COLOR_RED="\033[31m"
MC_COLOR_BLUE="\033[34m"

mc_color() {
  local color="$1"; shift
  printf "%b%s%b" "$color" "$*" "$MC_COLOR_RESET"
}

mc_header() {
  printf "%b%s%b\n" "$MC_COLOR_BOLD" "$*" "$MC_COLOR_RESET"
}

mc_info() { printf "%bℹ %s%b\n" "$MC_COLOR_BLUE" "$*" "$MC_COLOR_RESET"; }
mc_warn() { printf "%b⚠ %s%b\n" "$MC_COLOR_YELLOW" "$*" "$MC_COLOR_RESET"; }
mc_success() { printf "%b✓ %s%b\n" "$MC_COLOR_GREEN" "$*" "$MC_COLOR_RESET"; }
mc_error() { printf "%b✖ %s%b\n" "$MC_COLOR_RED" "$*" "$MC_COLOR_RESET"; }

# Interactive menu with arrows or vim keys.
mc_menu() {
  local prompt="$1"; shift
  local -a options=("$@")
  local index=0 key
  local stty_state
  stty_state=$(stty -g)
  printf "%s\n" "$prompt"
  while true; do
    for i in "${!options[@]}"; do
      if [[ $i -eq $index ]]; then
        printf " ▸ %b%s%b\n" "$MC_COLOR_GREEN" "${options[$i]}" "$MC_COLOR_RESET"
      else
        printf "   %s\n" "${options[$i]}"
      fi
    done
    IFS= read -rsn1 key
    case "$key" in
      $'\x1b')
        read -rsn2 key
        case "$key" in
          "[A") ((index=(index-1+${#options[@]})%${#options[@]}));;
          "[B") ((index=(index+1)%${#options[@]}));;
        esac;;
      j) ((index=(index+1)%${#options[@]}));;
      k) ((index=(index-1+${#options[@]})%${#options[@]}));;
      "") stty "$stty_state"; return $index;;
      q) stty "$stty_state"; return 255;;
    esac
    printf "\033[%dA" "$(( ${#options[@]} ))"
    printf "\r\033[K"
  done
}

