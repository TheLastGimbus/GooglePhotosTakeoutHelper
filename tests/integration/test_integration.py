import unittest

from google_photos_takeout_helper import __main__ as helper

# Run with `python3 -m unittest discover -s tests/integration`
class TestIntegration(unittest.TestCase):
    def test_integration(self):
        # TODO: remove all files from `output`
        helper.main(["-i", "tests/integration/fixtures/input", "-o", "tests/integration/fixtures/output"])
        # TODO: compare each each file in `output` to the one in `reference`

    def assertFileMatches(self, file, reference):
        # raise AssertionError('File not exists in path "' + path + '".')
        pass

if __name__ == '__main__':
    unittest.main()
