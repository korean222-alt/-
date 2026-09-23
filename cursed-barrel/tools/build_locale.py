"""Build game/ReplicatedStorage/CursedBarrel/Shared/LocaleData.lua from tools/locale/en_*.txt.
Each line: <Korean>\t<English>   ("\n" means a line break).
--check : also fail if a Korean UI string in game/ has no English line."""
import pathlib,sys,re
root=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from extract_korean import strings
SPEC=re.compile(r'%%|%[-+#0]*\d*(?:\.\d+)?[dsf]')
def load():
    table={}
    for p in sorted((root/'tools/locale').glob('en_*.txt')):
        for n,line in enumerate(p.read_text().split('\n'),1):
            if not line.strip() or line.startswith('#'): continue
            if '\t' not in line: raise SystemExit(f'{p.name}:{n}: missing tab')
            ko,en=line.split('\t',1)
            ko=ko.replace('\\n','\n');en=en.replace('\\n','\n')
            a=[s for s in SPEC.findall(ko) if s!='%%'];b=[s for s in SPEC.findall(en) if s!='%%']
            if len(a)!=len(b): raise SystemExit(f'{p.name}:{n}: format specifiers differ: {ko!r} / {en!r}')
            table[ko]=en
    return table
def lua_str(s):
    eq='='
    while ']'+eq+']' in s or s.endswith(']'+eq[:-1]): eq+='='
    return '['+eq+'['+('\n' if s.startswith('\n') else '')+s+']'+eq+']'
def build(table):
    out=['-- 자동 생성 파일. tools/locale/en_*.txt 를 고치고 python tools/build_locale.py 로 다시 만드세요.','-- Generated from tools/locale/en_*.txt by tools/build_locale.py. Do not edit by hand.','return {']
    for ko in sorted(table):
        out.append(f' [ {lua_str(ko)} ] = {lua_str(table[ko])},')
    out.append('}')
    target=root/'game/ReplicatedStorage/CursedBarrel/Shared/LocaleData.lua'
    target.write_text('\n'.join(out)+'\n')
    return target
if __name__=='__main__':
    table=load()
    target=build(table)
    missing=[k for k in strings() if k not in table]
    print(f'LocaleData: {len(table)} English lines -> {target.relative_to(root)}')
    if '--check' in sys.argv:
        if missing:
            for k in missing: print('MISSING:',repr(k))
            raise SystemExit(f'{len(missing)} Korean UI strings have no English line')
        print('Locale coverage: every Korean UI string has English')
