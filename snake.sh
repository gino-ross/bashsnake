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

# utility function for movement logic
is_opposite() {
    case "$1:$2" in
    up:down | down:up | left:right | right:left) return 0 ;;
    esac
    return 1
}

# reads arrow key input and adds requested directions to queue
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

# utility function for updating snake array
update_snake_array() {
    snake=("$(printf "%d,%d" "$head_y" "$head_x")" "${snake[@]}")
    old_cell=${snake[-1]}
    unset 'snake[-1]'
}

# update snake array according to movement
move_snake() {
    IFS=, read -r head_y head_x <<<"${snake[0]}"

    case "$current_dir" in
    up) ((head_y--)) ;;
    down) ((head_y++)) ;;
    left) ((head_x--)) ;;
    right) ((head_x++)) ;;
    esac
    update_snake_array
}

compute_bounds() {
    local termwidth
    termwidth=$(tput cols)
    local termheight
    termheight=$(tput lines)

    local padding=2

    local width=$((termwidth - padding * 2))
    local height=$((termheight - padding * 2))

    # account for zero-indexing to create a uniform border
    ((padding += 1))

    top_row_index=$padding
    bottom_row_index=$((padding + height))

    left_column_index=$padding
    right_column_index=$((padding + width))
}

draw_border() {
    # top and bottom borders
    for ((x = left_column_index; x <= right_column_index; x++)); do
        printf "\e[%d;%dH\u2588" "$top_row_index" "$x"
        printf "\e[%d;%dH\u2588" "$bottom_row_index" "$x"
    done
    # left and right borders
    for ((y = top_row_index; y <= bottom_row_index; y++)); do
        printf "\e[%d;%dH\u2588" "$y" "$left_column_index"
        printf "\e[%d;%dH\u2588" "$y" "$right_column_index"
    done
}

kill_snake() {
    printf "\e[%d;%dHX" "$1" "$2" # show head as X on collision
    game_over=1
}

hit_wall() {
    [[ $1 == "$left_column_index" || $1 == "$right_column_index" || $2 == "$top_row_index" || $2 == "$bottom_row_index" ]]
}

# returns 0 if no collision, 1 (game over) on wall or self collision
check_collisions() {
    local head=$1 head_y head_x
    IFS=, read -r head_y head_x <<<"$head"

    if hit_wall "$head_x" "$head_y"; then
        kill_snake "$head_y" "$head_x"
        return 1
    fi

    for segment in "${snake[@]:1}"; do
        if [[ $segment == "$head" ]]; then
            kill_snake "$head_y" "$head_x"
            return 1
        fi
    done
    return 0
}

# draw head, segments and clear old cells
draw_snake() {
    local head head_y head_x y x
    head=${snake[0]}
    IFS=, read -r head_y head_x <<<"$head"
    printf "\e[%d;%dH\u25A1" "$head_y" "$head_x"

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

# main game logic
game_over=0
# score=0
snake=("10,10" "10,9" "10,8" "10,7" "10,6" "10,5" "10,4")

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
compute_bounds
draw_border

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

        if check_collisions "${snake[0]}"; then
            draw_snake
        else
            break
        fi

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

sleep 1
printf "\n\n\n\n\ryou suck"
