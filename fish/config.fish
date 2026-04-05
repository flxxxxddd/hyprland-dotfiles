if status is-interactive
    set fish_greeting

    starship init fish | source
    ~/.config/kitty/scripts/fetch.sh

    # aliases
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias ls 'eza --icons'
    alias pamcan pacman
    alias fastfetch ~/.config/kitty/scripts/fetch.sh
    alias zed zeditor
    alias q 'qs -c ii'
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
