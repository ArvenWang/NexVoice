#!/usr/bin/env python3
import argparse
import json
import sys
import time

import sherpa_onnx
import soundfile as sf


def parse_args():
    parser = argparse.ArgumentParser(description="NexVoice SenseVoice transcriber")
    parser.add_argument("--model", required=True)
    parser.add_argument("--tokens", required=True)
    parser.add_argument("--wave", required=True)
    parser.add_argument("--language", default="auto")
    parser.add_argument("--use-itn", type=int, default=1)
    parser.add_argument("--num-threads", type=int, default=4)
    return parser.parse_args()


def main():
    args = parse_args()
    started = time.monotonic()
    recognizer = sherpa_onnx.OfflineRecognizer.from_sense_voice(
        model=args.model,
        tokens=args.tokens,
        num_threads=max(1, args.num_threads),
        language=args.language,
        use_itn=bool(args.use_itn),
        debug=False,
    )

    audio, sample_rate = sf.read(args.wave, dtype="float32", always_2d=True)
    mono = audio[:, 0]
    duration = float(len(mono)) / float(sample_rate) if sample_rate else 0.0

    stream = recognizer.create_stream()
    stream.accept_waveform(sample_rate, mono)
    recognizer.decode_stream(stream)

    payload = {
        "text": stream.result.text,
        "duration_seconds": duration,
        "elapsed_seconds": time.monotonic() - started,
    }
    print(json.dumps(payload, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise
