# claude-voice

Talk to [Claude Code](https://docs.anthropic.com/en/docs/claude-code) instead of typing.

Records audio directly in the terminal, transcribes via Google Speech API, and feeds the text to Claude Code as if you typed it.

## Prerequisites

| Dependency | Why | Install |
|-----------|-----|---------|
| [Homebrew](https://brew.sh) | Package manager (macOS) | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | CLI for Claude | `npm install -g @anthropic-ai/claude-code` |
| Python 3.8+ | Runtime | Installed automatically by `install.sh` if missing |
| Microphone access | Audio recording | Grant Terminal/iTerm mic permission in System Settings |

On **Linux**, `apt-get` is used instead of Homebrew. Python 3 is typically pre-installed.

## Install

```bash
git clone https://github.com/iAmSurajT/claude-voice.git
cd claude-voice
./install.sh
```

The installer handles everything else automatically:
- Installs `portaudio` via Homebrew (or apt on Linux)
- Installs Python packages (`sounddevice`, `scipy`, `SpeechRecognition`)
- Creates `/user:voice` slash command for Claude Code (works globally in any project)
- Adds `cv` shell alias to your `.zshrc` / `.bashrc`

## Usage

### Claude Code slash command

```
> /voice
```

Start speaking. Recording auto-stops after 5 seconds of silence. Claude responds as if you typed the transcribed text.

### Standalone terminal command

```bash
cv                # speak, press Enter to stop, prints transcript
cv | pbcopy       # copies transcript to clipboard
```

Interactive controls when run from a terminal:
- **Enter** - stop recording
- **Esc** - cancel

## How it works

```
  Voice Input

  * Recording (auto-stops after 5s silence)
  * [6.2s]
  * Recorded 8.1s
  * create a REST API with FastAPI

create a REST API with FastAPI          <-- stdout, fed to Claude
```

1. `sounddevice` records audio from your microphone
2. Silence detection determines when you stop speaking
3. `SpeechRecognition` sends audio to Google Speech API for transcription
4. Transcript goes to stdout, status messages to stderr
5. Claude Code treats stdout as your typed message

Two modes depending on context:

| Mode | Stop method | When |
|------|------------|------|
| TTY (terminal) | Press Enter or Esc | Running `cv` directly |
| Non-TTY (Claude Code) | Auto-stop after 5s silence | Running via `/voice` |

## Configuration

Edit `voice_input.py` to tune these values:

| Variable | Default | Description |
|----------|---------|-------------|
| `SILENCE_THRESHOLD` | 800 | Mic sensitivity (lower = more sensitive) |
| `SILENCE_DURATION` | 5.0 | Seconds of silence before auto-stop |
| `SAMPLE_RATE` | 16000 | Audio sample rate |

## Troubleshooting

**Microphone not working**
Grant mic access: macOS System Settings > Privacy & Security > Microphone > enable Terminal/iTerm.

**"Could not understand audio"**
Speak clearly, reduce background noise, check system mic input level.

**Recording stops too early**
Increase `SILENCE_DURATION` in `voice_input.py` (default 5.0 seconds).

**Import errors**
Re-run `./install.sh`, or manually: `python3 -m pip install sounddevice scipy SpeechRecognition`

**Homebrew not found**
Install from https://brew.sh, then re-run `./install.sh`.

## License

MIT
