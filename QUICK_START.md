# Voice Input for Claude Code

Talk to Claude Code instead of typing. Records audio directly in the terminal -- no browser, no GUI windows.

## Install

```bash
./install.sh
```

The installer handles everything:
- Installs `portaudio` via Homebrew
- Installs Python packages (`sounddevice`, `scipy`, `SpeechRecognition`)
- Creates Claude Code slash commands (`/user:voice`, `/project:voice-input`)
- Adds a `cv` shell alias

## Use

### In Claude Code

```
> /voice
```

Recording starts automatically. Speak your message. It auto-stops after 5 seconds of silence, transcribes, and Claude responds as if you typed it.

### In your terminal

```bash
cv                # speak, press Enter to stop, prints transcript
cv | pbcopy       # same but copies to clipboard
```

In a real terminal you get interactive controls:
- `Enter` - stop recording
- `Esc` - cancel

## How It Works

```
  Voice Input

  ● Recording (auto-stops after 5s silence)
  ● [3.4s]
                          ← you speak here
  ● Recorded 8.1s
  ● please update the quick start md

please update the quick start md        ← this goes to stdout
```

1. `sounddevice` records audio from your microphone
2. Silence detection auto-stops when you finish speaking
3. `SpeechRecognition` sends audio to Google Speech API for transcription
4. Transcript prints to stdout (status messages go to stderr)
5. Claude Code treats the stdout output as your message

Two modes:
- **TTY** (real terminal): Enter to stop, Esc to cancel
- **Non-TTY** (Claude Code slash command): auto-stops after 5s silence

## Requirements

- Python 3.13 (installed via Homebrew)
- macOS or Linux
- Microphone access granted to Terminal/iTerm

## What Gets Installed

| What | Where | Purpose |
|------|-------|---------|
| `portaudio` | Homebrew | Audio backend |
| `sounddevice`, `scipy`, `SpeechRecognition` | pip (python3.13) | Recording + transcription |
| `/user:voice` | `~/.claude/commands/voice.md` | Global slash command |
| `/project:voice-input` | `.claude/commands/voice-input.md` | Project slash command |
| `cv` alias | `~/.zshrc` or `~/.bashrc` | Standalone shell usage |

## Troubleshooting

**Microphone not working**
- macOS: System Settings > Privacy & Security > Microphone > enable Terminal/iTerm
- Test with: `python3.13 -c "import sounddevice; print(sounddevice.query_devices())"`

**"Could not understand audio"**
- Speak clearly, close to the microphone
- Check system mic input level
- Reduce background noise

**Recording stops too early / too late**
- Edit `SILENCE_DURATION` in `voice_input.py` (default: 5.0 seconds)
- Edit `SILENCE_THRESHOLD` for mic sensitivity (default: 800)

**Import errors**
```bash
/usr/local/bin/python3.13 -c "import sounddevice, scipy, speech_recognition"
```
If this fails, re-run `./install.sh`.
