#!/usr/bin/env python3
"""Loopback-only static inspector server; no third-party Python dependencies."""
import argparse
import hashlib
import json
import os
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen
import webbrowser

WEB = Path(__file__).resolve().parent.parent / "web"
DIRECTORY_ID = hashlib.sha256(str(WEB).encode()).hexdigest()


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        if self.path == "/.moonhid-status.json":
            body = json.dumps({"app": "moonhid-inspector-v1", "directory_id": DIRECTORY_ID}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            super().do_GET()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=int(os.environ.get("MOONHID_PORT", "8765")))
    parser.add_argument("--open", action="store_true", help="Open the default browser (for user-run launcher).")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("port must be 1..65535")
    if not (WEB / "moonhid-core.js").is_file():
        parser.error("Build the MoonBit browser module first: node scripts/build-web.mjs")
    url = f"http://127.0.0.1:{args.port}/"
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), partial(Handler, directory=str(WEB)))
    except OSError as error:
        try:
            with urlopen(url + ".moonhid-status.json", timeout=1) as response:
                existing = json.load(response)
        except (OSError, URLError, ValueError):
            existing = None
        if existing != {"app": "moonhid-inspector-v1", "directory_id": DIRECTORY_ID}:
            parser.error(f"Port {args.port} is occupied. Set MOONHID_PORT to another port. ({error})")
        print(f"MoonHID is already running: {url}", flush=True)
        if args.open:
            webbrowser.open(url)
        return
    with server:
        print(f"MoonHID inspector: {url}\nPress Ctrl+C to stop.", flush=True)
        if args.open:
            webbrowser.open(url)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nMoonHID inspector stopped.", flush=True)


if __name__ == "__main__":
    main()
