def main():
    import argparse as _argparse
    import json as _json
    import os as _os
    import re as _re
    import shutil as _shutil
    from datetime import datetime as _datetime

    import piexif as _piexif
    from fractions import Fraction  # piexif requires some values to be stored as rationals
    import math

    parser = _argparse.ArgumentParser(
        prog='Photos takeout helper',
        usage='python3 photos_helper.py -i [INPUT TAKEOUT FOLDER] -o [OUTPUT FOLDER]',
        description=
        """This script takes all of your photos form Google Photos takeout, 
        fixes their exif DateTime data (when they were taken) and file creation date,
        and then copies it all to one folder.
        "Why do I need to delete album folders?"
        -They mostly contain duplicates of same photos that are in corresponding "date folder" :/
        You need to do this before running this.
        """,
    )
    parser.add_argument(
        '-i', '--input-folder',
        type=str,
        required=True,
        help='Input folder with all stuff form Google Photos takeout zip(s)'
    )
    parser.add_argument(
        '-o', '--output-folder',
        type=str,
        required=False,
        default='ALL_PHOTOS',
        help='Output folders which in all photos will be placed in'
    )
    parser.add_argument(
        '--keep-duplicates',
        action='store_true',
        help="Don't remove duplicates. Disclaimer: "
             "duplicates will have trouble to find correct creation date, "
             "and it may not be accurate"
    )
    parser.add_argument(
        '--dont-fix',
        action='store_true',
        help="Don't try to fix Dates. I don't know why would you not want to do that, but ok"
    )
    parser.add_argument(
        '--dont-copy',
        action='store_true',
        help="Don't copy files to target folder. I don't know why would you not want to do that, but ok"
    )
    parser.add_argument(
        "--divide-to-dates",
        action='store_true',
        help="Create folders and subfolders based on the date the photos were taken"
             "If you use the --dont-copy flag, or the --dont-fix flag, this is useless"
    )
    args = parser.parse_args()

    print('DISCLAIMER!')
    print("Before running this script, you need to cut out all folders that aren't dates")
    print("That is, all album folders, and everything that isn't named")
    print('2016-06-16 (or with "#", they are good)')
    print('See README.md or --help on why')
    print("(Don't worry, your photos from albums are already in some date folder)")
    print()
    print('Type "yes i did that" to confirm:')
    response = input()
    if response.lower() == 'yes i did that':
        print('Heeeere we go!')
    else:
        print('Ok come back when you do this')

    PHOTOS_DIR = args.input_folder
    FIXED_DIR = args.output_folder

    TAG_DATE_TIME_ORIGINAL = _piexif.ExifIFD.DateTimeOriginal
    TAG_DATE_TIME_DIGITIZED = _piexif.ExifIFD.DateTimeDigitized
    TAG_DATE_TIME = 306
    TAG_PREVIEW_DATE_TIME = 50971

    photo_formats = ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tif', '.tiff', '.svg', '.heic']
    video_formats = ['.mp4', '.gif', '.mov', '.webm', '.avi', '.wmv', '.rm', '.mpg', '.mpe', '.mpeg', '.m4v']

    _os.makedirs(FIXED_DIR, exist_ok=True)

    def for_all_files_recursive(
            dir,
            file_function=lambda fo, fi: True,
            folder_function=lambda fo: True,
            filter_fun=lambda file: True
    ):
        for file in _os.listdir(dir):
            file = dir + '/' + file
            if _os.path.isdir(file):
                folder_function(file)
                for_all_files_recursive(file, file_function, folder_function, filter_fun)
            elif _os.path.isfile(file):
                if filter_fun(file):
                    file_function(dir, file)
            else:
                print('Found something weird...')
                print(file)

    def is_photo(file):
        what = _os.path.splitext(file.lower())[1]
        if what not in photo_formats:
            return False
        return True

    def is_video(file):
        what = _os.path.splitext(file.lower())[1]
        if what not in video_formats:
            return False
        return True

    # PART 1: removing duplicates

    # THIS IS PARTLY COPIED FROM STACKOVERFLOW
    # THANK YOU @Todor Minakov
    def find_duplicates(path, filter_fun=lambda file: True):
        hashes_by_size = {}
        # Excluding original files (or first file if original not found)
        duplicates = []

        for dirpath, dirnames, filenames in _os.walk(path):
            for filename in filenames:
                if not filter_fun(filename):
                    continue
                full_path = _os.path.join(dirpath, filename)
                try:
                    # if the target is a symlink (soft one), this will
                    # dereference it - change the value to the actual target file
                    full_path = _os.path.realpath(full_path)
                    file_size = _os.path.getsize(full_path)
                except (OSError,):
                    # not accessible (permissions, etc) - pass on
                    continue

                duplicate = hashes_by_size.get(file_size)

                if duplicate:
                    hashes_by_size[file_size].append(full_path)
                else:
                    hashes_by_size[file_size] = []  # create the list for this file size
                    hashes_by_size[file_size].append(full_path)

        for size in hashes_by_size.keys():
            if len(hashes_by_size[size]) > 1:
                original = None
                for filename in hashes_by_size[size]:
                    if not _re.search(r'\(\d+\).', filename):
                        original = filename
                if original is None:
                    original = hashes_by_size[size][0]

                dups = hashes_by_size[size].copy()
                dups.remove(original)
                duplicates += dups

        return duplicates

    # Removes all duplicates in folder
    def remove_duplicates(dir):
        duplicates = find_duplicates(dir, lambda f: (is_photo(f) or is_video(f)))
        for file in duplicates:
            _os.remove(file)
        return True

    # PART 2: Fixing metadata and date-related stuff

    # Returns json dict
    def find_json_for_file(dir, file):
        potential_json = file + '.json'
        if _os.path.isfile(potential_json):
            try:
                with open(potential_json, 'r') as f:
                    dict = _json.load(f)
                return dict
            except:
                raise FileNotFoundError('Couldnt find json for file: ' + file)
        else:
            raise FileNotFoundError('Couldnt find json for file: ' + file)

    # Returns date in 2019:01:01 23:59:59 format
    def get_date_from_folder_name(dir):
        dir = _os.path.basename(_os.path.normpath(dir))
        dir = dir[:10].replace('-', ':') + ' 12:00:00'

        # Reformat it to check if it matcher, and quit if doesn't match - it's probably a date folder
        try:
            return _datetime.strptime(dir, '%Y:%m:%d %H:%M:%S').strftime('%Y:%m:%d %H:%M:%S')
        except ValueError as e:
            print()
            print(e)
            print()
            print('==========!!!==========')
            print("You probably forgot to remove 'album folders' from your takeout folder")
            print("Please do that - see README.md or --help for why")
            print()
            print('Once you do this, just run it again :)')
            print('==========!!!==========')
            exit(-1)


    def set_creation_date_from_str(file, str_datetime):
        try:
            # Turns out exif can have different formats - YYYY:MM:DD, YYYY/..., YYYY-... etc
            # God wish that americans won't have something like MM-DD-YYYY
            str_datetime = str_datetime.replace('-', ':').replace('/', ':').replace('.', ':').replace('\\', ':')[:19]
            timestamp = _datetime.strptime(
                str_datetime,
                '%Y:%m:%d %H:%M:%S'
            ).timestamp()
        except Exception as e:
            print('Error setting creation date from string:')
            print(e)
        _os.utime(file, (timestamp, timestamp))

    def set_creation_date_from_exif(file):
        exif_dict = _piexif.load(file)
        tags = [['0th', TAG_DATE_TIME], ['Exif', TAG_DATE_TIME_ORIGINAL], ['Exif', TAG_DATE_TIME_DIGITIZED]]
        datetime_str = None
        for tag in tags:
            try:
                datetime_str = exif_dict[tag[0]][tag[1]].decode('UTF-8')
                break
            except KeyError:
                pass
        if datetime_str is None or datetime_str.strip() == '':
            raise IOError('No DateTime in given exif')
        set_creation_date_from_str(file, datetime_str)

    def set_file_exif_date(file, creation_date):
        try:
            exif_dict = _piexif.load(file)
        except (_piexif.InvalidImageDataError, ValueError):
            exif_dict = {'0th': {}, 'Exif': {}}

        creation_date = creation_date.encode('UTF-8')
        exif_dict['0th'][TAG_DATE_TIME] = creation_date
        exif_dict['Exif'][TAG_DATE_TIME_ORIGINAL] = creation_date
        exif_dict['Exif'][TAG_DATE_TIME_DIGITIZED] = creation_date

        try:
            _piexif.insert(_piexif.dump(exif_dict), file)
        except Exception as e:
            print("Couldn't insert exif!")
            print(e)

    def get_date_str_from_json(json):
        return _datetime.fromtimestamp(
            int(json['photoTakenTime']['timestamp'])
        ).strftime('%Y:%m:%d %H:%M:%S')

    def change_to_rational(number):
        """convert a number to rantional
        Keyword arguments: number
        return: tuple like (1, 2), (numerator, denominator)
        """
        f = Fraction(str(number))
        return f.numerator, f.denominator

    # got this here https://github.com/hMatoba/piexifjs/issues/1#issuecomment-260176317
    def degToDmsRational(degFloat):
        min_float = degFloat % 1 * 60
        sec_float = min_float % 1 * 60
        deg = math.floor(degFloat)
        deg_min = math.floor(min_float)
        sec = round(sec_float * 100)

        return [(deg, 1), (deg_min, 1), (sec, 100)]

    def set_file_geo_data(file, json):
        """
        Reads the geoData from google and saves it to the EXIF. This works assuming that the geodata looks like -100.12093, 50.213143. Something like that.

        Written by DalenW.
        :param file:
        :param json:
        :return:
        """

        # prevents crashes
        try:
            exif_dict = _piexif.load(file)
        except (_piexif.InvalidImageDataError, ValueError):
            exif_dict = {'0th': {}, 'Exif': {}}

        # fetches geo data from the photos editor first.
        longitude = float(json['geoData']['longitude'])
        latitude = float(json['geoData']['latitude'])
        altitude = float(json['geoData']['altitude'])

        # fallbacks to GeoData Exif if it wasn't set in the photos editor.
        # https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/pull/5#discussion_r531792314
        longitude = float(json['geoData']['longitude'])
        latitude = float(json['geoData']['latitude'])
        altitude = json['geoData']['altitude']
        # Prioritise geoData set from GPhotos editor
        if longitude == 0 and latitude == 0:
            longitude = float(json['geoDataExif']['longitude'])
            latitude = float(json['geoDataExif']['latitude'])
            altitude = json['geoDataExif']['altitude']

        # latitude >= 0: North latitude -> "N"
        # latitude < 0: South latitude -> "S"
        # longitude >= 0: East longitude -> "E"
        # longitude < 0: West longitude -> "W"

        if longitude >= 0:
            longitude_ref = 'E'
        else:
            longitude_ref = 'W'
            longitude = longitude * -1

        if latitude >= 0:
            latitude_ref = 'N'
        else:
            latitude_ref = 'S'
            latitude = latitude * -1

        # referenced from https://gist.github.com/c060604/8a51f8999be12fc2be498e9ca56adc72
        gps_ifd = {
            _piexif.GPSIFD.GPSVersionID: (2, 0, 0, 0)
        }

        # skips it if it's empty
        if latitude != 0 or longitude != 0:
            gps_ifd.update({
                _piexif.GPSIFD.GPSLatitudeRef: latitude_ref,
                _piexif.GPSIFD.GPSLatitude: degToDmsRational(latitude),

                _piexif.GPSIFD.GPSLongitudeRef: longitude_ref,
                _piexif.GPSIFD.GPSLongitude: degToDmsRational(longitude)
            })

        if altitude != 0:
            gps_ifd.update({
                _piexif.GPSIFD.GPSAltitudeRef: 1,
                _piexif.GPSIFD.GPSAltitude: change_to_rational(round(altitude))
            })

        gps_exif = {"GPS": gps_ifd}
        exif_dict.update(gps_exif)

        try:
            _piexif.insert(_piexif.dump(exif_dict), file)
        except Exception as e:
            print("Couldn't insert geo exif!")
            # local variable 'new_value' referenced before assignment means that one of the GPS values is incorrect
            print(e)

    # Fixes ALL metadata, takes just file and dir and figures it out
    def fix_metadata(dir, file):
        print(file)

        has_nice_date = False
        try:
            set_creation_date_from_exif(file)
            has_nice_date = True
        except (_piexif.InvalidImageDataError, ValueError) as e:
            print(e)
            print(f'No exif for {file}')
        except IOError:
            print('No creation date found in exif!')

        try:
            google_json = find_json_for_file(dir, file)
            date = get_date_str_from_json(google_json)
            set_file_geo_data(file, google_json)
            set_file_exif_date(file, date)
            set_creation_date_from_str(file, date)
            has_nice_date = True
            return
        except FileNotFoundError:
            print("Couldn't find json for file :/")

        if has_nice_date:
            return

        print('Last chance, coping folder name as date...')
        date = get_date_from_folder_name(dir)
        set_file_exif_date(file, date)
        set_creation_date_from_str(file, date)
        return True

    # PART 3: Copy all photos and videos to target folder

    # Makes a new name like 'photo(1).jpg'
    def new_name_if_exists(file_name, watch_for_duplicates=True):
        split = _os.path.splitext(file_name)
        new_name = split[0] + split[1]
        i = 1
        while True:
            if not _os.path.isfile(new_name):
                return new_name
            else:
                if watch_for_duplicates:
                    if _os.path.getsize(new_name) == _os.path.getsize(file_name):
                        return file_name
                new_name = split[0] + '(' + str(i) + ')' + split[1]
                i += 1

    def copy_to_target(dir, file):
        if is_photo(file) or is_video(file):
            new_file = new_name_if_exists(FIXED_DIR + '/' + _os.path.basename(file),
                                          watch_for_duplicates=not args.keep_duplicates)
            _shutil.copy2(file, new_file)
        return True

    def copy_to_target_and_divide(dir, file):
        creation_date = _os.path.getmtime(file)
        date = _datetime.fromtimestamp(creation_date)

        new_path = f"{FIXED_DIR}/{date.year}/{date.month:02}/"
        _os.makedirs(new_path, exist_ok=True)

        new_file = new_name_if_exists(new_path + _os.path.basename(file),
                                      watch_for_duplicates=not args.keep_duplicates)
        _shutil.copy2(file, new_file)
        return True

    if not args.keep_duplicates:
        print('=====================')
        print('Removing duplicates...')
        print('=====================')
        for_all_files_recursive(
            dir=PHOTOS_DIR,
            folder_function=remove_duplicates
        )
    if not args.dont_fix:
        print('=====================')
        print('Fixing files metadata and creation dates...')
        print('=====================')
        for_all_files_recursive(
            dir=PHOTOS_DIR,
            file_function=fix_metadata,
            filter_fun=lambda f: (is_photo(f) or is_video(f))
        )
    if not args.dont_fix and not args.dont_copy and args.divide_to_dates:
        print('=====================')
        print('Creating subfolders and dividing files based on date...')
        print('=====================')
        for_all_files_recursive(
            dir=PHOTOS_DIR,
            file_function=copy_to_target_and_divide,
            filter_fun=lambda f: (is_photo(f) or is_video(f))
        )
    elif not args.dont_copy:
        print('=====================')
        print('Coping all files to one folder...')
        print('(If you want, you can get them organized in folders based on year and month.'
              ' Run with --divide-to-dates to do this)')
        print('=====================')
        for_all_files_recursive(
            dir=PHOTOS_DIR,
            file_function=copy_to_target,
            filter_fun=lambda f: (is_photo(f) or is_video(f))
        )

    print()
    print('DONE! FREEDOM!')
    print()
    print()
    print('Sooo... what now? You can see README.md for what nice G Photos alternatives I found and recommend')
    print('Have a nice day!')


if __name__ == '__main__':
    main()
