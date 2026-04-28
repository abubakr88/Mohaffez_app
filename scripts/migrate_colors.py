"""
One-shot migration: replace all raw `Colors.*` usages in lib/ with the
corresponding `AppThemeConstants.*` token.

Run from repo root:
    python scripts/migrate_colors.py

Strategy:
  - Replacements are applied in *length order* (longest pattern first) so
    `Colors.green.shade50` is not partially clobbered into
    `AppThemeConstants.success.shade50`.
  - Bracket-index forms `Colors.grey[600]` are mapped to the same token as
    the equivalent `.shade600` form.
  - We touch every .dart file under lib/ EXCEPT the theme definition itself
    and the QuizDS sub-theme tokens file (which intentionally uses Colors).
  - If a file uses Colors.* but doesn't already import AppThemeConstants,
    we inject the import.
"""

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EXCLUDE = {
    os.path.normpath('lib/shared/theme/app_theme_constants.dart'),
    os.path.normpath('lib/shared/theme/app_theme.dart'),
    os.path.normpath('lib/shared/theme/app_theme_data.dart'),
    os.path.normpath('lib/screens/teacher/quiz/widgets/quiz_design_tokens.dart'),
}

# Map every raw form to its AppThemeConstants.* token.
# Order does NOT matter here — we sort by length descending before substituting.
MAP = {
    # ── Pure neutrals ──────────────────────────────────────────────────────
    'Colors.white':           'AppThemeConstants.white',
    'Colors.white24':         'AppThemeConstants.white24',
    'Colors.white60':         'AppThemeConstants.white60',
    'Colors.white70':         'AppThemeConstants.white70',
    'Colors.black':           'AppThemeConstants.black',
    'Colors.black54':         'AppThemeConstants.black54',
    'Colors.black87':         'AppThemeConstants.black87',
    'Colors.transparent':     'AppThemeConstants.transparent',

    # ── Greys ──────────────────────────────────────────────────────────────
    'Colors.grey':            'AppThemeConstants.grey500',
    'Colors.grey.shade50':    'AppThemeConstants.grey50',
    'Colors.grey.shade100':   'AppThemeConstants.grey100',
    'Colors.grey.shade200':   'AppThemeConstants.grey200',
    'Colors.grey.shade300':   'AppThemeConstants.grey300',
    'Colors.grey.shade400':   'AppThemeConstants.grey400',
    'Colors.grey.shade500':   'AppThemeConstants.grey500',
    'Colors.grey.shade600':   'AppThemeConstants.grey600',
    'Colors.grey.shade700':   'AppThemeConstants.grey700',
    'Colors.grey.shade800':   'AppThemeConstants.grey800',
    'Colors.grey.shade900':   'AppThemeConstants.grey900',
    'Colors.grey[50]':        'AppThemeConstants.grey50',
    'Colors.grey[100]':       'AppThemeConstants.grey100',
    'Colors.grey[200]':       'AppThemeConstants.grey200',
    'Colors.grey[300]':       'AppThemeConstants.grey300',
    'Colors.grey[400]':       'AppThemeConstants.grey400',
    'Colors.grey[500]':       'AppThemeConstants.grey500',
    'Colors.grey[600]':       'AppThemeConstants.grey600',
    'Colors.grey[700]':       'AppThemeConstants.grey700',
    'Colors.grey[800]':       'AppThemeConstants.grey800',
    'Colors.grey[900]':       'AppThemeConstants.grey900',
    'Colors.blueGrey':        'AppThemeConstants.grey600',

    # ── Reds → error semantic ─────────────────────────────────────────────
    'Colors.red':             'AppThemeConstants.error',
    'Colors.red.shade50':     'AppThemeConstants.errorLight',
    'Colors.red.shade100':    'AppThemeConstants.errorLight',
    'Colors.red.shade200':    'AppThemeConstants.accentRed',
    'Colors.red.shade300':    'AppThemeConstants.accentRed',
    'Colors.red.shade400':    'AppThemeConstants.accentRed',
    'Colors.red.shade500':    'AppThemeConstants.error',
    'Colors.red.shade600':    'AppThemeConstants.error',
    'Colors.red.shade700':    'AppThemeConstants.error',
    'Colors.red.shade800':    'AppThemeConstants.errorDark',
    'Colors.red.shade900':    'AppThemeConstants.errorDark',

    # ── Greens → success semantic ─────────────────────────────────────────
    'Colors.green':           'AppThemeConstants.success',
    'Colors.green.shade50':   'AppThemeConstants.successLight',
    'Colors.green.shade100':  'AppThemeConstants.successLight',
    'Colors.green.shade200':  'AppThemeConstants.accentGreenAlt',
    'Colors.green.shade300':  'AppThemeConstants.accentGreenAlt',
    'Colors.green.shade400':  'AppThemeConstants.accentGreenAlt',
    'Colors.green.shade500':  'AppThemeConstants.success',
    'Colors.green.shade600':  'AppThemeConstants.success',
    'Colors.green.shade700':  'AppThemeConstants.success',
    'Colors.green.shade800':  'AppThemeConstants.successDark',
    'Colors.green.shade900':  'AppThemeConstants.successDark',

    # ── Oranges → warning semantic ────────────────────────────────────────
    'Colors.orange':          'AppThemeConstants.warning',
    'Colors.orange.shade50':  'AppThemeConstants.warningLight',
    'Colors.orange.shade100': 'AppThemeConstants.warningLight',
    'Colors.orange.shade200': 'AppThemeConstants.accentOrange',
    'Colors.orange.shade300': 'AppThemeConstants.accentOrange',
    'Colors.orange.shade400': 'AppThemeConstants.accentOrange',
    'Colors.orange.shade500': 'AppThemeConstants.warning',
    'Colors.orange.shade600': 'AppThemeConstants.warning',
    'Colors.orange.shade700': 'AppThemeConstants.warning',
    'Colors.orange.shade800': 'AppThemeConstants.warningDark',
    'Colors.orange.shade900': 'AppThemeConstants.warningDark',
    'Colors.deepOrange':      'AppThemeConstants.accentOrange',

    # ── Amber → accent amber ──────────────────────────────────────────────
    'Colors.amber':           'AppThemeConstants.accentAmber',
    'Colors.amber.shade50':   'AppThemeConstants.accentAmberLight',
    'Colors.amber.shade100':  'AppThemeConstants.accentAmberLight',
    'Colors.amber.shade200':  'AppThemeConstants.accentAmber',
    'Colors.amber.shade300':  'AppThemeConstants.accentAmber',
    'Colors.amber.shade400':  'AppThemeConstants.accentAmber',
    'Colors.amber.shade500':  'AppThemeConstants.accentAmber',
    'Colors.amber.shade600':  'AppThemeConstants.accentAmberDark',
    'Colors.amber.shade700':  'AppThemeConstants.accentAmberDark',
    'Colors.amber.shade800':  'AppThemeConstants.accentAmberDark',
    'Colors.amber.shade900':  'AppThemeConstants.accentAmberDark',

    # ── Blues → accent blue ───────────────────────────────────────────────
    'Colors.blue':            'AppThemeConstants.accentBlue',
    'Colors.blue.shade50':    'AppThemeConstants.accentBlueLight',
    'Colors.blue.shade100':   'AppThemeConstants.accentBlueLight',
    'Colors.blue.shade200':   'AppThemeConstants.accentBlue',
    'Colors.blue.shade300':   'AppThemeConstants.accentBlue',
    'Colors.blue.shade400':   'AppThemeConstants.accentBlue',
    'Colors.blue.shade500':   'AppThemeConstants.accentBlue',
    'Colors.blue.shade600':   'AppThemeConstants.accentBlueDark',
    'Colors.blue.shade700':   'AppThemeConstants.accentBlueDark',
    'Colors.blue.shade800':   'AppThemeConstants.accentBlueDark',
    'Colors.blue.shade900':   'AppThemeConstants.accentBlueDark',
    'Colors.lightBlue':       'AppThemeConstants.accentBlue',
    'Colors.lightBlue.shade100': 'AppThemeConstants.accentBlueLight',
    'Colors.lightBlue.shade200': 'AppThemeConstants.accentBlue',

    # ── Purples → accent purple ───────────────────────────────────────────
    'Colors.purple':          'AppThemeConstants.accentPurple',
    'Colors.purple.shade50':  'AppThemeConstants.accentPurpleLight',
    'Colors.purple.shade100': 'AppThemeConstants.accentPurpleLight',
    'Colors.purple.shade200': 'AppThemeConstants.accentPurple',
    'Colors.purple.shade300': 'AppThemeConstants.accentPurple',
    'Colors.purple.shade700': 'AppThemeConstants.accentPurpleDark',
    'Colors.purple.shade800': 'AppThemeConstants.accentPurpleDark',
    'Colors.purple.shade900': 'AppThemeConstants.accentPurpleDark',

    # ── Teal aliases ──────────────────────────────────────────────────────
    'Colors.teal':            'AppThemeConstants.primary',
    'Colors.teal.shade50':    'AppThemeConstants.accentBackground',
    'Colors.teal.shade700':   'AppThemeConstants.deepTeal',

    # ── Yellow aliases (rare) ─────────────────────────────────────────────
    'Colors.yellow':          'AppThemeConstants.accentAmber',
    'Colors.yellow.shade700': 'AppThemeConstants.accentAmberDark',
}

