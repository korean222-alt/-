"""화면에 나갈 수 있는 한국어 문자열을 src 에서 모두 뽑는다 (주석 · 로그 · warn 제외).
사용 : python3 tools/extract_korean.py > /tmp/ko.txt"""
import re, sys, pathlib
HANGUL = re.compile('[가-힣]')
root = pathlib.Path(__file__).resolve().parent.parent / 'src'
SKIP_CALL = re.compile(r'(GameConfig\.log|\blog\(|warn\(|print\(|error\(|:log\(|Funnel\(|_logCatchFail|AnalyticsService|LogCustomEvent|SetAttribute\()')
strs = {}
for path in root.rglob('*.lua'):
    if path.name in ('LocaleData.lua',):
        continue
    text = path.read_text(encoding='utf-8')
    # 블록 주석 제거
    text = re.sub(r'--\[(=*)\[.*?\]\1\]', '', text, flags=re.S)
    for lineno, line in enumerate(text.split('\n'), 1):
        # 줄 주석 제거 (문자열 안의 -- 는 드물다)
        code = re.sub(r'--(?!\[).*$', '', line)
        if not HANGUL.search(code) or SKIP_CALL.search(code):
            continue
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'|\[(=*)\[(.*?)\]\3\]', code):
            s = m.group(1) if m.group(1) is not None else (m.group(2) if m.group(2) is not None else m.group(4))
            if s and HANGUL.search(s):
                s = s.replace('\\n', '\n').replace('\\"', '"').replace("\\'", "'")
                strs.setdefault(s, f'{path.relative_to(root)}:{lineno}')
for s, where in strs.items():
    print(where + '\t' + s.replace('\n', '\\n'))
