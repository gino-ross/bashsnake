# bashsnake

A classic Snake game written in pure Bash.

## Play

```sh
./snake.sh
```

Control the snake with the arrow keys. Eat the fruit to increase your score.

- **r** — restart after game over
- **q** — quit

## Requirements

- Bash 4+ (uses arrays)
- A terminal with ANSI escape support
- `tput` (ncurses)

## Platform compatibility

- **Linux** — fully supported
- **macOS / BSD** — not supported (`date +%s%N` is GNU-specific)
- **Windows** — works under WSL or Git Bash; native CMD/PowerShell not supported
