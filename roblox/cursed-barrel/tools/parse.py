"""Dump a binary .rbxl: scripts (one .lua file each), instance tree, class counts, string properties.

usage: python3 parse.py place.rbxl out_dir   (needs: pip install lz4 zstandard)
Edit the .lua files under out_dir/scripts, then write them back with patch.py.
"""
import struct, sys, json, os
import lz4.block, zstandard

path = sys.argv[1]
out = sys.argv[2]
d = open(path, 'rb').read()
pos = 32
classes = {}   # id -> (name, refs)
props = {}     # ref -> {prop: value}
parent = {}

def rd_chunks():
    global pos
    while pos < len(d):
        name = d[pos:pos+4]; clen, ulen = struct.unpack('<II', d[pos+4:pos+12]); pos += 16
        if clen == 0:
            body = d[pos:pos+ulen]; pos += ulen
        else:
            raw = d[pos:pos+clen]; pos += clen
            if raw[:4] == b'\x28\xb5\x2f\xfd':
                body = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
            else:
                body = lz4.block.decompress(raw, uncompressed_size=ulen)
        yield name, body
        if name == b'END\x00':
            break

def interleaved(b, off, n):
    vals = []
    for i in range(n):
        x = (b[off+i] << 24) | (b[off+n+i] << 16) | (b[off+2*n+i] << 8) | b[off+3*n+i]
        x = (x >> 1) ^ -(x & 1)
        vals.append(x)
    return vals, off + 4*n

def refs(b, off, n):
    v, off = interleaved(b, off, n)
    acc = 0; out = []
    for x in v:
        acc += x; out.append(acc)
    return out, off

def rstr(b, off):
    l = struct.unpack('<I', b[off:off+4])[0]
    return b[off+4:off+4+l], off+4+l

for name, body in rd_chunks():
    if name == b'INST':
        cid = struct.unpack('<I', body[:4])[0]
        cname, o = rstr(body, 4)
        o += 1
        n = struct.unpack('<I', body[o:o+4])[0]; o += 4
        r, o = refs(body, o, n)
        classes[cid] = (cname.decode(), r)
    elif name == b'PROP':
        cid = struct.unpack('<I', body[:4])[0]
        pname, o = rstr(body, 4)
        pname = pname.decode()
        t = body[o]; o += 1
        cname, r = classes[cid]
        if t == 0x01:
            for ref in r:
                s, o = rstr(body, o)
                try: s = s.decode('utf-8')
                except: s = '<binary %d bytes>' % len(s)
                props.setdefault(ref, {})[pname] = s
        elif t == 0x02:
            for i, ref in enumerate(r):
                props.setdefault(ref, {})[pname] = bool(body[o+i])
        elif t == 0x03:
            v, _ = interleaved(body, o, len(r))
            for ref, x in zip(r, v):
                props.setdefault(ref, {})[pname] = x
    elif name == b'PRNT':
        n = struct.unpack('<I', body[1:5])[0]
        c, o = refs(body, 5, n)
        p, o = refs(body, o, n)
        for a, b_ in zip(c, p): parent[a] = b_

cls_of = {}
for cid, (cn, r) in classes.items():
    for ref in r: cls_of[ref] = cn

def path_of(ref):
    parts = []
    while ref in cls_of:
        parts.append(props.get(ref, {}).get('Name', '?'))
        ref = parent.get(ref, -1)
    return '.'.join(reversed(parts))

# class counts
from collections import Counter
cnt = Counter(cls_of.values())
with open(os.path.join(out, 'classes.txt'), 'w') as f:
    for k, v in cnt.most_common(): f.write(f'{v}\t{k}\n')

os.makedirs(os.path.join(out, 'scripts'), exist_ok=True)
with open(os.path.join(out, 'scripts.txt'), 'w') as f:
    for ref, cn in cls_of.items():
        if cn in ('Script', 'LocalScript', 'ModuleScript'):
            p = path_of(ref); src = props.get(ref, {}).get('Source', '')
            dis = props.get(ref, {}).get('Disabled', None)
            f.write(f'{cn}\t{len(src.splitlines())}\t{p}\tdisabled={dis}\n')
            fn = p.replace('/', '_')[:180] + f'.{ref}.{cn}.lua'
            open(os.path.join(out, 'scripts', fn), 'w').write(src)

# tree of top-level (depth<=3), non-part
with open(os.path.join(out, 'tree.txt'), 'w') as f:
    kids = {}
    for c, p in parent.items(): kids.setdefault(p, []).append(c)
    def walk(ref, depth):
        for c in sorted(kids.get(ref, []), key=lambda x: props.get(x, {}).get('Name', '')):
            f.write('  '*depth + f"{props.get(c,{}).get('Name','?')} [{cls_of.get(c)}] ({len(kids.get(c,[]))})\n")
            if depth < 4: walk(c, depth+1)
    walk(-1, 0)

# other interesting string props
with open(os.path.join(out, 'strings.txt'), 'w') as f:
    for ref, pr in props.items():
        for k, v in pr.items():
            if isinstance(v, str) and k not in ('Name', 'Source') and v and len(v) < 500:
                f.write(f'{cls_of.get(ref)}\t{path_of(ref)}\t{k}={v!r}\n')
print('instances', len(cls_of))
