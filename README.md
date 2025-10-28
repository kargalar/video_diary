# Video Diary

Record short daily videos, rate them, add moods, and track your progress in the calendar. Developed with Flutter for Android, iOS, web (limited), and desktop targets.

## Features

- Quick video recording with front camera (Portrait/Landscape mode adjustable)
- Post-recording: Add title, rate with 1-5 stars, and select multiple moods
- Video list: Thumbnail, duration, file size; rename and delete (swipe menu)
- Player: Play/pause, timeline and duration display
- Calendar view: Shows recorded days, streak (streak), daily average rating, and mood heatmaps
- Daily reminder notification: Schedule notification at selected time (timezone support)
- Theme: Light/Dark
- Choose folder to save videos (default: video_diary under app documents)

## Quick Start

1) Install dependencies

```powershell
flutter pub get
```

2) Run the app (on connected device/emulator)

```powershell
flutter run
```

3) Release build (optional)

```powershell
flutter run --release
```

Note: VS Code has ready tasks: "Flutter pub get", "Flutter analyze", "Flutter test".

## Screens and Flow

- Diary (home page):
	- Top: Streak banner with current and best streak
	- List: Video thumbnails, duration/size and title; swipe to Rename/Delete
	- Bottom actions: Record, Calendar, Settings
- Record: Small FAB to start/stop, live duration counter; after stopping, prompt for title, rating, and mood
- Player: Full screen video, top back/title, bottom controls
- Calendar: Month view, record count badges, today's frame, streak highlights, rating stars; tap day to list + rating edit panel
- Settings: Folder selection, theme, landscape recording mode, daily reminder time

## Permissions and Platform Notes

- Android:
	- Camera and Microphone: Required for video recording
	- Notifications and (Android 13+) "exact alarm" permission: For daily reminders
	- Storage: User folder selection via SAF; videos saved in selected folder under `video_diary/`
	- Some devices may schedule approximate notifications due to "background full-time alarm" restrictions
- iOS:
	- Add Camera/Microphone/Notification permission descriptions to Info.plist (Privacy – Camera/Microphone Usage Description, Notifications)

This repo keeps platform manifests minimal; update as needed.

## Storage and Data Model

- Video files: In user's selected base directory under `video_diary/diary_YYYY-MM-DD_HH-mm-ss[_Title].mp4`
- Entry list and attributes: Stored as JSON in SharedPreferences
- Daily data (daily average rating, moods): Hive box `day_data`
- Thumbnails: Generated with `video_thumbnail` and path stored in entry

## Project Structure (summary)

- `lib/main.dart`: App entry, notification/init and portrait lock
- `lib/core/app.dart`: Theme, routes, provider config
- `lib/features/diary/...`: Diary entry list, record, player, calendar; repository and model
- `lib/features/settings/...`: Settings screen, model and repository
- `lib/services/...`: Notification, storage (folder selection/creation), camera/video services

## Common Issues

- Notifications not coming:
	- Grant system permissions after selecting time in app
	- Android 13+ requires notification permission; some devices need full-time alarm permission too
- Video file naming failure:
	- Title converted to "safe" characters; renaming may fail if file is open
- Cannot write to external folder:
	- Depends on Android version/device policy; only write to selected SAF folder; otherwise use app documents folder
- Camera orientation/squeezing:
	- "Landscape Recording" setting in Record page locks preview/recording; app returns to portrait after exit

## Development

Check code quality:

```powershell
flutter analyze
```

Run tests:

```powershell
flutter test -r compact
```

## Kullanılan Paketler (seçme)

- provider, camera, video_player, file_selector, flutter_local_notifications
- permission_handler, path_provider, shared_preferences, intl, timezone, flutter_timezone
- video_thumbnail, flutter_slidable, hive, hive_flutter

---

Sorularınız veya önerileriniz için issue açabilirsiniz.