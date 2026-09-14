

from __future__ import annotations

import mimetypes
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class FlutterHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **getattr(SimpleHTTPRequestHandler, "extensions_map", {}),
        ".html": "text/html",
        ".js": "text/javascript",
        ".mjs": "text/javascript",
        ".wasm": "application/wasm",
        ".json": "application/json",
        ".css": "text/css",
        ".svg": "image/svg+xml",
        ".png": "image/png",
        ".ico": "image/x-icon",
    }

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web").resolve()
    port = int(sys.argv[2] if len(sys.argv) > 2 else 8000)

    mimetypes.add_type("text/javascript", ".mjs")
    mimetypes.add_type("text/javascript", ".js")
    mimetypes.add_type("application/wasm", ".wasm")

    if not root.exists():
        print(f"Нет папки: {root}")
        sys.exit(1)

    handler = partial(FlutterHandler, directory=str(root))
    server = ThreadingHTTPServer(("127.0.0.1", port), handler)
    print(f"Serving {root}")
    print(f"Open http://127.0.0.1:{port}/")
    print("Ctrl+C — стоп")
    server.serve_forever()


if __name__ == "__main__":
    main()
