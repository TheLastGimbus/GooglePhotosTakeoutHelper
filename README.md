[![AUR](https://img.shields.io/aur/version/gpth-bin)](https://aur.archlinux.org/packages/gpth-bin)
[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg?logo=paypal)](https://www.paypal.me/TheLastGimbus)

# Google Photos Takeout Helper
## What is this for?
If you ever want to move from Google Photos to other platform/solution, your fastest choice to export all photos is [Google Takeout](https://takeout.google.com/)

But when you download it, you will find yourself with hundreds of little folders with few photos and weird `.json` files inside.
What if you want to just have one folder with all photos, in chronological order? Good luck copying all of that 😕

This script does just that - it organizes and cleans up your Takeout for you 👍

It will take all of your photos from those tiny folders, set their and `file last modified` correctly, and put it in one big folder (or folders divided by a month) ❤

## How to use:
0. Get all your photos in [Google Takeout](https://takeout.google.com/)
    - "deselect all" and then select only Google Photos
    - deselect all "album folders" - folders with name of some album, and select *only* "year folders" - folders named like "`Photos from 20..`" - don't worry, all of your photos are in "year folders anyway".
1. Download the script from [releases tab](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/releases)
    - [also available on AUR 😏](https://aur.archlinux.org/packages/gpth-bin)
2. Merge all contents from all Google Takeout zips to *one folder*
3. Run `gpth -i "your/input/folder" -o "your/output/folder"`

If you want your photos to be divided by a year and month, run it with the `--divide-to-dates` flag.

### How to use for dummies (non-programming people):
1. Go to [releases->latest release->assets](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/releases) and
download `gpth-vX.X.X-windoza.exe`
2. Prepare your Takeout:
    If your Takeout was divided into multiple `.zip`s, you will need to extract them, and move their contents into **one folder**
3. Open `cmd`, and type:
    ```bash
    cd C:\Folder\Where\You\Downloaded\takeout-helper
    gpth-vX.X.X-windoza.exe -i "C:\INPUT\TAKEOUT\FOLDER" -o "C:\OUTPUT\FOLDER"
    ```
    **// PS 2: YOU NEED TO WRAP YOUR PATHS IN - `"` - ESPECIALLY IF THEY HAVE SPACES**

## Contact/errors
If you have issues/questions, you can hit me up either by [Reddit](https://www.reddit.com/user/TheLastGimbus/), [Twitter](https://twitter.com/TheLastGimbus) Email: [google-photos-takeout-gh@niceyyyboyyy.anonaddy.com](mailto:google-photos-takeout-gh@niceyyyboyyy.anonaddy.com), or if you think your issue is common: [Issues](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues) tab

## If I helped you, you can consider donating me: [https://www.paypal.me/TheLastGimbus](https://www.paypal.me/TheLastGimbus)
I spent a lot of time fixing bugs and making this work stable 💖 - would be super thankful for any donations

## After exporting
### Be aware if you move your photos on your Android phone...
(99% of the times), if you move some files in Android, their creation and modification time is reset to current.

"Simple Gallery" app usually keeps original file creation time when moving and coping (but I don't guarantee it). It's also pretty cool - check it out: https://github.com/SimpleMobileTools/Simple-Gallery

### What to do when you got rid of Google Photos? What are the alternatives?
 - I really recommend you using [Syncthing](https://syncthing.net/) for syncing your photos and files across devices. It does so through your local Wi-Fi, so you're not dependent on any service or internet connection. It will also keep original file creation date and metadata, so it resolves Android issue that I mentioned before.

 - If you want something more centralized but also self-hosted, [Nextcloud](https://nextcloud.com) is a nice choice, but its approach to photos is still not perfect. (And you need to set up your own server)

 - Guys at [Photoprism](https://photoprism.org/) are working on full Google Photos alternative, with search and AI tagging etc, but it's stil work in progress

### Other Takeout projects
I used this tool to export my notes to markdown - you can then edit them with any markdown editor you like :)

https://github.com/vHanda/google-keep-exporter

### Where is the Python script??
Yeah, the whole thing got re-written in Dart, and now it's way more stable and faster. If you still want Python for some reason, check out v2.x - in releases/tags

### TODO (Pull Requests welcome):
- [ ] GPS data: from JSON to Exif - ~~Thank you @DalenW 💖~~ still thank you, but it is now missing in the Dart version
- [ ] Writing data from `.json`s back to `EXIF` data
- [x] Some way to handle albums - THANK YOU @bitsondatadev 😘 🎉 💃
