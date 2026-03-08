# claude-voice

Talk to [Claude Code](https://docs.anthropic.com/en/docs/claude-code) instead of typing.

Records audio directly in the terminal, transcribes via Google Speech API, and feeds the text to Claude Code as if you typed it.

## Install

```bash
git clone https://github.com/iAmSurajT/claude-voice.git
cd claude-voice
./install.sh
```

The installer handles everything automatically:
- Installs `portaudio` (Homebrew on macOS, apt on Linux)
- Installs Python packages (`sounddevice`, `scipy`, `SpeechRecognition`)
- Creates `/user:voice` slash command for Claude Code
- Adds `cv` shell alias

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

1. `sounddevice` records audio from your microphone
2. Silence detection determines when you stop speaking
3. `SpeechRecognition` sends audio to Google Speech API
4. Transcript goes to stdout, status messages to stderr
5. Claude Code treats stdout as your typed message

Two modes depending on context:

| Mode | Stop method | When |
|------|------------|------|
| TTY (terminal) | Press Enter or Esc | Running `cv` directly |
| Non-TTY (Claude Code) | Auto-stop after 5s silence | Running via `/voice` |

## Requirements

- Python 3.8+
- macOS or Linux
- Microphone access granted to Terminal/iTerm
- Internet connection (for Google Speech API)

## Configuration

Edit `voice_input.py` to tune these values:

| Variable | Default | Description |
|----------|---------|-------------|
| `SILENCE_THRESHOLD` | 800 | Mic sensitivity (lower = more sensitive) |
| `SILENCE_DURATION` | 5.0 | Seconds of silence before auto-stop |
| `SAMPLE_RATE` | 16000 | Audio sample rate |

## Troubleshooting

**Microphone not working** - Grant mic access: macOS System Settings > Privacy & Security > Microphone > Terminal

**"Could not understand audio"** - Speak clearly, reduce background noise, check mic input level

**Recording stops too early** - Increase `SILENCE_DURATION` in `voice_input.py`

**Import errors** - Re-run `./install.sh`

## License

MIT
