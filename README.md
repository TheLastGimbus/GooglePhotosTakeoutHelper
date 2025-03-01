[![AUR](https://img.shields.io/aur/version/gpth-bin?logo=arch-linux)](https://aur.archlinux.org/packages/gpth-bin)
[![total Github Releases downloads](https://img.shields.io/github/downloads/TheLastGimbus/GooglePhotosTakeoutHelper/total?label=total%20downloads)](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/releases/)
[![latest version downloads](https://img.shields.io/github/downloads/TheLastGimbus/GooglePhotosTakeoutHelper/latest/total?label=latest%20version%20downloads)](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/releases/latest)
[![resolved Github issues](https://img.shields.io/github/issues-closed/TheLastGimbus/GooglePhotosTakeoutHelper?label=resolved%20issues)](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues)
[![commit activity](https://img.shields.io/github/commit-activity/y/TheLastGimbus/GooglePhotosTakeoutHelper)](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/graphs/contributors)

# Google Photos Takeout Helper 📸🆘

## What is this for 🧐

If you ever want to move from Google Photos to other platform/solution, your fastest choice to export all photos is [Google Takeout 🥡](https://takeout.google.com/)

But when you download it, you will find yourself with zips with hundreds of little folders with weird `.json` files inside 🍝.
What if you want to just have one folder with all photos, in chronological order? Good luck copying all of that 🙃

This script does just that - it organizes and cleans up your Takeout for you 🧹😌

It will take all of those folders, find all photos in them, set their `file last modified` correctly, and put it in one big folder (or folders divided by a month) 🗄

## How to use

Since `v3.2.0`, `gpth` is interactive 🎉 - you don't need to type any complicated arguments - just get your takeout, run gpth, and follow prompted instructions 💃

If you want to run it on Synology, have problems with interactive, or just love cmd, look at ["Running manually with cmd"](#running-manually-with-cmd). Otherwise, just:

### 1. Get all your photos from [Google Takeout](https://takeout.google.com/) 📥

"deselect all" and then select only Google Photos

<img width="75%" alt="gpth usage image tutorial" src="https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/assets/40139196/8e85f58c-9958-466a-a176-51af85bb73dd">

### 2. Unzip them all and merge into one, so that all "Takeout" folders become one

   **NOTE:** Keep those original zips, you may need them if anything goes wrong

   <img width="75%" alt="Unzip image tutorial" src="https://user-images.githubusercontent.com/40139196/229361367-b9803ab9-2724-4ddf-9af5-4df507e02dfe.png">

### 3. Download the executable for your system from [releases tab](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/releases) 🛒 ([also available on AUR 😏](https://aur.archlinux.org/packages/gpth-bin))

### 4. Run `gpth`

- On Windoza: just double-click the downloaded `.exe` 🎉 - tell windoza defender that it's safe, and follow prompted instructions 🧾
- On Mac/Linux: open terminal, `cd` to the folder with downloaded executable and run it:

     ```bash
     # if you have Mac with M1/M2 chip, you need to enable x86 emulation
     # otherwise, just skip it
     softwareupdate --install-rosetta

     cd Downloads # probably
     # add execute permission for file
     chmod +x gpth-macos # or gpth-linux
     # tell MacOS Gatekeeper to not worry
     xattr -r -d com.apple.quarantine gpth-macos
     # run it 🏃
     ./gpth-macos # or ./gpth-linux
     ```

## Recent Improvements 🚀

The latest version includes several improvements to make the tool more robust and user-friendly:

- **Enhanced Error Handling**: Better error messages and logging for easier troubleshooting
- **Improved File Handling**: Better handling of large files and non-ASCII characters
- **More Language Support**: Added support for edited photos in more languages (Turkish, Arabic, Hindi, Vietnamese, Thai, Indonesian)
- **Robust Date Extraction**: Improved date extraction from filenames with more flexible patterns
- **Better Performance**: Optimized hash calculation for large files
- **Safer File Operations**: Improved sanitization of filenames to prevent errors

Done! Enjoy your photos!!!

### Running manually with cmd

You may still need this mode if:

- You want to run on Synology where there are no ui programs required for interactive
  - You can read/discuss in [#157](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/discussions/157) for any help
- ~~Interactive unzipping crashes for you (known issue in windoza 😢 #178)~~ - disabled for now
- Want to use this in other script/automation

In that case:

1. Manually unzip all your takeout zips and merge them into one folder
2. Open cmd and:
   - For windoza:

     ```bash
     # psst: in windoza cmd, you can just drag and drop files/folders to type them in
     # 1. change working directory to where gpth.exe is:
     cd Downloads  # Most probably
     # run it, selecting input and output folders with options like this:
     # (you can try to drag and drop them)
     gpth.exe --input "Downloads\you\input\folder" --output "C:\some\other\location" --albums "shortcut"
     # select which album solution you like - see --help for all of them
     # remember to use "" !
     ```

   - For Linux/macOS:

     ```bash
     # ssh/whatever to where you're running it
     cd Downloads  # folder with gpth
     chmod +x gpth  # add execute permission
     # tell MacOS Gatekeeper to not worry
     xattr -r -d com.apple.quarantine gpth-macos
     ./gpth --input "/some/input/folder" --output "other/output/folder" --albums "shortcut"
     # select which album solution you like - see --help for all of them
     ```

You can check all cmd flags by running `gpth --help` - for example, the `--divide-to-dates` flag

## If I helped you, you can consider donating me ☕

I spent **a lot of** time fixing bugs and making this work stable 💖 - would be super thankful for any donations 🥰

[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg?logo=paypal&style=for-the-badge)](https://www.paypal.me/TheLastGimbus)
[![Donate using ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A6HO71P)
[![Donate using Liberapay](https://liberapay.com/assets/widgets/donate.svg)](https://liberapay.com/TheLastGimbus/donate)

## After exporting 🤔

### Be aware if you move your photos on your Android phone... ☝

(99% of the times), if you move some files in Android, their creation and modification time is reset to current.

"Simple Gallery" app usually keeps original file creation time when moving and copying (but I don't guarantee it). It's also pretty cool - check it out: <https://github.com/SimpleMobileTools/Simple-Gallery>

### What to do when you got rid of Google Photos? What are the alternatives? 🗺

- I really recommend you using [Syncthing](https://syncthing.net/) for syncing your photos and files across devices. It does so through your local Wi-Fi, so you're not dependent on any service or internet connection. It will also keep original file creation date and metadata, so it resolves Android issue that I mentioned before.

- [Immich](https://immich.app/) aims to be full blown GPhotos replacement - it's still under development, but already looks great!

- Same with [Photoprism](https://photoprism.org/), tho this one is in development longer (may be more mature)

- If you want something more centralized but also self-hosted, [Nextcloud](https://nextcloud.com) is a nice choice, but its approach to photos is still not perfect. (And you need to set up your own server)

### Other Takeout projects

I used this tool to export my notes to markdown - you can then edit them with any markdown editor you like :)

<https://github.com/vHanda/google-keep-exporter>

### Where is the Python script 🐍 ??

Yeah, the whole thing got re-written in Dart, and now it's way more stable and faster. If you still want Python for some reason, check out v2.x - in releases/tags

### TODO (Pull Requests welcome)

- [x] GPS data: from JSON to Exif - ~~Thank you @DalenW 💖~~ now implemented in the Dart version
- [x] Writing data from `.json`s back to `EXIF` data
- [x] Some way to handle albums - THANK YOU @bitsondatadev 😘 🎉 💃

## New Features

### GPS and EXIF Data

The latest version now includes support for extracting GPS data from JSON files and writing it back to EXIF metadata:

- **GPS Data Extraction**: Automatically extracts GPS coordinates from JSON files during processing
- **EXIF Writing**: New `--write-exif` flag to write JSON data (dates, GPS) to EXIF metadata

To use the EXIF writing feature:

```bash
gpth --input "/path/to/takeout" --write-exif
```

This will go through all files in the input folder and write any available date and GPS data from JSON files to the EXIF metadata of the corresponding images. This is useful if you want to preserve this information when moving to other photo management solutions.

For faster EXIF writing, you can process multiple files in parallel using the `--batch-size` option:

```bash
gpth --input "/path/to/takeout" --write-exif --batch-size 8
```

This will process 8 files simultaneously, which can significantly speed up the EXIF writing process on multi-core systems. The default batch size is 4.

The GPS data is also extracted during normal processing and can be used by other applications that read EXIF data.

### Performance Optimization

If you don't need GPS data and want faster processing, you can use the `--skip-gps` flag:

```bash
gpth --input "/path/to/takeout" --output "/path/to/output" --skip-gps
```

This will skip the GPS data extraction step, which can significantly speed up processing for large collections.

### Dry Run Mode

If you want to see what would happen without actually moving or copying any files, you can use the `--dry-run` flag:

```bash
gpth --input "/path/to/takeout" --output "/path/to/output" --dry-run
```

This will show you a summary of what would happen, including a sample of files that would be processed, without making any changes to your files.

### Enhanced GPS Extraction

The latest version includes improved GPS data extraction that can handle various formats found in Google Photos JSON files, including:

- Standard geoData format
- Nested location structures
- Google Maps style coordinates
- Various naming conventions (latitude/longitude, lat/lng, etc.)

This ensures that as much location data as possible is preserved when processing your photos.
