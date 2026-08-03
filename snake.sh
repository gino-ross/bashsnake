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

is_opposite() {
    case "$1:$2" in
    up:down | down:up | left:right | right:left) return 0 ;;
    esac
    return 1
}

poll_input() {
    local key rest dir ref
    while IFS= read -t 0.001 -rn 1 key; do
        if [[ $key == $'\e' ]]; then
            rest=""
            IFS= read -t 0.001 -rn 2 rest || break
            key+="$rest"
        fi

        case "$key" in
        $'\e[A') dir="up" ;;
        $'\e[B') dir="down" ;;
        $'\e[C') dir="right" ;;
        $'\e[D') dir="left" ;;
        q) break ;;
        *) continue ;;
        esac

        # process new direction inputs with priority on buffered dirchanges
        # fixes instant 180 turns caused by higher rate input polling
        if ((${#dir_queue[@]} > 0)); then
            ref="${dir_queue[-1]}"
        else
            ref="$current_dir"
        fi
        if ! is_opposite "$ref" "$dir"; then
            dir_queue+=("$dir")
        fi
    done
}

move_snake() {
    case "$current_dir" in
    up) ((y--)) ;;
    down) ((y++)) ;;
    left) ((x--)) ;;
    right) ((x++)) ;;
    esac
}

# main game logic
game_over=0
# score=0
x=10
y=10

# Dir queue to allow input buffering
dir_queue=()
current_dir="right"

render_dt=16666667 # ~60fps, in nanoseconds
move_dt=100000000  # 0.1s, in nanoseconds

now=$(date +%s%N)
next_render=$now
next_move=$now

printf "\e[?25l" # Hide cursor
clear

while [ $game_over == 0 ]; do

    # input handling
    poll_input

    now=$(date +%s%N)

    # movement tick
    if ((now >= next_move)); then
        if ((${#dir_queue[@]} > 0)); then
            current_dir="${dir_queue[0]}"
            dir_queue=("${dir_queue[@]:1}")
        fi
        move_snake
        next_move=$((next_move + move_dt))
    fi

    # render tick
    if ((now >= next_render)); then
        printf "\e[2J\e[H" # Clear
        printf "\e[%d;%dH@" "$y" "$x"
        next_render=$((next_render + render_dt))
    fi

    # sleep until the next render deadline
    sleep_time_ns=$((next_render - now))
    if ((sleep_time_ns > 0)); then
        sleep "$(awk -v n="$sleep_time_ns" 'BEGIN {printf "%.6f", n/1000000000}')"
    fi
done
