"""코드 속 한국어 문자열(주석 제외)을 찾는다. 번역 누락 검사용: python3 tools/find_korean.py [경로...]"""
import os
import re
import sys

HAN = re.compile(r"[가-힣]")
STR = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')


def code_part(line):
    # 문자열 밖의 -- 부터는 주석
    out, i = [], 0
    for m in STR.finditer(line):
        before = line[i:m.start()]
        if "--" in before:
            out.append(before[: before.index("--")])
            return "".join(out)
        out.append(before + m.group(0))
        i = m.end()
    rest = line[i:]
    if "--" in rest:
        rest = rest[: rest.index("--")]
    return "".join(out) + rest


def main():
    roots = sys.argv[1:] or ["src"]
    count = 0
    for root in roots:
        walk = [(os.path.dirname(root), [], [os.path.basename(root)])] if os.path.isfile(root) else os.walk(root)
        for dirpath, _, files in walk:
            for f in sorted(files):
                if not f.endswith(".lua") or (os.path.basename(dirpath) == "Locale" or f == "Locale.lua"):
                    continue
                path = os.path.join(dirpath, f)
                for n, line in enumerate(open(path, encoding="utf-8"), 1):
                    for s in STR.findall(code_part(line)):
                        if HAN.search(s):
                            count += 1
                            print(f"{path}:{n}: {s[:120]}")
    print(f"{count} Korean strings" if count else "OK: no Korean strings in code")
    return 1 if count else 0


if __name__ == "__main__":
    sys.exit(main())
