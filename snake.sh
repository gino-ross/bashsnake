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

poll_input() {
    local key rest
    while IFS= read -t 0.001 -rn 1 key; do
        if [[ $key == $'\e' ]]; then
            rest=""
            IFS= read -t 0.001 -rn 2 rest || break
            key+="$rest"
        fi

        case "$key" in
        $'\e[A') requested_dir="up" ;;
        $'\e[B') requested_dir="down" ;;
        $'\e[C') requested_dir="right" ;;
        $'\e[D') requested_dir="left" ;;
        q) break ;;
        esac
    done
}

update_direction() {
    # validate direction change
    case "$current_dir:$requested_dir" in
    up:down | down:up | left:right | right:left)
        ;; # ignore 180 turns
    *)
        current_dir="$requested_dir"
        ;;
    esac
}

move_snake() {
    case "$current_dir" in
    up) ((y--)) ;;
    down) ((y++)) ;;
    left) ((x--)) ;;
    right) ((x++)) ;;
    esac
}

game_over=0
# score=0
x=10
y=10
requested_dir="right"
current_dir="right"
frametime=0.1

printf "\e[?25l" # Hide cursor
clear

while [ $game_over == 0 ]; do

    # input handling
    poll_input

    update_direction

    move_snake

    printf "\e[2J\e[H" # Clear
    printf "\e[%d;%dH@" "$y" "$x"
    sleep "$frametime"
done
