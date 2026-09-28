"""Replace script Source strings inside a binary .rbxl, leaving every other byte as-is.

usage: python3 patch.py original.rbxl scripts_dir output.rbxl
scripts_dir holds files named "<path>.<ref>.<Class>.lua" (as produced by parse.py).
"""
import os, re, struct, sys
import lz4.block, zstandard

src_path, scripts_dir, out_path = sys.argv[1:4]
d = open(src_path, 'rb').read()

edits = {}
for fn in os.listdir(scripts_dir):
    m = re.search(r'\.(\d+)\.(Script|LocalScript|ModuleScript)\.lua$', fn)
    if m:
        edits[int(m.group(1))] = open(os.path.join(scripts_dir, fn), 'rb').read()


def interleaved_refs(b, off, n):
    out, acc = [], 0
    for i in range(n):
        x = (b[off + i] << 24) | (b[off + n + i] << 16) | (b[off + 2 * n + i] << 8) | b[off + 3 * n + i]
        acc += (x >> 1) ^ -(x & 1)
        out.append(acc)
    return out


def rstr(b, off):
    l = struct.unpack('<I', b[off:off + 4])[0]
    return b[off + 4:off + 4 + l], off + 4 + l


out = bytearray(d[:32])
pos = 32
classes = {}
changed = 0
while pos < len(d):
    head = d[pos:pos + 16]
    name = head[:4]
    clen, ulen = struct.unpack('<II', head[4:12])
    raw_len = clen if clen else ulen
    raw = d[pos + 16:pos + 16 + raw_len]
    pos += 16 + raw_len
    if clen == 0:
        body = raw
    elif raw[:4] == b'\x28\xb5\x2f\xfd':
        body = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
    else:
        body = lz4.block.decompress(raw, uncompressed_size=ulen)

    new_body = None
    if name == b'INST':
        cid = struct.unpack('<I', body[:4])[0]
        cname, o = rstr(body, 4)
        o += 1
        n = struct.unpack('<I', body[o:o + 4])[0]
        classes[cid] = (cname.decode(), interleaved_refs(body, o + 4, n))
    elif name == b'PROP':
        cid = struct.unpack('<I', body[:4])[0]
        pname, o = rstr(body, 4)
        cname, refs = classes[cid]
        if pname == b'Source' and body[o] == 0x01 and any(r in edits for r in refs):
            o += 1
            parts = [body[:o]]
            before = changed
            for ref in refs:
                s, o = rstr(body, o)
                if ref in edits and edits[ref] != s:
                    s = edits[ref]
                    changed += 1
                parts.append(struct.pack('<I', len(s)) + s)
            assert o == len(body), 'unexpected trailing bytes in Source PROP'
            if changed != before:
                new_body = b''.join(parts)

    if new_body is None:
        out += head + raw  # untouched chunk: copy the exact original bytes
    else:
        comp = lz4.block.compress(new_body, store_size=False)
        out += name + struct.pack('<III', len(comp), len(new_body), 0) + comp
    if name == b'END\x00':
        out += d[pos:]
        break

open(out_path, 'wb').write(out)
print(f'scripts changed: {changed}  ->  {out_path} ({len(out)} bytes)')
