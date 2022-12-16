import argparse
import re

p = argparse.ArgumentParser()
p.add_argument('--version', help='Version to get changelog for. You can type with or without "v" prefix')
args = p.parse_args()

version = args.version.strip().replace('v', '')
if not re.match(r'\d+.\d+.\d+', version):
    raise ValueError('Invalid version')

with open("CHANGELOG.md", 'r') as f:
    lines = f.read()

# Get first "##" followed by version
start = lines.index(f'## {version}')
# Start from newline
start = lines.index('\n', start) + 1
# Find next "##" (previous version)
try:
    end = lines.index('\n## ', start)
except ValueError:
    # in case there is no previous version
    end = -1

print(lines[start:end].strip())
