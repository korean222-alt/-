"""Collect Korean string literals shown to players (skips comments and log/warn/print lines).
Usage: python tools/extract_korean.py > list.txt"""
import re,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[1]/'game'
HANGUL=re.compile(r'[\uac00-\ud7a3]')
STR=re.compile(r'"((?:[^"\\\n]|\\.)*)"')
SKIP=re.compile(r'GameConfig\.log\(|Config\.log\(|\bwarn\(|\bprint\(|\berror\(|\bassert\(')
def strings():
    out={}
    for p in sorted(root.rglob('*.lua')):
        block=False
        for line in p.read_text().split('\n'):
            s=line
            if block:
                if ']]' in s: block=False
                continue
            if re.match(r'\s*--\[\[',s):
                if ']]' not in s: block=True
                continue
            # cut trailing comment outside strings
            cut=None;inq=False;i=0
            while i<len(s):
                c=s[i]
                if c=='\\' and inq: i+=2;continue
                if c=='"': inq=not inq
                elif not inq and s.startswith('--',i): cut=i;break
                i+=1
            code=s if cut is None else s[:cut]
            if SKIP.search(code): continue
            for m in STR.finditer(code):
                t=m.group(1)
                if HANGUL.search(t):
                    out.setdefault(t.encode().decode('unicode_escape') if '\\u' in t else t.replace('\\n','\n'),str(p.relative_to(root.parent)))
    return out
if __name__=='__main__':
    for k,v in strings().items(): print(v+'\t'+k.replace('\n','\\n'))
