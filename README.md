[![PyPI](https://img.shields.io/pypi/v/google-photos-takeout-helper)](https://pypi.org/project/google-photos-takeout-helper/)
[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg?logo=paypal)](https://www.paypal.me/TheLastGimbus)

# Google Photos Takeout Helper
## What is this for?
If you ever want to move from Google Photos to other platform/solution, your fastest choice to export all photos is [Google Takeout](https://takeout.google.com/)

But when you download it, you will find yourself with hundreds of little folders with few photos and weird `.json` files inside.
What if you want to just have one folder with all photos, in chronological order? Good luck coping all of that :confused:

This script does just that - it organizes and cleans up your Takeout for you :+1:

It will take all of your photos from those tiny folders, set their `exif` and `last modified`, and other properties correctly, and put it in one big folder (or folders divided by a month)

## How to use:
0. Get all your photos in [Google Takeout](https://takeout.google.com/) (select only Google Photos)
1. `pip install -U google-photos-takeout-helper`
2. Extract all contents from your Google Takeout to one folder
3. Run `google-photos-takeout-helper -i [INPUT TAKEOUT FOLDER] -o [OUTPUT FOLDER]`

If you want your photos to be divided by a year and month, run it with `--divide-to-dates` flag.

### How to use for dummies (non-programming people):
This script is written in Python - but if you have Windows, and don't want to bother installing it, 
you can download a standalone .exe :tada:

1. Go to [releases->latest release->assets](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/releases) and
download `takeout-helper.exe`

2. Prepare your Takeout:

If your Takeout was divided into multiple `.zip`s, you will need to extract them, and move their contents into one
folder

3. Open cmd, and type:

```bash
cd C:\Folder\Where\You\Downloaded\takeout-helper
takeout-helper.exe -i [C:\INPUT\TAKEOUT\FOLDER] -o [C:\OUTPUT\FOLDER]
```
// Ps note: Don't use the "[ ]" in the command above.

### Contact/errors
If you have issues/questions, you can hit me up either by [Reddit](https://www.reddit.com/user/TheLastGimbus/), [Twitter](https://twitter.com/TheLastGimbus) Email: [google-photos-takeout-gh@niceyyyboyyy.anonaddy.com](mailto:google-photos-takeout-gh@niceyyyboyyy.anonaddy.com), or if you think your issue is common: [Issues](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues) tab

### If I helped you, you can consider donating me: [https://www.paypal.me/TheLastGimbus](https://www.paypal.me/TheLastGimbus)
I spent a lot of time fixing bugs and making standalone .exe file for Windows users :sparkling_heart: - would be
super thankful for any donations

You can also send me some Bitcoin: `3GezcSsZ6TWw1ug9Q8rK44y9goWa3vTmbk`, DOGE: `DTKFGSzPCDxZPQQtCTyUHbpRYy6n8fSpco`, or Monero: `43HorPVy1PTGVph3Qh3b6vVSfW2p3fH4ChjtiLVdLZw4Kw1vZUgCCcZSmfGCeEFq6bdeuF7zMutAcAcuuYFf8vEr6htBWTk`


### But, be aware if you move your photos on you Android phone...
Beware, that (99% of the times), if you move some files in Android, their creation and modification time is re-seted to current.

"Simple Gallery" app usually keeps original file creation time when moving and coping (but I don't guarantee it). It's also pretty cool and you can check it out: https://github.com/SimpleMobileTools/Simple-Gallery

## What to do when you got rid of Google Photos? What are the alternatives?
 - I really recommend you using [Syncthing](https://syncthing.net/) for syncing your photos and files across devices. It does so through your local WiFi, so you're not dependend on any service or internet connection. It will also keep original file creation date and metadata, so it resolves Android issue that I mentioned before.

 - If you want something more centralized but also self-hosted, [Nextcloud](https://nextcloud.com) is a nice choice, but it's approach to photos is still not perfect. (And you need to set up your own server)

 - Guys at [Photoprism](https://photoprism.org/) are working on full Google Photos alternative, with search and AI tagging etc, but it's stil work in progress. (I will edit this when they are done, but can't promise :P ) 

### Google has changed folder structure
Around december 2020, Google stopped putting photos in thousands of "yyyy-mm-dd" folders, and started putting them in tens of "Photos form yyyy" folders instead 🙄

- If you have new "year folders" (that is, few folders named like "Photos from 2012") (+albums) - use the newest
  version
  - `pip install -U google-photos-takeout-helper`
- If you have old "date folders" (that is, ton of folders named like "2012-06-23") - use version `1.2.0`
  - `pip install -U google-photos-takeout-helper==1.2.0`
Old version is... well, old, and I recommend you to just request the takeout again and run agains newest version of script :+1:

#### Other Takeout projects
I used this tool to export my notes to markdown - you can then edit them with any markdown editor you like :)

https://github.com/vHanda/google-keep-exporter

This one saves them in format ready for Evernote/ClintaNotes:

https://github.com/HardFork/KeepToText

### TODO (Pull Requests welcome):
- [ ] Videos' Exif data - probably impossible to do :confused:
- [x] Gps data: from JSON to Exif - Thank you @DalenW :sparkling_heart:
- [x] Some way to handle albums - THANK YOU @bitsondatadev :kissing_heart: :tada: :woman_dancing:
- [X] Windoza standalone `.exe` file - Thank you, _me_ :kissing_heart:
