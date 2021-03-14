import json
import pathlib

test_assets_path = pathlib.Path('../__takeout_helper_test_data__')
out_path = test_assets_path / 'output'
asserts_path = test_assets_path / 'asserts'


def test_file_modified():
    with open(asserts_path / 'file_modified.json', 'r') as f:
        _data = json.load(f)
        pairs = {**_data['photos'], **_data['videos']}

    for key in pairs:
        file = out_path / key
        assert file.stat().st_mtime == pairs[key]
