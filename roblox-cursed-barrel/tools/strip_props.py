"""Studio 가 저장한 .rbxl 을 Lune 이 읽을 수 있게 고친다.

최신 Studio 는 `Tags` 속성(CollectionService 태그)을 SharedString(형식 28)으로 저장하는데
Lune(rbx_dom) 은 예전 형식(String)만 받아서 파일 전체를 못 연다.
`Tags` 덩어리는 String 으로 바꿔 쓰고(태그는 그대로 남는다), 나머지 덩어리는 압축된 그대로 옮긴다.
그래도 못 읽는 속성이 있으면 `클래스.속성` 을 넘겨 그 덩어리를 뺀다.

    python3 tools/strip_props.py 원본.rbxl 결과.rbxl [클래스.속성 ...]
    python3 tools/strip_props.py 원본.rbxl --list      # 덩어리 목록만
"""
import struct
import sys

import lz4.block
import zstandard

SHARED_STRING, STRING = 28, 1
CONVERT = {"Tags"}


def chunks(data):
    assert data[:8] == b"<roblox!", "not a binary place"
    pos = 32
    while pos < len(data):
        name = data[pos:pos + 4]
        clen, ulen, _ = struct.unpack_from("<III", data, pos + 4)
        size = clen if clen else ulen
        body = data[pos + 16:pos + 16 + size]
        yield name, clen, ulen, body, data[pos:pos + 16 + size]
        pos += 16 + size
        if name == b"END\0":
            break


def payload(clen, ulen, body):
    if clen == 0:
        return body
    if body[:4] == b"\x28\xb5\x2f\xfd":
        return zstandard.ZstdDecompressor().decompress(body, max_output_size=ulen)
    return lz4.block.decompress(body, uncompressed_size=ulen)


def rbytes(buf, off):
    (n,) = struct.unpack_from("<I", buf, off)
    return buf[off + 4:off + 4 + n], off + 4 + n


def interleaved_u32(buf, off, count):
    """Roblox 의 바이트 섞인(big-endian, interleaved) u32 배열."""
    out = []
    for i in range(count):
        b = bytes(buf[off + k * count + i] for k in range(4))
        out.append(struct.unpack(">I", b)[0])
    return out


def main():
    data = open(sys.argv[1], "rb").read()
    classes, counts, shared, parsed = {}, {}, [], []
    for name, clen, ulen, body, raw in chunks(data):
        info = None
        if name in (b"INST", b"PROP"):
            p = payload(clen, ulen, body)
            (cid,) = struct.unpack_from("<I", p, 0)
            s, off = rbytes(p, 4)
            s = s.decode("utf-8", "replace")
            if name == b"INST":
                classes[cid] = s
                counts[cid] = struct.unpack_from("<I", p, off + 1)[0]
            else:
                info = (cid, s, p[off], p, off + 1)
        elif name == b"SSTR":
            p = payload(clen, ulen, body)
            (n,) = struct.unpack_from("<I", p, 4)
            off = 8
            for _ in range(n):
                v, off = rbytes(p, off + 16)
                shared.append(v)
        parsed.append((name, raw, info))

    if len(sys.argv) > 2 and sys.argv[2] == "--list":
        for name, raw, info in parsed:
            if info:
                print(name.decode(), classes.get(info[0]), info[1], "type", info[2])
            else:
                print(name.decode(), len(raw))
        return

    drop = set(sys.argv[3:])
    out = [data[:32]]
    converted = 0
    for name, raw, info in parsed:
        if info:
            cid, prop, ptype, p, voff = info
            full = f"{classes.get(cid)}.{prop}"
            if full in drop:
                print("dropped", full, "type", ptype)
                continue
            if prop in CONVERT and ptype == SHARED_STRING:
                idx = interleaved_u32(p, voff, counts[cid])
                body = bytearray(p[:voff - 1])
                body.append(STRING)
                for i in idx:
                    v = shared[i]
                    body += struct.pack("<I", len(v)) + v
                raw = b"PROP" + struct.pack("<III", 0, len(body), 0) + bytes(body)
                converted += 1
        out.append(raw)
    open(sys.argv[2], "wb").write(b"".join(out))
    print("converted", converted, "Tags chunks")


if __name__ == "__main__":
    main()
