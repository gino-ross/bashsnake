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

- Bash 4+
- A terminal with ANSI escape support (basically any modern terminal)
- `tput` (part of the ncurses package, available by default on most Unix-like systems)

## Platform compatibility

- **Linux** — fully supported
- **MacOS / BSD** — not supported (`date` syntax is GNU-specific)
  - May be supported in the future
- **Windows** — works under WSL or Git Bash, but native CMD/PowerShell not supported
