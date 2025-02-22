import argparse
import re

def main():
    p = argparse.ArgumentParser(description='Get changelog for a specific version.')
    p.add_argument('--version', required=True, help='Version to get changelog for. You can type with or without "v" prefix')
    args = p.parse_args()

    version = args.version.strip().replace('v', '')
    if not re.match(r'^\d+\.\d+\.\d+$', version):
        raise ValueError('Invalid version format. Expected format: X.Y.Z')

    try:
        with open("CHANGELOG.md", 'r') as f:
            lines = f.read()
    except FileNotFoundError:
        raise FileNotFoundError('CHANGELOG.md file not found.')

    # Get first "##" followed by version
    try:
        start = lines.index(f'## {version}')
    except ValueError:
        raise ValueError(f'Version {version} not found in CHANGELOG.md')

    # Start from newline
    start = lines.index('\n', start) + 1
    # Find next "##" (previous version)
    try:
        end = lines.index('\n## ', start)
    except ValueError:
        # in case there is no previous version
        end = len(lines)

    print(lines[start:end].strip())

if __name__ == '__main__':
    main()
