#!/usr/bin/env python3
"""Installs Godot's web export templates without downloading the full archive.

The official templates archive is about 1 GB and holds every platform. This
reads its zip index with HTTP range requests and extracts only the web
templates (~17 MB) into Godot's export template folder.

Usage: tools/fetch_web_templates.py 4.3-stable
"""

import io
import os
import sys
import urllib.request
import zipfile

WANTED = ("version.txt", "web_nothreads_release.zip", "web_nothreads_debug.zip")


class RangeReader(io.RawIOBase):
    """A seekable, read-only file backed by HTTP range requests."""

    def __init__(self, url: str) -> None:
        head = urllib.request.urlopen(urllib.request.Request(url, method="HEAD"))
        self.url = head.url  # follow the release redirect once
        self.size = int(head.headers["Content-Length"])
        self.pos = 0

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.pos

    def seek(self, offset: int, whence: int = 0) -> int:
        self.pos = {0: offset, 1: self.pos + offset, 2: self.size + offset}[whence]
        return self.pos

    def readinto(self, buffer) -> int:
        if self.pos >= self.size or len(buffer) == 0:
            return 0
        end = min(self.pos + len(buffer), self.size) - 1
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        data = urllib.request.urlopen(request).read()
        buffer[: len(data)] = data
        self.pos += len(data)
        return len(data)


def main() -> None:
    version = sys.argv[1]  # e.g. 4.3-stable
    url = (f"https://github.com/godotengine/godot/releases/download/{version}/"
           f"Godot_v{version}_export_templates.tpz")
    dest = os.path.expanduser(
        f"~/.local/share/godot/export_templates/{version.replace('-', '.')}")
    os.makedirs(dest, exist_ok=True)
    archive = zipfile.ZipFile(io.BufferedReader(RangeReader(url), buffer_size=1 << 20))
    for name in WANTED:
        with archive.open(f"templates/{name}") as src, open(os.path.join(dest, name), "wb") as out:
            out.write(src.read())
        print(f"installed {name} -> {dest}")


if __name__ == "__main__":
    main()
