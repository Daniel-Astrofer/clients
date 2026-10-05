#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path('lib')
SKIP_PARTS = {
    '_legacy',
    '_roadmap',
    '.dart_tool',
    'build',
}

ALLOWED_EXACT = {
    Path('lib/bootstrap/mobile_bootstrap.dart'),
    Path('lib/design_system/foundation/theme/app_colors.dart'),
    Path('lib/design_system/foundation/theme/app_theme.dart'),
    Path('lib/design_system/foundation/theme/app_typography.dart'),
    Path('lib/design_system/foundation/theme/monochrome_theme.dart'),
    Path('lib/design_system/foundation/theme/design_system_template.dart'),
    Path('lib/design_system/foundation/theme/home_surface_tokens.dart'),
    Path('lib/design_system/foundation/theme/activity_surface_tokens.dart'),
    Path('lib/design_system/foundation/theme/kerosene_brand_tokens.dart'),
    Path('lib/design_system/foundation/assets/animation/kerosene_lottie.dart'),
    Path('lib/dev_menu.dart'),
    Path('lib/storybook/stories/wallet_flow_stories.dart'),
    Path('lib/core/widgets/animated_number_display.dart'),
    Path('lib/features/financial_accounts/presentation/widgets/revolut_account_card.dart'),
    Path('lib/features/home/presentation/widgets/home_stage_atmosphere.dart'),
    Path('lib/features/home/scene/renderer/media_layer.dart'),
}

ALLOWED_PREFIXES = {
    Path('lib/features/home/scene'),
}

DIRECT_MATERIAL_ICON = re.compile(r'(?<!Kerosene)Icons\.')
RAW_FONT_FAMILY_LITERAL = re.compile(r"fontFamily\s*:\s*['\"]")


def has_direct_lottie_runtime(text: str) -> bool:
    if 'package:lottie' in text:
        return True
    return any(
        re.search(r'(?<!Kerosene)Lottie\.', line)
        and not line.lstrip().startswith(('//', '*'))
        for line in text.splitlines()
    )

CHECKS = [
    ('direct lucide package', lambda text: 'package:lucide_icons' in text),
    ('direct LucideIcons usage', lambda text: 'LucideIcons.' in text),
    ('Cyber naming/visual language', lambda text: 'Cyber' in text),
    ('direct color literal', lambda text: 'Color(0x' in text),
    ('direct GoogleFonts call', lambda text: 'GoogleFonts.' in text),
    ('direct google_fonts package', lambda text: 'package:google_fonts/google_fonts.dart' in text),
    ('raw fontFamily literal', lambda text: bool(RAW_FONT_FAMILY_LITERAL.search(text))),
    ('direct Material Icons usage', lambda text: bool(DIRECT_MATERIAL_ICON.search(text))),
    ('direct lottie runtime', has_direct_lottie_runtime),
    ('direct rive package', lambda text: 'package:rive' in text),
    ('direct runtime animation widget usage', lambda text: 'RiveAnimation.' in text or 'RiveWidget' in text),
]

violations: list[str] = []

for path in ROOT.rglob('*.dart'):
    if any(part in SKIP_PARTS for part in path.parts):
        continue
    text = path.read_text(errors='ignore')
    for label, predicate in CHECKS:
        if not predicate(text):
            continue
        if path in ALLOWED_EXACT or any(
            path == prefix or prefix in path.parents for prefix in ALLOWED_PREFIXES
        ):
            continue
        violations.append(f'{path}: {label}')

if violations:
    print('\n'.join(sorted(set(violations))), file=sys.stderr)
    print('\nFrontend cleanup guard failed.', file=sys.stderr)
    print('Use Kerosene design-system wrappers/tokens instead of raw icons, colors, cyber naming, or direct font packages.', file=sys.stderr)
    sys.exit(1)

print('Frontend cleanup guard passed.')
PY
