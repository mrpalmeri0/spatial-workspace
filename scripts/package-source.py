#!/usr/bin/env python3
"""Package both native targets using an explicit public source allowlist."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
config = {}
for raw in (root / 'Config/release.env').read_text().splitlines():
    line = raw.strip()
    if line and not line.startswith('#') and '=' in line:
        key, value = line.split('=', 1)
        config[key] = value.strip().strip('"')
version = config['MARKETING_VERSION']
prefix = f'SpatialWorkspace-v{version}-source-preview'
output = root / 'build/exports' / (prefix + '.zip')
files = [root / 'build.sh', root / '.gitignore']
files += [root / name for name in ('README.md', 'README.it.md', 'LEGGIMI-ITALIANO.md', 'CHANGELOG.md', 'CHANGELOG.it.md', 'CONTRIBUTING.md', 'CONTRIBUTING.it.md', 'SECURITY.md', 'SECURITY.it.md', 'NOTICE.md', 'NOTICE.it.md')]
if (root / 'LICENSE').is_file():
    files.append(root / 'LICENSE')
# Only known public source/config extensions; never package arbitrary local files.
allowed = {
    'Sources': {'.swift', '.h'}, 'Shared': {'.swift'}, 'iPhone': {'.swift'},
    'Assets': {'.png', '.icns'}, 'Tests': {'.swift', '.py', '.sh'},
    'scripts': {'.py', '.sh', '.swift'}, 'Config': {'.plist', '.entitlements'},
    'docs/en': {'.md'}, 'docs/it': {'.md'}, 'docs/images': {'.png', '.jpg'},
    'Resources': {'.strings'}, 'examples': {'.md', '.json'},
    '.github': {'.md', '.yml', '.yaml'},
    'RayNeoWorkspace.xcodeproj': {'.pbxproj', '.xcscheme'},
}
for folder, extensions in allowed.items():
    files += [p for p in (root / folder).rglob('*')
              if p.is_file() and not p.is_symlink() and p.suffix in extensions
              and not {'AppIcon.iconset', '__pycache__', 'xcuserdata'}.intersection(p.parts)]
files.append(root / 'Config/release.env')
payload = {p.relative_to(root).as_posix(): p.read_bytes() for p in sorted(set(files))}
payload['Build-preview.command'] = (
    '#!/bin/bash\nset -euo pipefail\ncd "$(dirname "$0")"\n'
    'SIGNING_IDENTITY=- bash build.sh\n'
    'printf "\\nOpen build/dev/RayNeoWorkspace-Dev.app to start.\\n"\n'
).encode()
try:
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True, stderr=subprocess.DEVNULL).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=normal'], cwd=root, text=True).strip())
except (subprocess.CalledProcessError, FileNotFoundError):
    revision = None
    dirty = None  # Source ZIPs can be repackaged without a Git checkout.
manifest = {'version': version + '-dev', 'source_commit': revision,
            'working_tree_dirty': dirty,
            'note': 'Hashes describe packaged bytes; uncommitted changes may differ from source_commit.',
            'files': {name: hashlib.sha256(data).hexdigest() for name, data in sorted(payload.items())}}
payload['SOURCE-MANIFEST.json'] = json.dumps(manifest, indent=2, ensure_ascii=False).encode()
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name, data in sorted(payload.items()):
        info = zipfile.ZipInfo(prefix + '/' + name)
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = ((0o100755 if name.endswith(('.sh', '.command')) else 0o100644) << 16)
        archive.writestr(info, data)
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    for name, data in payload.items():
        assert archive.read(prefix + '/' + name) == data
print(output)
print('SHA256 ' + hashlib.sha256(output.read_bytes()).hexdigest())
print(f'{len(payload)} files; {output.stat().st_size} bytes')
