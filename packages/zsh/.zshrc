# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
export PATH="/opt/homebrew/opt/dotnet@8/bin:$PATH"
export PATH="/opt/homebrew/opt/dotnet@9/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="/usr/local/nvim/bin:$PATH"
export NVIM_APPNAME="nvim-scratch"


tmuxpick () {
    local session
    session=$(tmux ls -F '#{session_name}' | fzf) || return
    [[ -n "$session" ]] || return
    tmux attach -t "$session"
}




# autoload -Uz compinit
# compinit

# Load Angular CLI autocompletion.
# source <(ng completion script)

# Enable Powerlevel10k theme
for theme in /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme /usr/local/share/powerlevel10k/powerlevel10k.zsh-theme; do
  if [[ -r "$theme" ]]; then source "$theme"; break; fi
done
unset theme
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Credentials, work helpers, and machine-specific overrides stay outside Git.
[[ ! -r "$HOME/.config/zsh/local.zsh" ]] || source "$HOME/.config/zsh/local.zsh"
