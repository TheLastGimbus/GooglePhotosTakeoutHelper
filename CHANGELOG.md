## 3.3.2

- Bump SDK and dependencies

## 3.3.1

### Fix bugs introduced in `v3.3.0` 🤓

- #147 Support `.tgz` files too
- #145 **DON'T** use ram memory equal to zip file thanks to `asyncWrite: true` flag 🙃
- #143 don't crash when encoding is other than `utf8` 🍰
- #136 #144 - On windzoa, set time to 1970 if it's before that - would love to *actually* fix this, but Dart doesn't let me :/

## 3.3.0

- Fix #143 - issues when encoding is not utf8 - sadly, others are still not supported, just skipped
- Ask for divide-to-folders in interactive
- Close #138 - support Archive/Trash folders!

  Implementation of this is a bit complicated, so may break, but should work 99% times
- Fix #134 - nicely tell user what to do when no "year folders" instead of exceptions
- Fix #92 - Much better json finding!
  
  It now should find all of those `...-edited(1).jpg.json` - this also makes it faster because it rarely falls back to reading exif, which is slower
- More small fixes and refactors

### Enjoy even faster and more stable `gpth` everyone 🥳🥳🥳

## 3.2.0

- Brand new ✨interactive mode✨ - just double click 🤘
  - `gpth` now uses 💅discontinued💅 [`file_picker_desktop`](https://pub.dev/packages/file_picker_desktop) to launch pickers for user to select output folder and input...
  - ...zips 🤐! because it also decompresses the takeouts for you! (People had ton of trouble of how to join them etc - no worries anymore!)
- Donation link

## 3.1.1

- Code sign windoza exe with self-made cert

## 3.1.0

- Added `--divide-to-dates` 🎉

## 3.0.0

- Dart!
- Speed
- Consistency - it is well known what script does, what does it copy and what not
- Stable album detection (tho still don't know what to do with it)
- [Testing!](https://youtu.be/UGSgpvjHp9o?t=292)
- Better json matching
- `--guess-from-name` is now a default
- `--skip-extras-harder` is missing for now
- `--divide-to-dates` is missing for now
- End-to-end tests are gone, but they're not as required since we have a lod of Units instead 👍
