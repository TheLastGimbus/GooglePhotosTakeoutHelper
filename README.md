# Google Photos Takeout Helper
#### Python scripts that helps you export your photos from Google Photos to one, nice folder

## How to use:
1. Clone/download this repo
2. `pip install requirements.txt`
3. Cut out/remove all "album folders" that aren't named "2016-06-16" or something like that
4. Run:

`python takeout_helper.py -i [INPUT TAKEOUT FOLDER] -o [OUTPUT FOLDER]`

Input takeout folder is your folder with all stuff you got in all .zip's.

If, instead of one big folder, you want your photos to be divided by year and month, run it with `--divide-to-dates` flag.



### Why do you need to cut out albums?
They mostly contain duplicates of same photos that are in corresponding "date folder"
This script tries to get all "photo taken time" stuff right. If it finds json - it sets everything from that json (it contains data of edited timestamp that you might've corrected in Google Photos). If it can't - it tries to get Exif data form photo.
IF it can't find anything like that, it sets date from folder name.

All of this is so that you can then safely store ALL of your photos in one folder, and they will all be in right order.

#### Unless you move them around your Android phone. 
Beware, that (99% of the times), if you move some files in Android, their creation and modification time is reseted to current.

"Simple Gallery" app usually keeps original file creation time when moving and coping (but I don't guarantee it). It's also pretty cool and you can check it out:

https://github.com/SimpleMobileTools/Simple-Gallery

## What to do when you got rid of Google Photos? What are the alternatives?
 - I really recommend you using [Syncthing](https://syncthing.net/) for syncing your photos and files across devices. It does so through your local WiFi, so you're not dependend on any service or internet connection. It will also keep original file creation date and metadata, so it resolves Android issue that I mentioned before.

 - If you want something more centralized but also self-hosted, [Nextcloud](https://nextcloud.com) is a nice choice, but it's approach to photos is still not perfect. (And you need to set up your own server)

 - Guys at [Photoprims](https://photoprism.org/) are working on full Google Photos alternative, with search and AI tagging etc, but it's stil work in progress. (I will edit this when they are done, but can't promise :P ) 




### TODO:
- [ ] Videos' Exif data
- [ ] Gps data: from JSON to Exif
- [ ] Some way to handle albums
