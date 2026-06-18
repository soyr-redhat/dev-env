#!/bin/bash
# Sawyer's devenv — sourced on login

DEVENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- auto-update ----------
if [ -d "$DEVENV_DIR/.git" ]; then
    (cd "$DEVENV_DIR" && git pull --ff-only --quiet 2>/dev/null)
fi

# ---------- env ----------
export HF_HOME="${HF_HOME:-$HOME/.cache/huggingface}"
export UV_CACHE_DIR="${UV_CACHE_DIR:-$HOME/.cache/uv}"
export EDITOR=vim

# ---------- aliases ----------
alias ll='ls -alF'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'

# ---------- uv venv helpers ----------
uva() {
    if [ -z "$1" ]; then
        echo "Usage: uva <venv-name>"
        echo "Available:"
        ls -1 "$HOME/.venvs/" 2>/dev/null || echo "  (none — create with: uv venv ~/.venvs/<name>)"
        return 1
    fi
    source "$HOME/.venvs/$1/bin/activate"
}

# ---------- oc helpers ----------
ocproject() {
    oc project "${1:-machine-learning}"
}

ocgpus() {
    oc get nodes -l nvidia.com/gpu.present=true -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1:].type,GPUs:.status.allocatable.nvidia\\.com/gpu
}

# ---------- logging ----------
dolog() {
    mkdir -p "$HOME/logs"
    local logfile="$HOME/logs/$(date +%Y-%m-%d).log"
    echo "[$(date +%H:%M:%S)] $*" >> "$logfile"
    echo "Logged to $logfile"
}

# ---------- everforest prompt ----------
_ef_bg="\[\e[38;2;51;63;48m\]"
_ef_green="\[\e[38;2;167;192;128m\]"
_ef_aqua="\[\e[38;2;131;165;152m\]"
_ef_orange="\[\e[38;2;230;152;117m\]"
_ef_grey="\[\e[38;2;133;146;137m\]"
_ef_yellow="\[\e[38;2;219;188;127m\]"
_ef_red="\[\e[38;2;230;126;128m\]"
_ef_reset="\[\e[0m\]"

_git_branch() {
    local b
    b=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    [ -n "$b" ] && echo " ${b}"
}

_venv_name() {
    [ -n "$VIRTUAL_ENV" ] && echo "($(basename "$VIRTUAL_ENV")) "
}

PS1="${_ef_grey}\$(_venv_name)${_ef_green}\u${_ef_grey}@${_ef_aqua}\h ${_ef_yellow}\w${_ef_orange}\$(_git_branch)${_ef_reset}\n${_ef_green}❯${_ef_reset} "

# ---------- ls colors (everforest-ish) ----------
export LS_COLORS='di=38;2;131;165;152:ln=38;2;219;188;127:ex=38;2;167;192;128:*.py=38;2;230;152;117:*.yaml=38;2;131;165;152:*.yml=38;2;131;165;152:*.json=38;2;219;188;127:*.md=38;2;133;146;137'
alias ls='ls --color=auto'

# ---------- source extras ----------
[ -f "$HOME/.bash_profile.local" ] && source "$HOME/.bash_profile.local"
