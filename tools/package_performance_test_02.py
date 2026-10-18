"""Package the existing compiled Test 02 artifacts without touching formal archives."""
from pathlib import Path
import hashlib
import zipfile

root = Path(__file__).resolve().parents[1]
path = root / 'tools/package_release.py'
dll = (root / 'Data/F4SE/Plugins/AozoraItemExtractor.dll').read_bytes()
assert b'performance-test-02-20261018' in dll, 'Stage the compiled Test 02 DLL first'
assert b'PreviewSpike07' not in dll and b'AIE-EXAMINE-OBS01' not in dll
source = path.read_text(encoding='utf-8-sig')
source = source.replace("version=(r/'VERSION.txt').read_text().strip()", "version=(r/'VERSION.txt').read_text().strip()+' Performance Test 02'")
source = source.replace("out=r/'package/formal'", "out=r/'package/test/performance-02'")
exec(compile(source, str(path), 'exec'), {'__file__': str(path), '__name__': '__main__'})
out = root / 'package/test/performance-02'
core = out / 'Aozora Item Extractor Ultimate Edition v1.0.6 Performance Test 02.zip'
with zipfile.ZipFile(core, 'a', zipfile.ZIP_DEFLATED) as archive:
    archive.write(root/'docs/PERFORMANCE_TEST_02.md', 'PERFORMANCE_TEST_02.md')
    archive.write(root/'docs/PERFORMANCE_TEST_02_BUILD.md', 'PERFORMANCE_TEST_02_BUILD.md')
# Recalculate after adding the diagnostic guide to the core.
lines = []
for package in sorted(out.glob('*.zip')):
    lines.append(hashlib.sha256(package.read_bytes()).hexdigest().upper()+'  '+package.name)
(out/'SHA256SUMS.txt').write_text('\n'.join(lines)+'\n', encoding='utf-8')
print('Final package checksums:\n'+'\n'.join(lines))
