def main():
    import argparse as _argparse
    import json as _json
    import os as _os
    import re as _re
    import shutil as _shutil
    import hashlib as _hashlib
    from collections import defaultdict as  _defaultdict
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
        '--skip-extras',
        action='store_true',
        help='EXPERIMENTAL: Skips the extra photos like photos that end in "edited" or "EFFECTS".'
    )
    parser.add_argument(
        '--skip-extras-harder',  # Oh yeah, skip my extras harder daddy
        action='store_true',
        help='EXPERIMENTAL: Skips the extra photos like photos like pic(1). Also includes --skip-extras.'
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
        exit(-2)

    PHOTOS_DIR = args.input_folder
    FIXED_DIR = args.output_folder

    TAG_DATE_TIME_ORIGINAL = _piexif.ExifIFD.DateTimeOriginal
    TAG_DATE_TIME_DIGITIZED = _piexif.ExifIFD.DateTimeDigitized
    TAG_DATE_TIME = 306
    TAG_PREVIEW_DATE_TIME = 50971

    photo_formats = ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tif', '.tiff', '.svg', '.heic']
    video_formats = ['.mp4', '.gif', '.mov', '.webm', '.avi', '.wmv', '.rm', '.mpg', '.mpe', '.mpeg', '.m4v']
    extra_formats = [
        '-edited', '-effects', '-smile', '-mix',  # EN/US
        '-edytowane',  # PL
        # Add more "edited" flags in more languages if you want. They need to be lowercase.
    ]

    # Statistics:
    s_removed_duplicates_count = 0
    s_copied_files = 0
    s_cant_insert_exif_files = []  # List of files where inserting exif failed
    s_date_from_folder_files = []  # List of files where date was set from folder name
    s_skipped_extra_files = []  # List of extra files ("-edited" etc) which were skipped

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
        # skips the extra photo file, like edited or effects. They're kinda useless.
        nonlocal s_skipped_extra_files
        if args.skip_extras or args.skip_extras_harder:  # if the file name includes something under the extra_formats, it skips it.
            for extra in extra_formats:
                if extra in file.lower():
                    s_skipped_extra_files.append(file)
                    return False
        if args.skip_extras_harder:
            search = "\(\d+\)\."  # we leave the period in so it doesn't catch folders.
            if bool(_re.search(search, file)):
                # PICT0003(5).jpg -> PICT0003.jpg      The regex would match "(5).", and replace it with a "."
                plain_file = _re.sub(search, '.', file)
                # if the original exists, it will ignore the (1) file, ensuring there is only one copy of each file.
                if _os.path.isfile(plain_file):
                    s_skipped_extra_files.append(file)
                    return False
        return True

    def is_video(file):
        what = _os.path.splitext(file.lower())[1]
        if what not in video_formats:
            return False
        return True

    def chunk_reader(fobj, chunk_size=1024):
        """ Generator that reads a file in chunks of bytes """
        while True:
            chunk = fobj.read(chunk_size)
            if not chunk:
                return
            yield chunk
    
    def get_hash(file, first_chunk_only=False, hash_algo=_hashlib.sha1):
        hashobj = hash_algo()
        with open(file, "rb") as f:
            if first_chunk_only:
                hashobj.update(f.read(1024))
            else:
                for chunk in chunk_reader(f):
                    hashobj.update(chunk)
        return hashobj.digest()

    # PART 1: removing duplicates

    # THIS IS PARTLY COPIED FROM STACKOVERFLOW
    # https://stackoverflow.com/questions/748675/finding-duplicate-files-and-removing-them
    #
    # We now use an optimized version linked from tfeldmann
    # https://gist.github.com/tfeldmann/fc875e6630d11f2256e746f67a09c1ae
    #
    # THANK YOU Todor Minakov (https://github.com/tminakov) and Thomas Feldmann (https://github.com/tfeldmann)
    #
    # NOTE: defaultdict(list) is a multimap, all init array handling is done internally 
    # See: https://en.wikipedia.org/wiki/Multimap#Python
    #
    def find_duplicates(path, filter_fun=lambda file: True):
        files_by_size = _defaultdict(list)
        files_by_small_hash = _defaultdict(list)
        files_by_full_hash = _defaultdict(list)

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

                files_by_size[file_size].append(full_path)

        # For all files with the same file size, get their hash on the first 1024 bytes
        for file_size, files in files_by_size.items():
            if len(files) < 2:
                continue  # this file size is unique, no need to spend cpu cycles on it

            for filename in files:
                try:
                    small_hash = get_hash(filename, first_chunk_only=True)
                except OSError:
                    # the file access might've changed till the exec point got here
                    continue
                files_by_small_hash[(file_size, small_hash)].append(filename)

        # For all files with the hash on the first 1024 bytes, get their hash on the full
        # file - if more than one file is inserted on a hash here they are certinly duplicates
        for files in files_by_small_hash.values():
            if len(files) < 2:
                # the hash of the first 1k bytes is unique -> skip this file
                continue

            for filename in files:
                try:
                    full_hash = get_hash(filename, first_chunk_only=False)
                except OSError:
                    # the file access might've changed till the exec point got here
                    continue

                files_by_full_hash[full_hash].append(filename)

        # Now we have the final multimap of absolute dups, We now can attempt to find the original file
        # and remove all the other duplicates
        for files in files_by_full_hash.values():
            if len(files) < 2:
                continue # this file size is unique, no need to spend cpu cycles on it
            original = None
            for filename in files:
                if not _re.search(r'\(\d+\).', filename):
                    original = filename
            if original is None:
                original = files[0]

            dups = files.copy()
            dups.remove(original)
            duplicates += dups

        return duplicates

    # Removes all duplicates in folder
    def remove_duplicates(dir):
        duplicates = find_duplicates(dir, lambda f: (is_photo(f) or is_video(f)))
        for file in duplicates:
            _os.remove(file)
        nonlocal s_removed_duplicates_count
        s_removed_duplicates_count += len(duplicates)
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
        dir = dir[:10].replace('-', ':').replace(' ', ':') + ' 12:00:00'

        # Sometimes google exports folders without the -, like 2009 08 30...
        # So the end result would be 2009 08 30 12:00:00, which does not match the format.
        # Therefore, we also replace the spaces with ':'

        # Reformat it to check if it matcher, and quit if doesn't match - it's probably a date folder
        try:
            return _datetime.strptime(dir, '%Y:%m:%d %H:%M:%S').strftime('%Y:%m:%d %H:%M:%S')
        except ValueError as e:
            print()
            print(e)
            print()
            print('==========!!!==========')
            print(f"Wrong folder name: {dir}")
            print("You probably forgot to remove 'album folders' from your takeout folder")
            print("Please do that - see README.md or --help for why")
            print("https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper#why-do-you-need-to-cut-out-albums")
            print()
            print('Once you do this, just run it again :)')
            print('==========!!!==========')
            exit(-1)

    def set_creation_date_from_str(file, str_datetime):
        try:
            # Turns out exif can have different formats - YYYY:MM:DD, YYYY/..., YYYY-... etc
            # God wish that americans won't have something like MM-DD-YYYY
            # The replace ': ' to ':0' fixes issues when it reads the string as 2006:11:09 10:54: 1.
            # It replaces the extra whitespace with a 0 for proper parsing
            str_datetime = str_datetime.replace('-', ':').replace('/', ':').replace('.', ':').replace('\\', ':').replace(': ', ':0')[:19]
            timestamp = _datetime.strptime(
                str_datetime,
                '%Y:%m:%d %H:%M:%S'
            ).timestamp()
            _os.utime(file, (timestamp, timestamp))
        except Exception as e:
            print('Error setting creation date from string:')
            print(e)
            raise ValueError(f"Error setting creation date from string: {str_datetime}")

    def set_creation_date_from_exif(file):
        exif_dict = _piexif.load(file)
        tags = [['0th', TAG_DATE_TIME], ['Exif', TAG_DATE_TIME_ORIGINAL], ['Exif', TAG_DATE_TIME_DIGITIZED]]
        datetime_str = ''
        date_set_success = False
        for tag in tags:
            try:
                datetime_str = exif_dict[tag[0]][tag[1]].decode('UTF-8')
                set_creation_date_from_str(file, datetime_str)
                date_set_success = True
                break
            except KeyError:
                pass  # No such tag - continue searching :/
            except ValueError:
                print("Wrong date format in exif!")
                print(datetime_str)
                print("does not match '%Y:%m:%d %H:%M:%S'")
        if not date_set_success:
            raise IOError('No correct DateTime in given exif')

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
            nonlocal s_cant_insert_exif_files
            s_cant_insert_exif_files.append(file)

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

        nonlocal s_date_from_folder_files
        s_date_from_folder_files.append(file)

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
            nonlocal s_copied_files
            s_copied_files += 1
        return True

    def copy_to_target_and_divide(dir, file):
        creation_date = _os.path.getmtime(file)
        date = _datetime.fromtimestamp(creation_date)

        new_path = f"{FIXED_DIR}/{date.year}/{date.month:02}/"
        _os.makedirs(new_path, exist_ok=True)

        new_file = new_name_if_exists(new_path + _os.path.basename(file),
                                      watch_for_duplicates=not args.keep_duplicates)
        _shutil.copy2(file, new_file)
        nonlocal s_copied_files
        s_copied_files += 1
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
    print("Final statistics:")
    print(f"Files copied to target folder: {s_copied_files}")
    print(f"Removed duplicates: {s_removed_duplicates_count}")
    print(f"Files where inserting correct exif failed: {len(s_cant_insert_exif_files)}")
    with open(PHOTOS_DIR + '/failed_inserting_exif.txt', 'w') as f:
        f.write("# This file contains list of files where setting right exif date failed\n")
        f.write("# You might find it useful, but you can safely delete this :)\n")
        f.write("\n".join(s_cant_insert_exif_files))
        print(f" - you have full list in {f.name}")
    print(f"Files where date was set from name of the folder: {len(s_date_from_folder_files)}")
    with open(PHOTOS_DIR + '/date_from_folder_name.txt', 'w') as f:
        f.write("# This file contains list of files where date was set from name of the folder\n")
        f.write("# You might find it useful, but you can safely delete this :)\n")
        f.write("\n".join(s_date_from_folder_files))
        print(f"(you have full list in {f.name})")
    if args.skip_extras or args.skip_extras_harder:
        # Remove duplicates: https://www.w3schools.com/python/python_howto_remove_duplicates.asp
        s_skipped_extra_files = list(dict.fromkeys(s_skipped_extra_files))
        print(f"Extra files that were skipped: {len(s_skipped_extra_files)}")
        with open(PHOTOS_DIR + '/skipped_extra_files.txt', 'w') as f:
            f.write("# This file contains list of extra files (ending with '-edited' etc) which were skipped because "
                    "you've used either --skip-extras or --skip-extras-harder\n")
            f.write("# You might find it useful, but you can safely delete this :)\n")
            f.write("\n".join(s_skipped_extra_files))
            print(f"(you have full list in {f.name})")

    print()
    print('Sooo... what now? You can see README.md for what nice G Photos alternatives I found and recommend')
    print('Have a nice day!')


if __name__ == '__main__':
    main()
