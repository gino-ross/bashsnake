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

update_snake_array() {
    snake=("$(printf "%d,%d" "$head_y" "$head_x")" "${snake[@]}")
    old_cell=${snake[-1]}
    unset 'snake[-1]'
}

move_snake() {
    IFS=, read -r head_y head_x <<<"${snake[0]}"

    case "$current_dir" in
    up)
        ((head_y--))
        update_snake_array
        ;;
    down)
        ((head_y++))
        update_snake_array
        ;;
    left)
        ((head_x--))
        update_snake_array
        ;;
    right)
        ((head_x++))
        update_snake_array
        ;;
    esac
}

draw_snake() {
    # unique icon for head
    IFS=, read -r y x <<<"${snake[0]}"
    printf "\e[%d;%dH\u25A1" "$y" "$x"

    for segment in "${snake[@]:1}"; do
        IFS=, read -r y x <<<"$segment"
        printf "\e[%d;%dH\u25A0" "$y" "$x"
    done

    # clear last removed cell (won't run if fruit picked up)
    IFS=, read -r y x <<<"$old_cell"
    if [ "$old_cell" ]; then
        printf "\e[%d;%dH " "$y" "$x"
    fi
}

draw_border() {
    local width=40
    local height=20

    # top and bottom borders
    for ((x = 1; x <= width; x++)); do
        printf "\e[1;%dH\u2588" "$x"
        printf "\e[%d;%dH\u2588" "$height" "$x"
    done

    for ((y = 1; y <= height; y++)); do
        printf "\e[%d;1H\u2588" "$y"
        printf "\e[%d;%dH\u2588" "$y" "$width"
    done

}

# main game logic
game_over=0
# score=0
snake=("10,10" "10,9")

# Dir queue to allow input buffering
dir_queue=()
current_dir="right"

poll_dt=16666667  # ~60fps, in nanoseconds
tick_dt=100000000 # 0.1s, in nanoseconds

now=$(date +%s%N)
next_poll=$now
next_tick=$now

printf "\e[?25l" # Hide cursor
clear
# draw_border

while [ $game_over == 0 ]; do
    now=$(date +%s%N)

    # input handling
    poll_input

    # movement and render tick
    while ((now >= next_tick)); do
        if ((${#dir_queue[@]} > 0)); then
            current_dir="${dir_queue[0]}"
            dir_queue=("${dir_queue[@]:1}")
        fi

        move_snake

        draw_snake

        next_tick=$((next_tick + tick_dt))
    done

    next_poll=$((next_poll + poll_dt))

    # calculate time to sleep before next poll
    now=$(date +%s%N)
    sleep_time_ns=$((next_poll - now))

    if ((sleep_time_ns > 0)); then
        sleep "$(awk -v n="$sleep_time_ns" 'BEGIN {printf "%.6f", n/1000000000}')"
    fi
done
