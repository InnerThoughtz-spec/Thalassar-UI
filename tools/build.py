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

# A single HTTP fetch opens the showcase. Embed the same library lexically:
# Matcha can discard a separately loaded chunk's return value, while lexical
# factories work on both Matcha and hosts that retain normal Luau returns.
demo_body = (root / 'examples' / 'demo.lua').read_text(encoding='utf-8-sig')
demo = root / 'Demo.lua'
demo_source = (
    '-- Thalassar UI standalone demo. MIT licensed. Interface showcase only.\n'
    'local ThalassarDemoLibrary = (function()\n'
    + output.read_text(encoding='utf-8')
    + '\nend)()\n'
    + demo_body
)
demo.write_text(demo_source, encoding='utf-8', newline='\n')
print(f'Built {demo.name}: {demo.stat().st_size} bytes')
