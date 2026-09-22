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
