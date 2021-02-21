import unittest
import shutil
import os
from pathlib import Path
import piexif
from loguru import logger

from google_photos_takeout_helper import __main__ as helper

# Run with `python3 -m unittest discover -s tests/integration`
class TestIntegration(unittest.TestCase):
    def setUp(self):
        integration_tests_dir = Path(__file__).resolve().parent
        fixtures_dir = integration_tests_dir / 'fixtures'
        workbench_dir = integration_tests_dir / 'workbench'

        # re-create workbench folder structure
        shutil.rmtree(workbench_dir, ignore_errors=True)

        self.input_dir = workbench_dir / 'input'
        self.output_dir = workbench_dir / 'output'
        self.reference_dir = workbench_dir / 'reference'

        # copy test data into workbench
        # We can't work directly from the 
        test_name = self.id().split('.')[-1]    # `id()` returns something like `test_integration.TestIntegration.test_set1`
        data_dir = fixtures_dir / test_name
        shutil.copytree(data_dir / 'input', self.input_dir)
        reference_source_dir = data_dir / 'reference'
        if reference_source_dir.exists():
            shutil.copytree(data_dir / 'reference', self.reference_dir)

    def test_set1(self):
        helper.main(['-i', str(self.input_dir), '-o', str(self.output_dir)])
        for file in self.output_dir.rglob('*'):
            reference = self.reference_dir / file.name
            self.assertFileMatches(file, reference)

    def test_current_reference_collection(self):
        helper.main(['-i', str(self.input_dir), '-o', str(self.output_dir), '--divide-to-dates'])
        for file in self.output_dir.rglob('*'):
            if not file.is_file():
                continue
            reference = self.reference_dir / file.relative_to(self.output_dir)
            self.assertFileMatches(file, reference)

    def assertFileMatches(self, file, reference):
        self.assertFileDates(file, reference)
        self.assertExifData(file, reference)

    def assertFileDates(self, file, reference):
        stats = os.stat(file)
        reference_stats = os.stat(reference)
        self.assertEqual(stats.st_birthtime, reference_stats.st_birthtime, f'File creation date not matching for {file}')
        self.assertEqual(stats.st_mtime, reference_stats.st_mtime, f'File modification date not matching for {file}')

    def assertExifData(self, file, reference):
        file_exif = None
        reference_exif = None
        try:
            file_exif = piexif.load(str(file))
        except Exception as e:
            pass
        try:
            reference_exif = piexif.load(str(reference))
        except Exception as e:
            pass

        if file_exif is None and reference_exif is None:
            # it's okay if both files don't have EXIF data
            return
        self.assertEqual(file_exif is None, reference_exif is None, f'EXIF presence mismatch for {file}')

        # show long diffs
        self.maxDiff = None

        # remove the thumbnails to keep the diff smaller
        del file_exif['thumbnail']
        del reference_exif['thumbnail']
       
        # see https://www.exiv2.org/tags.html for tag details
        TAG_DATE_TIME = 306
        tags = [
            ['0th', piexif.ImageIFD.DateTime], 
            ['Exif', piexif.ExifIFD.DateTimeOriginal], 
            ['Exif', piexif.ExifIFD.DateTimeDigitized],
            ['GPS', piexif.GPSIFD.GPSVersionID],
            ['GPS', piexif.GPSIFD.GPSLatitude],
            ['GPS', piexif.GPSIFD.GPSLatitudeRef],
            ['GPS', piexif.GPSIFD.GPSLongitude],
            ['GPS', piexif.GPSIFD.GPSLongitudeRef],
            ['GPS', piexif.GPSIFD.GPSAltitude],
            ['GPS', piexif.GPSIFD.GPSAltitudeRef]
        ]
        for tag in tags:
            file_value = None
            reference_value = None
            try:
                file_value = file_exif[tag[0]][tag[1]]
            except KeyError:
                pass
            try:
                reference_value = reference_exif[tag[0]][tag[1]]
            except KeyError:
                pass
            name = piexif.TAGS[tag[0]][tag[1]]['name']
            self.assertEqual(file_value, reference_value, f'EXIF {tag[0]}.{name} mismatch for {file}')


if __name__ == '__main__':
    unittest.main()
