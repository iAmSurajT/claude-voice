#!/usr/bin/env python3
"""Voice input for Claude Code - terminal inline.

Two modes:
  - TTY (real terminal):  Press Enter to stop, Esc to cancel
  - Non-TTY (Claude Code): Auto-stops after silence

Status messages go to stderr. Only the final transcript goes to stdout.

Dependencies: sounddevice, scipy, SpeechRecognition
"""

import io
import os
import select
import signal
import sys
import threading
import time

import numpy as np
import scipy.io.wavfile as wavfile
import sounddevice as sd
import speech_recognition as sr

SAMPLE_RATE = 16000
CHANNELS = 1
SILENCE_THRESHOLD = 800
SILENCE_DURATION = 5.0  # seconds of silence before auto-stop

# ANSI colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
DIM = "\033[0;90m"
BOLD = "\033[1m"
RESET = "\033[0m"


def eprint(*args, **kwargs):
    """Print to stderr (keeps stdout clean for the transcript)."""
    print(*args, file=sys.stderr, flush=True, **kwargs)


def is_tty():
    """Check if stdin is a real terminal."""
    try:
        return os.isatty(sys.stdin.fileno())
    except Exception:
        return False


def is_silent(audio_chunk, threshold=SILENCE_THRESHOLD):
    """Check if an audio chunk is silence."""
    return np.abs(audio_chunk).mean() < threshold


def record_with_tty():
    """Record with interactive terminal controls (Enter to stop)."""
    import termios
    import tty

    audio_frames = []
    is_recording = True
    start_time = time.time()

    def audio_callback(indata, frames, time_info, status):
        if is_recording:
            audio_frames.append(indata.copy())

    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)

    try:
        stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=CHANNELS,
            dtype="int16",
            callback=audio_callback,
            blocksize=1024,
        )
        stream.start()
        tty.setraw(fd)

        spinner = ["●", "○"]
        spin_idx = 0

        while True:
            elapsed = time.time() - start_time
            frame = spinner[spin_idx % len(spinner)]
            spin_idx += 1

            sys.stderr.write(
                f"\r  {RED}{frame}{RESET} {BOLD}Recording{RESET} "
                f"{DIM}[{elapsed:.1f}s]{RESET}  "
                f"{DIM}Enter=stop  Esc=cancel{RESET}   "
            )
            sys.stderr.flush()

            if select.select([sys.stdin], [], [], 0.3)[0]:
                ch = os.read(fd, 1)
                if ch in (b"\r", b"\n"):
                    break
                if ch in (b"\x1b", b"\x03"):
                    is_recording = False
                    stream.stop()
                    stream.close()
                    sys.stderr.write("\r" + " " * 60 + "\r")
                    sys.stderr.flush()
                    return None

        is_recording = False
        stream.stop()
        stream.close()

        sys.stderr.write("\r" + " " * 60 + "\r")
        sys.stderr.flush()
        elapsed = time.time() - start_time
        eprint(f"  {GREEN}●{RESET} Recorded {elapsed:.1f}s")

    except Exception as e:
        eprint(f"\r  {RED}Mic error:{RESET} {e}")
        return None
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

    if not audio_frames:
        return None

    return np.concatenate(audio_frames, axis=0)


def record_with_silence_detection():
    """Record until silence is detected (for non-TTY environments)."""
    audio_frames = []
    is_recording = True
    start_time = time.time()
    last_sound_time = time.time()
    has_speech = False
    stop_event = threading.Event()

    def audio_callback(indata, frames, time_info, status):
        nonlocal last_sound_time, has_speech
        if not is_recording:
            return
        audio_frames.append(indata.copy())
        if not is_silent(indata):
            last_sound_time = time.time()
            has_speech = True

    try:
        stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=CHANNELS,
            dtype="int16",
            callback=audio_callback,
            blocksize=1024,
        )
        stream.start()

        eprint(f"  {RED}●{RESET} {BOLD}Recording{RESET} {DIM}(auto-stops after {SILENCE_DURATION:.0f}s silence){RESET}")

        spinner = ["●", "○"]
        spin_idx = 0

        while not stop_event.is_set():
            elapsed = time.time() - start_time
            silence_elapsed = time.time() - last_sound_time
            frame = spinner[spin_idx % len(spinner)]
            spin_idx += 1

            sys.stderr.write(
                f"\r  {RED}{frame}{RESET} {DIM}[{elapsed:.1f}s]{RESET}   "
            )
            sys.stderr.flush()

            # Auto-stop after silence (only if we detected speech first)
            if has_speech and silence_elapsed >= SILENCE_DURATION:
                break

            # Safety timeout: 120 seconds max
            if elapsed >= 120:
                break

            time.sleep(0.3)

        is_recording = False
        stream.stop()
        stream.close()

        sys.stderr.write("\r" + " " * 40 + "\r")
        sys.stderr.flush()
        elapsed = time.time() - start_time
        eprint(f"  {GREEN}●{RESET} Recorded {elapsed:.1f}s")

    except Exception as e:
        eprint(f"  {RED}Mic error:{RESET} {e}")
        return None

    if not audio_frames:
        return None

    return np.concatenate(audio_frames, axis=0)


def transcribe(audio_data):
    """Transcribe audio data using Google Speech API."""
    eprint(f"  {YELLOW}●{RESET} Transcribing...")

    try:
        buf = io.BytesIO()
        wavfile.write(buf, SAMPLE_RATE, audio_data)
        buf.seek(0)

        recognizer = sr.Recognizer()
        with sr.AudioFile(buf) as source:
            audio = recognizer.record(source)

        text = recognizer.recognize_google(audio)

        # Overwrite "Transcribing..." line
        sys.stderr.write("\033[A\r" + " " * 40 + "\r")
        sys.stderr.flush()
        eprint(f"  {GREEN}●{RESET} {DIM}{text}{RESET}")

        return text

    except sr.UnknownValueError:
        sys.stderr.write("\033[A\r" + " " * 40 + "\r")
        sys.stderr.flush()
        eprint(f"  {RED}●{RESET} Could not understand audio")
        return None
    except sr.RequestError as e:
        sys.stderr.write("\033[A\r" + " " * 40 + "\r")
        sys.stderr.flush()
        eprint(f"  {RED}●{RESET} API error: {e}")
        return None
    except Exception as e:
        sys.stderr.write("\033[A\r" + " " * 40 + "\r")
        sys.stderr.flush()
        eprint(f"  {RED}●{RESET} Error: {e}")
        return None


def main():
    signal.signal(signal.SIGINT, lambda s, f: sys.exit(1))

    if is_tty():
        eprint(f"\n  {BOLD}Voice Input{RESET} {DIM}(speak, then press Enter){RESET}\n")
        audio_data = record_with_tty()
    else:
        eprint(f"\n  {BOLD}Voice Input{RESET}\n")
        audio_data = record_with_silence_detection()

    if audio_data is None:
        eprint()
        sys.exit(1)

    text = transcribe(audio_data)
    if text is None:
        eprint()
        sys.exit(1)

    eprint()
    print(text)


if __name__ == "__main__":
    main()
