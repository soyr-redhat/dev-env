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
_git_branch() {
    local b
    b=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    [ -n "$b" ] && echo " ${b}"
}

_venv_name() {
    [ -n "$VIRTUAL_ENV" ] && echo "($(basename "$VIRTUAL_ENV")) "
}

if [ -n "$ZSH_VERSION" ]; then
    _g='%{'"$(printf '\e[38;2;167;192;128m')"'%}'
    _a='%{'"$(printf '\e[38;2;131;165;152m')"'%}'
    _o='%{'"$(printf '\e[38;2;230;152;117m')"'%}'
    _y='%{'"$(printf '\e[38;2;219;188;127m')"'%}'
    _d='%{'"$(printf '\e[38;2;133;146;137m')"'%}'
    _r='%{'"$(printf '\e[0m')"'%}'
    setopt PROMPT_SUBST
    PROMPT='${_d}$(_venv_name)${_g}%n${_d}@${_a}%m ${_y}%~${_o}$(_git_branch)${_r}
${_g}❯${_r} '
else
    _g='\[\e[38;2;167;192;128m\]'
    _a='\[\e[38;2;131;165;152m\]'
    _o='\[\e[38;2;230;152;117m\]'
    _y='\[\e[38;2;219;188;127m\]'
    _d='\[\e[38;2;133;146;137m\]'
    _r='\[\e[0m\]'
    PS1="${_d}\$(_venv_name)${_g}\u${_d}@${_a}\h ${_y}\w${_o}\$(_git_branch)${_r}\n${_g}❯${_r} "
fi

# ---------- ls colors (everforest-ish) ----------
export LS_COLORS='di=38;2;131;165;152:ln=38;2;219;188;127:ex=38;2;167;192;128:*.py=38;2;230;152;117:*.yaml=38;2;131;165;152:*.yml=38;2;131;165;152:*.json=38;2;219;188;127:*.md=38;2;133;146;137'
alias ls='ls --color=auto'

# ---------- source extras ----------
[ -f "$HOME/.bash_profile.local" ] && source "$HOME/.bash_profile.local"
