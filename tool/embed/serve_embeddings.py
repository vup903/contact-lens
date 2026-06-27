"""Local embedding microservice for free-form queries in the live demo.

Loads the same multilingual MiniLM (ONNX via fastembed) used to bake the offline
vectors, and serves `POST /embed` so the Flutter app can embed *arbitrary* typed
queries at request time — not just the precomputed curated set. CORS is enabled
for the Flutter Web dev server.

    # from repo root, with tool/embed/.venv active (or use its python directly)
    python tool/embed/serve_embeddings.py            # listens on 127.0.0.1:8077

This service is OPTIONAL. Without it the app falls back to the precomputed
vectors (curated queries) and then to the lexical tier, so the demo still runs —
free-form semantic queries just won't have a vector. Pure stdlib HTTP server, no
web framework dependency.

Endpoints:
  GET  /health           -> {"ok": true}
  POST /embed  {"texts": ["..."]}  -> {"vectors": [[...], ...]}  (L2-normalized)
"""

from __future__ import annotations

import json
import math
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# Must match tool/embed/build_embeddings.py so runtime and precomputed vectors
# live in the same space.
MODEL_NAME = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
PORT = 8077

_model = None


def get_model():
    global _model
    if _model is None:
        from fastembed import TextEmbedding

        _model = TextEmbedding(model_name=MODEL_NAME)
    return _model


def l2_normalize(vec):
    norm = math.sqrt(sum(x * x for x in vec))
    if norm == 0:
        return [0.0 for _ in vec]
    return [x / norm for x in vec]


class Handler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/health"):
            self._json(200, {"ok": True, "model": MODEL_NAME})
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        if not self.path.startswith("/embed"):
            self._json(404, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(length) or b"{}")
            texts = body.get("texts")
            if texts is None and body.get("text") is not None:
                texts = [body["text"]]
            texts = [str(t) for t in (texts or [])]
            vectors = [
                l2_normalize([float(x) for x in v]) for v in get_model().embed(texts)
            ]
            self._json(200, {"vectors": vectors})
        except Exception as exc:  # keep the demo alive; report instead of crashing
            self._json(500, {"error": str(exc)})

    def log_message(self, *args):  # silence per-request logging
        pass


# Dual-stack server so the app reaching "localhost:8077" resolves correctly
# whether Windows hands it IPv6 (::1) or IPv4 (127.0.0.1).
class _DualStackServer(ThreadingHTTPServer):
    address_family = socket.AF_INET6

    def server_bind(self):
        try:
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        except (AttributeError, OSError):
            pass
        super().server_bind()


def main():
    get_model()  # load the model before accepting requests
    print(f"embedding service on http://localhost:{PORT}  (model {MODEL_NAME})")
    _DualStackServer(("", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
