#!/usr/bin/env python3
"""Render the original vector-style icon and wrap PNG representations in ICNS."""
import pathlib, struct, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='uad-icon-') as temporary:
    temp = pathlib.Path(temporary)
    png = temp / 'icon.png'
    subprocess.run(['swift', '-module-cache-path', str(temp/'cache'), str(root/'Tools/make_icon.swift'), str(png)], check=True)
    chunks = []
    for tag, size in [('icp4',16),('icp5',32),('icp6',64),('ic07',128),('ic08',256),('ic09',512),('ic10',1024)]:
        scaled = temp / f'{size}.png'
        subprocess.run(['sips','-z',str(size),str(size),str(png),'--out',str(scaled)], check=True, stdout=subprocess.DEVNULL)
        data = scaled.read_bytes()
        chunks.append(tag.encode() + struct.pack('>I', len(data)+8) + data)
    body = b''.join(chunks)
    (root / 'Resources/AppIcon.icns').write_bytes(b'icns' + struct.pack('>I',len(body)+8) + body)
