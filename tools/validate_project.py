#!/usr/bin/env python3
"""Static sanity checks for Arena Duel resources (does not replace Godot import/parse tests)."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
script = ROOT / 'scripts/main.gd'
scene = ROOT / 'scenes/main.tscn'
project = ROOT / 'project.godot'
shaders = (ROOT / 'shaders' / 'fighter_surface.gdshader', ROOT / 'shaders' / 'void_prince.gdshader')
for path in (script, scene, project, *shaders):
    if not path.is_file():
        errors.append(f'Missing required file: {path.relative_to(ROOT)}')

if script.exists():
    text = script.read_text(encoding='utf-8')
    for resource in re.findall(r'(?:preload|load)\("res://([^"]+)"\)', text):
        if not (ROOT / resource).is_file():
            errors.append(f'Missing referenced resource: res://{resource}')
    for required in ('func _draw_fighter_sprite', 'func _update_dark_zones', 'func _p1_attack_pressed', 'func _p2_attack_pressed', 'func _setup_fighter_sprites', 'func _sync_fighter_sprites'):
        if required not in text:
            errors.append(f'Missing expected function: {required}')
    # Enforce explicit return types for every project function.
    for line_no, line in enumerate(text.splitlines(), 1):
        if line.startswith('func ') and ' -> ' not in line:
            errors.append(f'Function is missing an explicit return type at line {line_no}: {line}')
    # Check delimiters while ignoring comments and quoted strings.
    pairs = {')': '(', ']': '[', '}': '{'}
    stack = []
    quote = None
    escaped = False
    for line_no, line in enumerate(text.splitlines(), 1):
        i = 0
        while i < len(line):
            ch = line[i]
            if quote:
                if escaped:
                    escaped = False
                elif ch == '\\':
                    escaped = True
                elif ch == quote:
                    quote = None
                i += 1
                continue
            if ch == '#':
                break
            if ch in ('"', "'"):
                quote = ch
            elif ch in '([{':
                stack.append((ch, line_no))
            elif ch in ')]}':
                if not stack or stack[-1][0] != pairs[ch]:
                    errors.append(f'Unbalanced delimiter {ch!r} at line {line_no}')
                    break
                stack.pop()
            i += 1
    if quote:
        errors.append('Unclosed quoted string at end of GDScript')
    if stack:
        errors.append(f'Unclosed delimiter {stack[-1][0]!r} from line {stack[-1][1]}')

try:
    from PIL import Image
    for name in ('hero_red.png', 'hero_blue.png', 'hero_druid.png', 'hero_guardian.png', 'hero_dark_prince.png'):
        path = ROOT / 'assets' / name
        if not path.is_file():
            errors.append(f'Missing character sprite: assets/{name}')
            continue
        with Image.open(path) as image:
            if image.mode != 'RGBA' or image.size != (512, 640):
                errors.append(f'Unexpected sprite format for {name}: {image.mode} {image.size}')
except ImportError:
    print('NOTE: Pillow unavailable; image checks skipped.')

if errors:
    print('STATIC VALIDATION FAILED:')
    for error in errors:
        print(' -', error)
    sys.exit(1)
print('Static validation passed: typed function signatures, required files, resource paths, GDScript delimiters, shaders, and character sprite formats.')
print('NOTE: Godot engine parsing, runtime behavior, controller hardware, and Windows export still require Godot 4.3+.')
