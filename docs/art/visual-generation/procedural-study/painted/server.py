#!/usr/bin/env python3
"""Isolated painted study; retains the previous study on port 8950."""
import sys
from pathlib import Path
from http.server import ThreadingHTTPServer
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from server import WorldGenerator, StudyHandler

class PaintedGenerator(WorldGenerator):
    def style_images(self, body):
        result = super().style_images(body)
        return {**result, 'method': '2D pigment and continuous drawing slope fields -> unchanged original common.style_shade -> unchanged original bloom/post; no sphere-surface equivalence'}


if __name__ == '__main__':
    generator = PaintedGenerator('/Applications/Godot.app/Contents/MacOS/Godot')
    generator.adapter_dir = Path(__file__).resolve().parent
    StudyHandler.generator = generator
    server = ThreadingHTTPServer(('127.0.0.1', 8951), StudyHandler)
    print('Painted study: http://127.0.0.1:8951/painted/', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
