#!/usr/bin/env python3
"""Serve only the surface study; previous studies stay on ports 8950/8951."""
import sys
import json
import subprocess
from urllib.parse import urlsplit
from pathlib import Path
from http.server import ThreadingHTTPServer
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from server import WorldGenerator, StudyHandler
from people_server import style_people
from context_catalog import context_catalog
from cult_catalog import cult_catalog


class SurfaceHandler(StudyHandler):
    def do_GET(self):
        if urlsplit(self.path).path == '/api/cult-config':
            if not self.local_request():
                return
            return self.send_json(200, cult_catalog())
        if urlsplit(self.path).path == '/api/people-contexts':
            if not self.local_request():
                return
            try:
                self.send_json(200, context_catalog())
            except (OSError, KeyError, ValueError) as error:
                self.send_json(500, {'error': str(error)})
            return
        return super().do_GET()

    def do_POST(self):
        endpoint = urlsplit(self.path).path
        if endpoint not in {'/api/people', '/api/cult'}:
            return super().do_POST()
        if not self.local_request():
            return
        if self.headers.get('Content-Type', '').split(';', 1)[0].strip() != 'application/json':
            return self.send_json(415, {'error': 'application/json required'})
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 56_001_000:
                raise ValueError('Invalid request size')
            self.send_json(200, style_people(self.generator, json.loads(self.rfile.read(length)), 'cult' if endpoint == '/api/cult' else 'person'))
        except (ValueError, json.JSONDecodeError) as error:
            self.send_json(400, {'error': str(error)})
        except subprocess.TimeoutExpired:
            self.send_json(504, {'error': 'Portrait NPR exceeded 60 seconds'})
        except (OSError, RuntimeError) as error:
            self.send_json(500, {'error': str(error)})

if __name__ == '__main__':
    generator = WorldGenerator('/Applications/Godot.app/Contents/MacOS/Godot')
    generator.adapter_dir = Path(__file__).resolve().parent
    SurfaceHandler.generator = generator
    server = ThreadingHTTPServer(('127.0.0.1', 8952), SurfaceHandler)
    print('Surface study: http://127.0.0.1:8952/painted/surface/', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
