"""Build the standalone UI distribution without fetching external code."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parts = ['-- Thalassar UI v1.0.0. MIT licensed. UI library only.\n']
for name, factory in [('glass', 'createThalassarUI'), ('effects', 'createThalassarBackgroundEffects'), ('wheel', 'createWheelBridge')]:
    source = (root / 'src' / f'{name}.lua').read_text(encoding='utf-8-sig')
    parts.append(f'local {factory} = (function()\n{source}\nend)()\n')
parts.append((root / 'src' / 'library.lua').read_text(encoding='utf-8-sig'))
output = root / 'Library.lua'
output.write_text('\n'.join(parts), encoding='utf-8', newline='\n')
print(f'Built {output.name}: {output.stat().st_size} bytes')
