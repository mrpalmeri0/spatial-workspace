#!/usr/bin/env python3
"""Check shipped locale tables, used keys and localized format argument parity."""
from pathlib import Path
import json
import re
root = Path(__file__).resolve().parents[1]
def read_table(path):
    result = {}
    for line in path.read_text().splitlines():
        if line.startswith('//') or not line.strip(): continue
        match = re.fullmatch(r'("(?:[^"\\]|\\.)*") = ("(?:[^"\\]|\\.)*");', line)
        assert match, (path, line)
        key, value = map(json.loads, match.groups())
        assert key not in result, (path, key)
        result[key] = value
    return result
it = read_table(root / 'Resources/it.lproj/Localizable.strings')
en = read_table(root / 'Resources/en.lproj/Localizable.strings')
assert it.keys() == en.keys(), 'Locale keys differ'
formats = re.compile(r'%(?!%)(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?[hlLzjt]*[@diuoxXfFeEgGcs]')
for key in it:
    assert formats.findall(it[key]) == formats.findall(en[key]), key
for folder in ['Sources', 'Shared', 'iPhone']:
    for path in (root / folder).glob('*.swift'):
        for raw in re.findall(r'\bL[F]?\(("(?:[^"\\]|\\.)*")', path.read_text()):
            key = json.loads(raw)
            assert key in en, (path.name, key)
for key in ['Workspace', 'Strumenti', 'iPhone e remoto', 'Impostazioni']:
    if key != 'Workspace': assert key in en
assert en['Doppio'] == 'Dual' and en['Avvia sessione'] == 'Start session'
print(f'PASS: {len(en)} locale keys, call-site coverage, format placeholders and UI labels')
