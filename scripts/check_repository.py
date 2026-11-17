"""Check source-package hygiene without requiring Vivado; does not simulate HDL."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parent.parent
files = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
files = [root / name for name in files if name]
assert files, 'No tracked/staged files'
for path in files:
    relative = path.relative_to(root)
    assert relative.parts[0] not in {'build', 'project', '.Xil', 'sim_run'}, relative
    assert path.suffix.lower() not in {'.dcp', '.bit', '.wdb', '.zip', '.xpr', '.v', '.sv'}, relative
    assert path.stat().st_size < 10_000_000, relative
    body = path.read_text(encoding='utf-8-sig')
    assert not re.search(r'(?i)[A-Z]:[/\\](?:Users|Xilinx)[/\\]|DESKTOP-[A-Z0-9]{5,}', body), f'Local machine path: {relative}'
    assert not re.search(r'gh[pousr]_[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----', body), f'Credential-like text: {relative}'
for name in ['create_project.tcl', 'verify_implementation.tcl', 'route_candidate.tcl',
             'audit_routed.tcl', 'open_design.tcl', 'package_project.tcl']:
    body = (root / 'scripts' / name).read_text(encoding='utf-8')
    assert 'set root [file normalize [file join [file dirname [info script]] ..]]' in body, name
assert len(list((root / 'rtl').glob('*.vhd'))) == 7
assert len(list((root / 'sim').glob('*.vhd'))) == 6
assert len(list((root / 'evidence/2026-11-17').glob('*_vhdl.txt'))) == 7
for path in (root / 'evidence/2026-11-17').glob('*_vhdl.txt'):
    assert 'PASS:' in path.read_text(encoding='utf-8'), path.name
print(f'PASS: {len(files)} source/document/evidence files; portable scripts and no generated binaries')
