"""Serve the built Flutter web demo locally — stable, offline, one command.

Serves `build/web` over http://localhost:8000 with correct MIME types (so the
CanvasKit .wasm loads cleanly) and opens the browser. No Flutter dev server, no
embedding service required: the demo queries are baked into the app, so the
whole walkthrough runs offline with zero moving parts.

    python tool/serve_web.py
"""
import http.server
import os
import socketserver
import threading
import webbrowser

PORT = 8000
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".mjs": "text/javascript",
        ".wasm": "application/wasm",
        ".json": "application/json",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=os.path.abspath(WEB_DIR), **kwargs)

    def log_message(self, *args):  # quiet
        pass


def main():
    os.chdir(os.path.abspath(WEB_DIR))
    # Use 127.0.0.1 (not "localhost") so the URL matches the IPv4 bind even when
    # Windows resolves localhost to IPv6 ::1 first.
    url = f"http://127.0.0.1:{PORT}"
    print(f"Contact Lens demo  ->  {url}   (Ctrl+C to stop)")
    threading.Timer(1.2, lambda: webbrowser.open(url)).start()
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
