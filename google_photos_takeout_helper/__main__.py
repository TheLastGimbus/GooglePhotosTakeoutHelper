import sys as _sys

from loguru import logger
from tqdm import tqdm as _tqdm

_sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')
logger.remove()  # removes the default console logger provided by Loguru.
# I find it to be too noisy with details more appropriate for file logging.
# INFO and messages of higher priority only shown on the console.
logger.add(lambda msg: _tqdm.write(msg, end=""), format="{message}", level="INFO")
# This creates a logging sink and handler that puts all messages at or above the TRACE level into a logfile for each run.
logger.add("file_{time}.log", level="TRACE", encoding="utf8")  # Unicode instructions needed to avoid file write errors.


@logger.catch(
    message=
    "WHHoopssiee! Looks like script crashed! This shouldn't happen, although it often does haha :P\n"
    "Most of the times, you should cut out the last printed file (it should be down there somehwere) "
    "to some other folder, and continue\n"
    "\n"
    "If this doesn't help, and it keeps doing this after many cut-outs, you can check out issues tab:\n"
    "https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues \n"
    "to see if anyone has similar issue, or contact me other way:\n"
    "https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/blob/master/README.md#contacterrors \n",
    # Still tell the system that something bad happened
    onerror=lambda e: _sys.exit(1)

)  # wraps entire function in a trap to display enhanced error tracebaks after an exception occurs.
def main():
    import argparse as _argparse
    import json as _json
    import os as _os
    import re as _re
    import shutil as _shutil
    import hashlib as _hashlib
    import functools as _functools
    from collections import defaultdict as  _defaultdict
    from datetime import datetime as _datetime
    from datetime import timedelta as _timedelta
    from pathlib import Path as Path

    try:
        from google_photos_takeout_helper.__version__ import __version__
    except ModuleNotFoundError:
        from __version__ import __version__

    import piexif as _piexif
    from fractions import Fraction  # piexif requires some values to be stored as rationals
    import math
    if _os.name == 'nt':
        import win32_setctime as _windoza_setctime

    parser = _argparse.ArgumentParser(
        prog='Google Photos Takeout Helper',
        usage='google-photos-takeout-helper -i [INPUT TAKEOUT FOLDER] -o [OUTPUT FOLDER]',
        description=
        """This script takes all of your photos from Google Photos takeout, 
        fixes their exif DateTime data (when they were taken) and file creation date,
        and then copies it all to one folder.
        """,
    )
    parser.add_argument('--version', action='version', version=f"%(prog)s {__version__}")
    parser.add_argument(
        '-i', '--input-folder',
        type=str,
        required=True,
        help='Input folder with all stuff from Google Photos takeout zip(s)'
    )
    parser.add_argument(
        '-o', '--output-folder',
        type=str,
        required=False,
        default='ALL_PHOTOS',
        help='Output folders which in all photos will be placed in'
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
        "--divide-to-dates",
        action='store_true',
        help="Create folders and subfolders based on the date the photos were taken"
    )
    parser.add_argument(
        '--albums',
        type=str,
        help="EXPERIMENTAL, MAY NOT WORK FOR EVERYONE: What kind of 'albums solution' you would like:\n"
             "'json' - written in a json file\n"
    )
    args = parser.parse_args()

    logger.info('Heeeere we go!')

    PHOTOS_DIR = Path(args.input_folder)
    FIXED_DIR = Path(args.output_folder)

    TAG_DATE_TIME_ORIGINAL = _piexif.ExifIFD.DateTimeOriginal
    TAG_DATE_TIME_DIGITIZED = _piexif.ExifIFD.DateTimeDigitized
    TAG_DATE_TIME = 306
    TAG_PREVIEW_DATE_TIME = 50971

    photo_formats = ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tif', '.tiff', '.svg', '.heic']
    video_formats = ['.mp4', '.gif', '.mov', '.webm', '.avi', '.wmv', '.rm', '.mpg', '.mpe', '.mpeg', '.mkv', '.m4v',
                     '.mts', '.m2ts']
    extra_formats = [
        '-edited', '-effects', '-smile', '-mix',  # EN/US
        '-edytowane',  # PL
        # Add more "edited" flags in more languages if you want. They need to be lowercase.
    ]

    # Album Multimap
    album_mmap = _defaultdict(list)

    # Duplicate by full hash multimap
    files_by_full_hash = _defaultdict(list)

    # holds all the renamed files that clashed from their
    rename_map = dict()

    _all_jsons_dict = _defaultdict(dict)

    # Statistics:
    s_removed_duplicates_count = 0
    s_copied_files = 0
    s_cant_insert_exif_files = []  # List of files where inserting exif failed
    s_date_from_folder_files = []  # List of files where date was set from folder name
    s_skipped_extra_files = []  # List of extra files ("-edited" etc) which were skipped
    s_no_json_found = []  # List of files where we couldn't find json
    s_no_date_at_all = []  # List of files where there was absolutely no option to set correct date

    FIXED_DIR.mkdir(parents=True, exist_ok=True)

    def for_all_files_recursive(
      dir: Path,
      file_function=lambda fi: True,
      folder_function=lambda fo: True,
      filter_fun=lambda file: True
    ):
        for file in dir.rglob("*"):
            if file.is_dir():
                folder_function(file)
                continue
            elif file.is_file():
                if filter_fun(file):
                    file_function(file)
            else:
                logger.debug(f'Found something weird... {file}')

    # This is required, because windoza crashes when timestamp is negative
    # https://github.com/joke2k/faker/issues/460#issuecomment-308897287
    # This (dynamic assigning a function) mayyy be a little faster than comparing it every time (?)
    datetime_from_timestamp = (lambda t: _datetime(1970, 1, 1) + _timedelta(seconds=int(t))) \
        if _os.name == 'nt' \
        else _datetime.fromtimestamp
    timestamp_from_datetime = (lambda dt: (dt - _datetime(1970, 1, 1)).total_seconds()) \
        if _os.name == 'nt' \
        else _datetime.timestamp

    def is_photo(file: Path):
        if file.suffix.lower() not in photo_formats:
            return False
        # skips the extra photo file, like edited or effects. They're kinda useless.
        nonlocal s_skipped_extra_files
        if args.skip_extras or args.skip_extras_harder:  # if the file name includes something under the extra_formats, it skips it.
            for extra in extra_formats:
                if extra in file.name.lower():
                    s_skipped_extra_files.append(str(file.resolve()))
                    return False
        if args.skip_extras_harder:
            search = r"\(\d+\)\."  # we leave the period in so it doesn't catch folders.
            if bool(_re.search(search, file.name)):
                # PICT0003(5).jpg -> PICT0003.jpg      The regex would match "(5).", and replace it with a "."
                plain_file = file.with_name(_re.sub(search, '.', str(file)))
                # if the original exists, it will ignore the (1) file, ensuring there is only one copy of each file.
                if plain_file.is_file():
                    s_skipped_extra_files.append(str(file.resolve()))
                    return False
        return True

    def is_video(file: Path):
        if file.suffix.lower() not in video_formats:
            return False
        return True

    def chunk_reader(fobj, chunk_size=1024):
        """ Generator that reads a file in chunks of bytes """
        while True:
            chunk = fobj.read(chunk_size)
            if not chunk:
                return
            yield chunk

    def get_hash(file: Path, first_chunk_only=False, hash_algo=_hashlib.sha1):
        hashobj = hash_algo()
        with open(file, "rb") as f:
            if first_chunk_only:
                hashobj.update(f.read(1024))
            else:
                for chunk in chunk_reader(f):
                    hashobj.update(chunk)
        return hashobj.digest()

    def populate_album_map(path: Path, filter_fun=lambda f: (is_photo(f) or is_video(f))):
        if not path.is_dir():
            raise NotADirectoryError('populate_album_map only handles directories not files')

        meta_file_exists = find_album_meta_json_file(path)
        if meta_file_exists is None or not meta_file_exists.exists():
            return False

        # means that we are processing an album so process
        for file in path.rglob("*"):
            if not (file.is_file() and filter_fun(file)):
                continue
            file_name = file.name
            # If it's not in the output folder
            if not (FIXED_DIR / file.name).is_file():
                full_hash = None
                try:
                    full_hash = get_hash(file, first_chunk_only=False)
                except Exception as e:
                    logger.debug(e)
                    logger.debug(f"populate_album_map - couldn't get hash of {file}")
                if full_hash is not None and full_hash in files_by_full_hash:
                    full_hash_files = files_by_full_hash[full_hash]
                    if len(full_hash_files) != 1:
                        logger.error("full_hash_files list should only be one after duplication removal, bad state")
                        exit(-5)
                        return False
                    file_name = full_hash_files[0].name

            # check rename map in case there was an overlap namechange
            if str(file) in rename_map:
                file_name = rename_map[str(file)].name

            album_mmap[file.parent.name].append(file_name)

    # PART 3: removing duplicates

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
    def find_duplicates(path: Path, filter_fun=lambda file: True):
        files_by_size = _defaultdict(list)
        files_by_small_hash = _defaultdict(list)

        for file in path.rglob("*"):
            if file.is_file() and filter_fun(file):
                try:
                    file_size = file.stat().st_size
                except (OSError, FileNotFoundError):
                    # not accessible (permissions, etc) - pass on
                    continue
                files_by_size[file_size].append(file)

        # For all files with the same file size, get their hash on the first 1024 bytes
        logger.info('Calculating small hashes...')
        for file_size, files in _tqdm(files_by_size.items(), unit='files-by-size'):
            if len(files) < 2:
                continue  # this file size is unique, no need to spend cpu cycles on it

            for file in files:
                try:
                    small_hash = get_hash(file, first_chunk_only=True)
                except OSError:
                    # the file access might've changed till the exec point got here
                    continue
                files_by_small_hash[(file_size, small_hash)].append(file)

        # For all files with the hash on the first 1024 bytes, get their hash on the full
        # file - if more than one file is inserted on a hash here they are certinly duplicates
        logger.info('Calculating full hashes...')
        for files in _tqdm(files_by_small_hash.values(), unit='files-by-small-hash'):
            if len(files) < 2:
                # the hash of the first 1k bytes is unique -> skip this file
                continue

            for file in files:
                try:
                    full_hash = get_hash(file, first_chunk_only=False)
                except OSError:
                    # the file access might've changed till the exec point got here
                    continue

                files_by_full_hash[full_hash].append(file)

    # Removes all duplicates in folder
    # ONLY RUN AFTER RUNNING find_duplicates()
    def remove_duplicates():
        nonlocal s_removed_duplicates_count
        # Now we have populated the final multimap of absolute dups, We now can attempt to find the original file
        # and remove all the other duplicates
        for files in _tqdm(files_by_full_hash.values(), unit='duplicates'):
            if len(files) < 2:
                continue  # this file size is unique, no need to spend cpu cycles on it

            s_removed_duplicates_count += len(files) - 1
            for file in files:
                # TODO reconsider which dup we delete these now that we're searching globally?
                if len(files) > 1:
                    file.unlink()
                    files.remove(file)
        return True

    # PART 1: Fixing metadata and date-related stuff

    # Returns json dict
    def find_json_for_file(file: Path):
        parenthesis_regexp = r'\([0-9]+\)'
        parenthesis = _re.findall(parenthesis_regexp, file.name)
        if len(parenthesis) == 1:
            # Fix for files that have as image/video IMG_1234(1).JPG with a json IMG_1234.JPG(1).json
            stripped_filename = _re.sub(parenthesis_regexp, '', file.name)
            potential_json = file.with_name(stripped_filename + parenthesis[0] + '.json')
        else:
            potential_json = file.with_name(file.name + '.json')

        if potential_json.is_file():
            try:
                with open(potential_json, 'r') as f:
                    json_dict = _json.load(f)
                return json_dict
            except:
                raise FileNotFoundError(f"Couldn't find json for file: {file}")

        nonlocal _all_jsons_dict
        # Check if we need to load this folder
        if file.parent not in _all_jsons_dict:
            for json_file in file.parent.rglob("*.json"):
                try:
                    with json_file.open('r') as f:
                        json_dict = _json.load(f)
                        if "title" in json_dict:
                            # We found a JSON file with a proper title, store the file name
                            _all_jsons_dict[file.parent][json_dict["title"]] = json_dict
                except:
                    logger.debug(f"Couldn't open json file {json_file}")

        # Check if we have found the JSON file among all the loaded ones in the folder
        if file.parent in _all_jsons_dict and file.name in _all_jsons_dict[file.parent]:
            # Great we found a valid JSON file in this folder corresponding to this file
            return _all_jsons_dict[file.parent][file.name]
        else:
            nonlocal s_no_json_found
            s_no_json_found.append(str(file.resolve()))
            raise FileNotFoundError(f"Couldn't find json for file: {file}")

    # Returns date in 2019:01:01 23:59:59 format
    def get_date_from_folder_meta(dir: Path):
        file = find_album_meta_json_file(dir)
        if not file:
            logger.debug("Couldn't pull datetime from album meta")
            return None
        try:
            with open(str(file), 'r') as fi:
                album_dict = _json.load(fi)
                # find_album_meta_json_file *should* give us "safe" file
                time = int(album_dict["albumData"]["date"]["timestamp"])
                return datetime_from_timestamp(time).strftime('%Y:%m:%d %H:%M:%S')
        except KeyError:
            logger.error(
                "get_date_from_folder_meta - json doesn't have required stuff "
                "- that probably means that either google fucked us again, or find_album_meta_json_file"
                "is seriously broken"
            )

        return None

    @_functools.lru_cache(maxsize=None)
    def find_album_meta_json_file(dir: Path):
        for file in dir.rglob("*.json"):
            try:
                with open(str(file), 'r') as f:
                    dict = _json.load(f)
                    if "albumData" in dict:
                        return file
            except Exception as e:
                logger.debug(e)
                logger.debug(f"find_album_meta_json_file - Error opening file: {file}")

        return None

    def set_creation_date_from_str(file: Path, str_datetime):
        try:
            # Turns out exif can have different formats - YYYY:MM:DD, YYYY/..., YYYY-... etc
            # God wish that americans won't have something like MM-DD-YYYY
            # The replace ': ' to ':0' fixes issues when it reads the string as 2006:11:09 10:54: 1.
            # It replaces the extra whitespace with a 0 for proper parsing
            str_datetime = str_datetime.replace('-', ':').replace('/', ':').replace('.', ':') \
                               .replace('\\', ':').replace(': ', ':0')[:19]
            timestamp = timestamp_from_datetime(
                _datetime.strptime(
                    str_datetime,
                    '%Y:%m:%d %H:%M:%S'
                )
            )
            _os.utime(file, (timestamp, timestamp))
            if _os.name == 'nt':
                _windoza_setctime.setctime(str(file), timestamp)
        except Exception as e:
            raise ValueError(f"Error setting creation date from string: {str_datetime}")

    def set_creation_date_from_exif(file: Path):
        try:
            # Why do you need to be like that, Piexif...
            exif_dict = _piexif.load(str(file))
        except Exception as e:
            raise IOError("Can't read file's exif!")
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
                logger.debug("Wrong date format in exif!")
                logger.debug(datetime_str)
                logger.debug("does not match '%Y:%m:%d %H:%M:%S'")
        if not date_set_success:
            raise IOError('No correct DateTime in given exif')

    def set_file_exif_date(file: Path, creation_date):
        try:
            exif_dict = _piexif.load(str(file))
        except:  # Sorry but Piexif is too unpredictable
            exif_dict = {'0th': {}, 'Exif': {}}

        creation_date = creation_date.encode('UTF-8')
        exif_dict['0th'][TAG_DATE_TIME] = creation_date
        exif_dict['Exif'][TAG_DATE_TIME_ORIGINAL] = creation_date
        exif_dict['Exif'][TAG_DATE_TIME_DIGITIZED] = creation_date

        try:
            _piexif.insert(_piexif.dump(exif_dict), str(file))
        except Exception as e:
            logger.debug("Couldn't insert exif!")
            logger.debug(e)
            nonlocal s_cant_insert_exif_files
            s_cant_insert_exif_files.append(str(file.resolve()))

    def get_date_str_from_json(json):
        return datetime_from_timestamp(
            int(json['photoTakenTime']['timestamp'])
        ).strftime('%Y:%m:%d %H:%M:%S')

    # ========= THIS IS ALL GPS STUFF =========

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

    def set_file_geo_data(file: Path, json):
        """
        Reads the geoData from google and saves it to the EXIF. This works assuming that the geodata looks like -100.12093, 50.213143. Something like that.

        Written by DalenW.
        :param file:
        :param json:
        :return:
        """

        # prevents crashes
        try:
            exif_dict = _piexif.load(str(file))
        except:
            exif_dict = {'0th': {}, 'Exif': {}}

        # converts a string input into a float. If it fails, it returns 0.0
        def _str_to_float(num):
            if type(num) == str:
                return 0.0
            else:
                return float(num)

        # fallbacks to GeoData Exif if it wasn't set in the photos editor.
        # https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/pull/5#discussion_r531792314
        longitude = _str_to_float(json['geoData']['longitude'])
        latitude = _str_to_float(json['geoData']['latitude'])
        altitude = _str_to_float(json['geoData']['altitude'])

        # Prioritise geoData set from GPhotos editor. If it's blank, fall back to geoDataExif
        if longitude == 0 and latitude == 0:
            longitude = _str_to_float(json['geoDataExif']['longitude'])
            latitude = _str_to_float(json['geoDataExif']['latitude'])
            altitude = _str_to_float(json['geoDataExif']['altitude'])

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
            _piexif.insert(_piexif.dump(exif_dict), str(file))
        except Exception as e:
            logger.debug("Couldn't insert geo exif!")
            # local variable 'new_value' referenced before assignment means that one of the GPS values is incorrect
            logger.debug(e)

    # ============ END OF GPS STUFF ============

    # Fixes ALL metadata, takes just file and dir and figures it out
    def fix_metadata(file: Path):
        # logger.info(file)

        has_nice_date = False
        try:
            set_creation_date_from_exif(file)
            has_nice_date = True
        except (_piexif.InvalidImageDataError, ValueError, IOError) as e:
            logger.debug(e)
            logger.debug(f'No exif for {file}')
        except IOError:
            logger.debug('No creation date found in exif!')

        try:
            google_json = find_json_for_file(file)
            date = get_date_str_from_json(google_json)
            set_file_geo_data(file, google_json)
            set_file_exif_date(file, date)
            set_creation_date_from_str(file, date)
            has_nice_date = True
            return
        except FileNotFoundError as e:
            logger.debug(e)

        if has_nice_date:
            return True

        logger.debug(f'Last option, copying folder meta as date for {file}')
        date = get_date_from_folder_meta(file.parent)
        if date is not None:
            set_file_exif_date(file, date)
            set_creation_date_from_str(file, date)
            nonlocal s_date_from_folder_files
            s_date_from_folder_files.append(str(file.resolve()))
            return True
        else:
            logger.warning(f'There was literally no option to set date on {file}')
            nonlocal s_no_date_at_all
            s_no_date_at_all.append(str(file.resolve()))

        return False

    # PART 2: Copy all photos and videos to target folder

    # Makes a new name like 'photo(1).jpg'
    def new_name_if_exists(file: Path):
        new_name = file
        i = 1
        while True:
            if not new_name.is_file():
                return new_name
            else:
                new_name = file.with_name(f"{file.stem}({i}){file.suffix}")
                rename_map[str(file)] = new_name
                i += 1

    def copy_to_target(file: Path):
        if is_photo(file) or is_video(file):
            new_file = new_name_if_exists(FIXED_DIR / file.name)
            _shutil.copy2(file, new_file)
            nonlocal s_copied_files
            s_copied_files += 1
        return True

    def copy_to_target_and_divide(file: Path):
        creation_date = file.stat().st_mtime
        date = datetime_from_timestamp(creation_date)

        new_path = FIXED_DIR / f"{date.year}/{date.month:02}/"
        new_path.mkdir(parents=True, exist_ok=True)

        new_file = new_name_if_exists(new_path / file.name)
        _shutil.copy2(file, new_file)
        nonlocal s_copied_files
        s_copied_files += 1
        return True

    # xD python lambdas are shit - this is only because we can't do 2 commands, so we do them in arguments
    def _walk_with_tqdm(res, bar: _tqdm):
        bar.update()
        return res

    # Count *all* photo and video files - this is hacky, and we should use .rglob altogether instead of is_photo
    logger.info("Counting how many input files we have ahead...")
    _input_files_count = 0
    for ext in _tqdm(photo_formats + video_formats, unit='formats'):
        _input_files_count += len(list(PHOTOS_DIR.rglob(f'**/*{ext}')))
    logger.info(f'Input files: {_input_files_count}')

    logger.info('=====================')
    logger.info('Fixing files metadata and creation dates...')
    # tqdm progress bar stuff
    _metadata_bar = _tqdm(total=_input_files_count, unit='files')

    for_all_files_recursive(
        dir=PHOTOS_DIR,
        file_function=lambda f: _walk_with_tqdm(fix_metadata(f), _metadata_bar),
        # TODO (probably never, but should): Change this maybe to path.rglob
        filter_fun=lambda f: (is_photo(f) or is_video(f))
    )
    _metadata_bar.close()
    logger.info('=====================')

    logger.info('=====================')
    _copy_bar = _tqdm(total=_input_files_count, unit='files')
    if args.divide_to_dates:
        logger.info('Creating subfolders and dividing files based on date...')
        for_all_files_recursive(
            dir=PHOTOS_DIR,
            file_function=lambda f: _walk_with_tqdm(copy_to_target_and_divide(f), _copy_bar),
            filter_fun=lambda f: (is_photo(f) or is_video(f))
        )
    else:
        logger.info('Copying all files to one folder...')
        logger.info('(If you want, you can get them organized in folders based on year and month.'
                    ' Run with --divide-to-dates to do this)')
        for_all_files_recursive(
            dir=PHOTOS_DIR,
            file_function=lambda f: _walk_with_tqdm(copy_to_target(f), _copy_bar),
            filter_fun=lambda f: (is_photo(f) or is_video(f))
        )
    _copy_bar.close()
    logger.info('=====================')
    logger.info('=====================')
    logger.info('Finding duplicates...')
    find_duplicates(FIXED_DIR, lambda f: (is_photo(f) or is_video(f)))
    logger.info('Removing duplicates...')
    remove_duplicates()
    logger.info('=====================')
    if args.albums is not None:
        if args.albums.lower() == 'json':
            logger.info('=====================')
            logger.info('Populate json file with albums...')
            logger.info('=====================')
            for_all_files_recursive(
                dir=PHOTOS_DIR,
                folder_function=populate_album_map
            )
            file = PHOTOS_DIR / 'albums.json'
            with open(file, 'w', encoding="utf-8") as outfile:
                _json.dump(album_mmap, outfile)
            logger.info(str(file))

    logger.info('')
    logger.info('DONE! FREEEEEDOOOOM!!!')
    logger.info('')
    logger.info("Final statistics:")
    logger.info(f"Files copied to target folder: {s_copied_files}")
    logger.info(f"Removed duplicates: {s_removed_duplicates_count}")
    logger.info(f"Files for which we couldn't find json: {len(s_no_json_found)}")
    if len(s_no_json_found) > 0:
        with open(PHOTOS_DIR / 'no_json_found.txt', 'w', encoding="utf-8") as f:
            f.write("# This file contains list of files for which there was no corresponding .json file found\n")
            f.write("# You might find it useful, but you can safely delete this :)\n")
            f.write("\n".join(s_no_json_found))
            logger.info(f" - you have full list in {f.name}")
    logger.info(f"Files where inserting new exif failed: {len(s_cant_insert_exif_files)}")
    if len(s_cant_insert_exif_files) > 0:
        logger.info("(This is not necessary bad thing - pretty much all videos fail, "
                    "and your photos probably have their original exif already")
        with open(PHOTOS_DIR / 'failed_inserting_exif.txt', 'w', encoding="utf-8") as f:
            f.write("# This file contains list of files where setting right exif date failed\n")
            f.write("# You might find it useful, but you can safely delete this :)\n")
            f.write("\n".join(s_cant_insert_exif_files))
            logger.info(f" - you have full list in {f.name}")
    logger.info(f"Files where date was set from name of the folder: {len(s_date_from_folder_files)}")
    if len(s_date_from_folder_files) > 0:
        with open(PHOTOS_DIR / 'date_from_folder_name.txt', 'w', encoding="utf-8") as f:
            f.write("# This file contains list of files where date was set from name of the folder\n")
            f.write("# You might find it useful, but you can safely delete this :)\n")
            f.write("\n".join(s_date_from_folder_files))
            logger.info(f" - you have full list in {f.name}")
    if args.skip_extras or args.skip_extras_harder:
        # Remove duplicates: https://www.w3schools.com/python/python_howto_remove_duplicates.asp
        s_skipped_extra_files = list(dict.fromkeys(s_skipped_extra_files))
        logger.info(f"Extra files that were skipped: {len(s_skipped_extra_files)}")
        with open(PHOTOS_DIR / 'skipped_extra_files.txt', 'w', encoding="utf-8") as f:
            f.write("# This file contains list of extra files (ending with '-edited' etc) which were skipped because "
                    "you've used either --skip-extras or --skip-extras-harder\n")
            f.write("# You might find it useful, but you can safely delete this :)\n")
            f.write("\n".join(s_skipped_extra_files))
            logger.info(f" - you have full list in {f.name}")
    if len(s_no_date_at_all) > 0:
        logger.info('')
        logger.info(f"!!! There were {len(s_no_date_at_all)} files where there was absolutely no way to set "
                    f"a correct date! They will probably appear at the top of the others, as their 'last modified' "
                    f"value is set to moment of downloading your takeout :/")
        with open(PHOTOS_DIR / 'unsorted.txt', 'w', encoding="utf-8") as f:
            f.write("# This file contains list of files where there was no way to set correct date!\n")
            f.write("# You probably want to set their dates manually - but you can delete this if you want\n")
            f.write("\n".join(s_no_date_at_all))
            logger.info(f" - you have full list in {f.name}")

    logger.info('')
    logger.info('Sooo... what now? You can see README.md for what nice G Photos alternatives I found and recommend')
    logger.info('')
    logger.info('If I helped you, you can consider donating me: https://www.paypal.me/TheLastGimbus')
    logger.info('Have a nice day!')


if __name__ == '__main__':
    main()