IMPORT_LINE = (
    "import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';"
)


def needs_import(content: str) -> bool:
    return ('AppThemeConstants' in content
            and 'app_theme_constants.dart' not in content)


def inject_import(content: str, file_path: str) -> str:
    """Add the AppThemeConstants import after the last existing import line."""
    # Compute the relative path from this file to app_theme_constants.dart.
    # Easier: use the package-style import which is unambiguous.
    lines = content.split('\n')
    last_import = -1
    for i, line in enumerate(lines):
        if line.startswith('import '):
            last_import = i
    if last_import == -1:
        # No existing imports — add at top
        return IMPORT_LINE + '\n\n' + content
    lines.insert(last_import + 1, IMPORT_LINE)
    return '\n'.join(lines)


def migrate_file(path: str) -> tuple[int, str]:
    """Apply all replacements. Returns (replacement_count, new_content)."""
    with open(path, 'r', encoding='utf-8') as f:
        original = f.read()
    content = original

    # Sort patterns by length descending so longer patterns match first.
    patterns = sorted(MAP.keys(), key=len, reverse=True)

    count = 0
    for pat in patterns:
        repl = MAP[pat]
        # Word-boundary on the right: must not be followed by alphanumerics
        # (which would mean we're matching a longer identifier like
        # `Colors.greenAccent`). We *do* allow `.` after the match so chains
        # like `Colors.white.withValues(...)` migrate correctly — the
        # length-descending sort ensures `Colors.green.shade50` is replaced
        # before bare `Colors.green` so we don't clobber shaded forms.
        regex = re.compile(re.escape(pat) + r'(?![a-zA-Z0-9_])')
        new_content, n = regex.subn(repl, content)
        if n:
            count += n
            content = new_content

    if count > 0 and needs_import(content):
        content = inject_import(content, path)

    return count, content


def main() -> int:
    lib_dir = os.path.join(REPO, 'lib')
    total_files = 0
    total_replacements = 0
    skipped_files = []

    for root, _dirs, files in os.walk(lib_dir):
        for fn in files:
            if not fn.endswith('.dart'):
                continue
            full = os.path.join(root, fn)
            rel = os.path.relpath(full, REPO)
            if os.path.normpath(rel) in EXCLUDE:
                skipped_files.append(rel)
                continue

            count, new_content = migrate_file(full)
            if count > 0:
                with open(full, 'w', encoding='utf-8', newline='\n') as f:
                    f.write(new_content)
                total_files += 1
                total_replacements += count
                print(f'  [{count:>3}] {rel}')

    print()
    print(f'Migrated {total_replacements} occurrences across {total_files} files.')
    print(f'Skipped (theme definitions): {len(skipped_files)}')
    for s in skipped_files:
        print(f'  - {s}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
