![PyPI](https://img.shields.io/pypi/v/google-photos-takeout-helper)
[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg?logo=paypal)](https://www.paypal.me/TheLastGimbus)

# Google Photos Takeout Helper
## What is this for?
If you ever want to move from Google Photos to other platform/solution, your fastest choice to export all photos is [Google Takeout](https://takeout.google.com/)

But when you download it, you will find yourself with hundreds of little folders with few photos and weird `.json` files inside.
What if you want to just have one folder with all photos, in chronological order? Good luck coping all of that :confused:

This script does just that - it organizes and cleans up your Takeout for you :+1:

It will take all of your photos from those tiny folders, set their `exif` and `last modified`, and other properties correctly, and put it in one big folder (or folders divided by a month)

# BIG DISCLAIMER - GOOGLE RECENTLY CHANGED FOLDER STRUCTURE

- If you have new "year folders" (that is, few folders named like "Photos from 2012") (+albums) - use the newest
  version
  - `pip install -U google-photos-takeout-helper`
- If you have old "date folders" (that is, ton of folders named like "2012-06-23") - use version `1.2.0`
  - `pip install -U google-photos-takeout-helper==1.2.0`

I don't know if new version fully works, so let me know if it doesn't :+1:

## How to use:
0. Get all your photos in [Google Takeout](https://takeout.google.com/) (select only Google Photos)
1. `pip install -U google-photos-takeout-helper`
2. Extract all contents from your Google Takeout to one folder
3. Run `google-photos-takeout-helper -i [INPUT TAKEOUT FOLDER] -o [OUTPUT FOLDER]`

Alternatively, if you don't have PATH set right, you can call it `python3 -m google_photos_takeout_helper`

If, instead of one big folder, you want your photos to be divided by a year and month, run it with `--divide-to-dates` flag.

### How to use for dummies (non-programming people):
<details><summary>Click for detailed instructions</summary>
<p>
This script is written in Python. You need to install Python interpreter before you use it - don't worry, it's easy :wink: Then, everything with Python will be done through terminal/cmd

1. Download and install Python for your system: https://www.python.org/downloads/ (Google step-by-step installation
   instructions if you have trouble) - if the installer will ask you about some `PATH` and `pip`, make sure to check
   that too

Now, you need to install my script with `pip` - a builtin tool that can install other Python programs and scripts. You
can run it either by typing `pip <options>` or `python3 -m pip <options>`:

2. `pip install -U google-photos-takeout-helper`

// Or `python3 -m pip install -U google-photos-takeout-helper`

// Watch out for versions, described in "BIG DISCLAIMER" above

If something goes wrong, and it prints some red errors, try to add ` --user` flag at the end

3. Prepare your Takeout:

If your Takeout was divided into multiple `.zip`s, you will need to extract them, and move their contents into one
folder. Now, you should be able to just run it straight in cmd/terminal:

4. `google-photos-takeout-helper -i [INPUT TAKEOUT FOLDER] -o [OUTPUT FOLDER]`

// Or if this doesn't work: `python3 -m google_photos_takeout_helper -i [INPUT TAKEOUT FOLDER] -o [OUTPUT FOLDER]`

// Ps note: Don't use the "[ ]" in the command above.

If you want your photos to be divided by a year and month, run it with `--divide-to-dates` flag.

If you have issues/questions, you can hit me up either by [Reddit](https://www.reddit.com/user/TheLastGimbus/), [Twitter](https://twitter.com/TheLastGimbus) Email: [google-photos-takeout-gh@niceyyyboyyy.anonaddy.com](mailto:google-photos-takeout-gh@niceyyyboyyy.anonaddy.com), or if you think your issue is common: [Issues](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues) tab

</p>
</details>

### If I helped you, you can consider donating me: [https://www.paypal.me/TheLastGimbus](https://www.paypal.me/TheLastGimbus)
Thanks :sparkling_heart:

##### But, be aware if you move your photos on you Android phone...
Beware, that (99% of the times), if you move some files in Android, their creation and modification time is re-seted to current.

"Simple Gallery" app usually keeps original file creation time when moving and coping (but I don't guarantee it). It's also pretty cool and you can check it out:

https://github.com/SimpleMobileTools/Simple-Gallery

## What to do when you got rid of Google Photos? What are the alternatives?
 - I really recommend you using [Syncthing](https://syncthing.net/) for syncing your photos and files across devices. It does so through your local WiFi, so you're not dependend on any service or internet connection. It will also keep original file creation date and metadata, so it resolves Android issue that I mentioned before.

 - If you want something more centralized but also self-hosted, [Nextcloud](https://nextcloud.com) is a nice choice, but it's approach to photos is still not perfect. (And you need to set up your own server)

 - Guys at [Photoprism](https://photoprism.org/) are working on full Google Photos alternative, with search and AI tagging etc, but it's stil work in progress. (I will edit this when they are done, but can't promise :P ) 


#### Other Takeout projects
I used this tool to export my notes to markdown - you can then edit them with any markdown editor you like :)

https://github.com/vHanda/google-keep-exporter


This one saves them in format ready for Evernote/ClintaNotes:

https://github.com/HardFork/KeepToText


### TODO (Pull Requests welcome):
- [ ] Videos' Exif data
- [x] Gps data: from JSON to Exif - Thank you @DalenW :sparkling_heart:
- [x] Some way to handle albums - THANK YOU @bitsondatadev :kissing_heart: :tada: :woman_dancing: 
