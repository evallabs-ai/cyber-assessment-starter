from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

NOTES_DIR = Path("/srv/notes")


class NoteHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/":
            names = sorted(p.name for p in NOTES_DIR.iterdir())
            return self.reply(200, "Public notes: " + ", ".join(names) + "\nRead one at /notes?name=<name>\n")
        if url.path != "/notes":
            return self.reply(404, "Not found\n")

        name = parse_qs(url.query).get("name", [""])[0]
        # The flaw: this removes "../" once, so "....//" becomes "../" afterwards.
        name = name.replace("../", "")
        try:
            return self.reply(200, (NOTES_DIR / name).read_text())
        except OSError:
            return self.reply(404, "No such note\n")

    def reply(self, status, body):
        self.send_response(status)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body.encode())


HTTPServer(("0.0.0.0", 8080), NoteHandler).serve_forever()
