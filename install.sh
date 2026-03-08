#!/usr/bin/env bash
set -euo pipefail

# Claude Voice Input - Installer
# Installs all dependencies and creates slash commands + shell alias.
# Works on macOS and Linux. Requires Homebrew on macOS.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VOICE_SCRIPT="$SCRIPT_DIR/voice_input.py"

RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[0;90m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}Claude Voice Input - Installer${RESET}"
echo -e "${DIM}────────────────────────────────${RESET}"

# --- Find or install Python 3 ---

find_python() {
    # Prefer python3.13+ from brew, fall back to any python3
    for candidate in python3.13 python3.12 python3.11 python3; do
        local path
        path=$(command -v "$candidate" 2>/dev/null) || continue
        # Verify it actually works
        if "$path" -c "import sys; assert sys.version_info >= (3, 8)" &>/dev/null 2>&1; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

PY=$(find_python) || true

if [[ -z "$PY" ]]; then
    if command -v brew &>/dev/null; then
        echo -e "  ${DIM}No suitable Python found. Installing python@3.13 via brew...${RESET}"
        brew install python@3.13 >/dev/null 2>&1
        PY=$(find_python) || true
        if [[ -z "$PY" ]]; then
            echo -e "  ${RED}Error: Python installation failed. Install Python 3.8+ manually.${RESET}"
            exit 1
        fi
    else
        echo -e "  ${RED}Error: Python 3.8+ not found and Homebrew not available.${RESET}"
        echo -e "  ${RED}Install Homebrew first: https://brew.sh${RESET}"
        exit 1
    fi
fi

PY_VERSION=$($PY -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo -e "  Python:  ${GREEN}$PY_VERSION${RESET} ($PY)"

# --- Install system dependencies ---

if [[ "$(uname)" == "Darwin" ]]; then
    if command -v brew &>/dev/null; then
        if ! brew list portaudio &>/dev/null 2>&1; then
            echo -e "  ${DIM}Installing portaudio via brew...${RESET}"
            brew install portaudio >/dev/null 2>&1
            echo -e "  portaudio: ${GREEN}installed${RESET}"
        else
            echo -e "  portaudio: ${DIM}already installed${RESET}"
        fi
    else
        echo -e "  ${RED}Homebrew not found. Install portaudio manually.${RESET}"
    fi
elif [[ "$(uname)" == "Linux" ]]; then
    if command -v apt-get &>/dev/null; then
        if ! dpkg -s portaudio19-dev &>/dev/null 2>&1; then
            echo -e "  ${DIM}Installing portaudio via apt...${RESET}"
            sudo apt-get install -y -qq portaudio19-dev >/dev/null 2>&1 || true
            echo -e "  portaudio: ${GREEN}installed${RESET}"
        else
            echo -e "  portaudio: ${DIM}already installed${RESET}"
        fi
    fi
fi

# --- Install Python dependencies ---

NEEDS_INSTALL=false
for pkg in sounddevice scipy speech_recognition; do
    if ! $PY -c "import $pkg" &>/dev/null 2>&1; then
        NEEDS_INSTALL=true
        break
    fi
done

if $NEEDS_INSTALL; then
    echo -e "  ${DIM}Installing Python packages...${RESET}"
    if $PY -m pip install --quiet --break-system-packages sounddevice scipy SpeechRecognition 2>/dev/null || \
       $PY -m pip install --quiet sounddevice scipy SpeechRecognition 2>/dev/null; then
        echo -e "  Packages: ${GREEN}sounddevice, scipy, SpeechRecognition${RESET}"
    else
        echo -e "  ${RED}Error: Failed to install Python packages.${RESET}"
        echo -e "  ${RED}Try manually: $PY -m pip install sounddevice scipy SpeechRecognition${RESET}"
        exit 1
    fi
else
    echo -e "  Packages: ${DIM}already installed${RESET}"
fi

# --- Verify imports ---

if ! $PY -c "import sounddevice, scipy, speech_recognition" &>/dev/null 2>&1; then
    echo -e "  ${RED}Warning: Some imports failed. Run: $PY -c 'import sounddevice, scipy, speech_recognition'${RESET}"
fi

# Make voice_input.py executable
chmod +x "$VOICE_SCRIPT"
echo -e "  Script:  ${GREEN}$VOICE_SCRIPT${RESET}"

# --- Create Claude Code slash commands ---

COMMAND_BODY="Use Bash to run the voice input script and capture the output. It records audio inline in the terminal.

Run this exact command:
\`\`\`
$PY $VOICE_SCRIPT
\`\`\`

If the command succeeds (exit code 0), the stdout output is the user's transcribed voice message. Treat it as if the user typed that message directly - respond to it as a normal prompt.

If the command fails (exit code 1), the user cancelled voice input. Just say \"Voice input cancelled.\" and wait for the next message."

# User-level command (works globally in any project)
USER_CMD_DIR="$HOME/.claude/commands"
mkdir -p "$USER_CMD_DIR"
echo "$COMMAND_BODY" > "$USER_CMD_DIR/voice.md"
echo -e "  Command: ${GREEN}/user:voice${RESET} (global)"

# --- Shell alias ---

ALIAS_LINE="alias cv='$PY \"$VOICE_SCRIPT\"'"
SHELL_RC=""

if [[ "${SHELL:-}" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "${SHELL:-}" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -qF "alias cv=" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Claude Voice Input" >> "$SHELL_RC"
        echo "$ALIAS_LINE" >> "$SHELL_RC"
        echo -e "  Alias:   ${GREEN}cv${RESET} (added to $SHELL_RC)"
    else
        # Update existing alias to point to current path
        grep -v "alias cv=" "$SHELL_RC" > "$SHELL_RC.tmp" && mv "$SHELL_RC.tmp" "$SHELL_RC"
        echo "$ALIAS_LINE" >> "$SHELL_RC"
        echo -e "  Alias:   ${GREEN}cv${RESET} (updated in $SHELL_RC)"
    fi
fi

# --- Done ---

echo ""
echo -e "${GREEN}${BOLD}Installed!${RESET}"
echo ""
echo -e "  ${BOLD}Usage in Claude Code:${RESET}"
echo -e "    /user:voice       ${DIM}(works in any project)${RESET}"
echo ""
echo -e "  ${BOLD}Standalone (in terminal):${RESET}"
echo -e "    cv                ${DIM}(speak, press Enter to stop, prints transcript)${RESET}"
echo -e "    cv | pbcopy       ${DIM}(same but copies to clipboard)${RESET}"
echo ""
echo -e "  ${BOLD}Modes:${RESET}"
echo -e "    Terminal:  ${DIM}Enter=stop  Esc=cancel${RESET}"
echo -e "    Claude:    ${DIM}auto-stops after 5s silence${RESET}"
echo ""
if [[ -n "$SHELL_RC" ]]; then
    echo -e "${DIM}Run 'source $SHELL_RC' or open a new terminal for the alias.${RESET}"
fi
