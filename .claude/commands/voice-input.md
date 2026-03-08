Use Bash to run the voice input script and capture the output. It records audio inline in the terminal.

Run this exact command:
```
/usr/local/bin/python3.13 /Users/surajtripathi_1/codebase/ai-learn/claude-voice/voice_input.py
```

If the command succeeds (exit code 0), the stdout output is the user's transcribed voice message. Treat it as if the user typed that message directly - respond to it as a normal prompt.

If the command fails (exit code 1), the user cancelled voice input. Just say "Voice input cancelled." and wait for the next message.
