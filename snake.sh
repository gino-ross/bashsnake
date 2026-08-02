#!/bin/bash
set -euo pipefail

stty_orig=$(stty -g)
stty raw -echo isig # raw input, signals still processed

# Restore terminal settings
cleanup() {
    stty "$stty_orig"
    printf "\e[?25h" # show cursor
}

# Cleanup on script end and kill signals
trap cleanup EXIT
trap "cleanup; exit 1" SIGINT SIGTERM

game_over=0
# score=0
x=10
y=10
frametime=0.5

printf "\e[?25l" # Hide cursor
clear

while [ $game_over == 0 ]; do

    # input handling
    if IFS= read -rn 1 -t "$frametime" key; then
        if [[ $key == $'\e' ]]; then #
            IFS= read -rn 2 rest
            key+="$rest"
        fi

        echo "$key"

        case "$key" in
        $'\e[A') ((y--)) ;;
        $'\e[B') ((y++)) ;;
        $'\e[C') ((x++)) ;;
        $'\e[D') ((x--)) ;;
        q) break ;;
        esac
    fi

    printf "\e[2J\e[H" # Clear
    printf "\e[%d;%dH@" "$y" "$x"
done
