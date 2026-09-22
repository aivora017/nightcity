# nightcity — zsh

export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nano

HISTFILE=~/.zsh_history
HISTSIZE=20000
SAVEHIST=20000
setopt share_history hist_ignore_dups hist_ignore_space autocd interactive_comments

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

alias qsr='pkill -x quickshell; QS_ICON_THEME=Papirus-Dark quickshell & disown'
alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

eval "$(starship init zsh)"

# ---------- modern tools (all use the terminal palette, so they follow the wallpaper) ----------
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first --git'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
export BAT_THEME="ansi"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

eval "$(zoxide init zsh)"

source <(fzf --zsh)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_DEFAULT_OPTS="--height 45% --layout reverse --border rounded \
  --color=fg:7,bg:-1,hl:4,fg+:15,bg+:0,hl+:4,info:6,prompt:4,pointer:5,marker:6,spinner:5,header:8,border:8"

source /usr/share/doc/pkgfile/command-not-found.zsh

# y opens yazi and leaves you in whatever folder you ended up in
function y() {
  local tmp="$(mktemp -t yazi-cwd.XXXXXX)" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then cd -- "$cwd"; fi
  rm -f -- "$tmp"
}

# ---------- modern tools (all use the terminal palette, so they follow the wallpaper) ----------
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first --git'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
export BAT_THEME="ansi"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

eval "$(zoxide init zsh)"

source <(fzf --zsh)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_DEFAULT_OPTS="--height 45% --layout reverse --border rounded \
  --color=fg:7,bg:-1,hl:4,fg+:15,bg+:0,hl+:4,info:6,prompt:4,pointer:5,marker:6,spinner:5,header:8,border:8"

source /usr/share/doc/pkgfile/command-not-found.zsh

# y opens yazi and leaves you in whatever folder you ended up in
function y() {
  local tmp="$(mktemp -t yazi-cwd.XXXXXX)" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then cd -- "$cwd"; fi
  rm -f -- "$tmp"
}
