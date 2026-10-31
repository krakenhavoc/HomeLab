"""ReazonSpeech for wkjp's spoken reading answers.

POST /transcribe with the recorded clip as the body (webm/ogg/mp4/wav, as the
browser made it) returns {"text": ..., "seconds": ..., "ms": ...}. GET /health
returns {"ok": true}. nginx exposes /transcribe as /asr/transcribe; nothing else
reaches this container.

ReazonSpeech k2 v2 is a Japanese-only transducer, int8, on the CPU: about 50 ms
for a word on one thread. On the user's own takes it heard 11 of 23 where
Whisper large-v3-turbo heard 9, and it needs no GPU, so it keeps working when
KBU is hot or down.
"""

import io
import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import av
import numpy as np
import sherpa_onnx

MODEL = os.environ.get("MODEL_DIR", "/models")
THREADS = int(os.environ.get("THREADS", "2"))
MAX_BYTES = 10 * 1024 * 1024
RATE = 16000

recognizer = sherpa_onnx.OfflineRecognizer.from_transducer(
    encoder=f"{MODEL}/encoder-epoch-99-avg-1.int8.onnx",
    decoder=f"{MODEL}/decoder-epoch-99-avg-1.int8.onnx",
    joiner=f"{MODEL}/joiner-epoch-99-avg-1.int8.onnx",
    tokens=f"{MODEL}/tokens.txt",
    num_threads=THREADS,
    sample_rate=RATE,
    feature_dim=80,
    decoding_method="greedy_search",
)
# one clip at a time: the VM has two vCPUs and they're both this decode's
busy = threading.Lock()


def decode(data):
    """Any container/codec the browser records to 16 kHz mono float32."""
    out = []
    with av.open(io.BytesIO(data)) as c:
        rs = av.AudioResampler(format="flt", layout="mono", rate=RATE)
        for frame in c.decode(audio=0):
            out += [f.to_ndarray().reshape(-1) for f in rs.resample(frame)]
        out += [f.to_ndarray().reshape(-1) for f in rs.resample(None)]
    return np.concatenate(out).astype(np.float32) if out else np.zeros(0, np.float32)


class Handler(BaseHTTPRequestHandler):
    server_version = "wkjp-asr"

    def reply(self, code, body):
        raw = json.dumps(body, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path == "/health":
            return self.reply(200, {"ok": True})
        self.reply(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/transcribe":
            return self.reply(404, {"error": "not found"})
        n = int(self.headers.get("Content-Length") or 0)
        if not 0 < n <= MAX_BYTES:
            return self.reply(
                400, {"error": "send the clip as the request body, up to 10 MB"}
            )
        data = self.rfile.read(n)
        try:
            samples = decode(data)
        except Exception:
            return self.reply(400, {"error": "can't decode that audio"})
        if len(samples) < RATE // 10:  # under 0.1 s: nothing to hear
            return self.reply(
                200, {"text": "", "seconds": round(len(samples) / RATE, 2), "ms": 0}
            )
        t0 = time.time()
        with busy:
            s = recognizer.create_stream()
            s.accept_waveform(RATE, samples)
            recognizer.decode_stream(s)
            text = s.result.text.strip()
        self.reply(
            200,
            {
                "text": text,
                "seconds": round(len(samples) / RATE, 2),
                "ms": round(1000 * (time.time() - t0)),
            },
        )

    def log_message(self, fmt, *args):
        sys.stderr.write("asr %s\n" % (fmt % args))


if __name__ == "__main__":
    print(
        f"asr: ReazonSpeech k2 v2 int8, {THREADS} threads, listening on :8000",
        file=sys.stderr,
        flush=True,
    )
    ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
