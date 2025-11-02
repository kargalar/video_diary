# Video Diary

A Flutter app to record short daily videos, rate them, add moods, and track your progress in a calendar.


## Download
[![Google Play Store](https://img.shields.io/badge/Google%20Play-Download-brightgreen?logo=google-play)](https://play.google.com/store/apps/details?id=app.videodiary)

## Features

- Record videos with front camera
- Rate videos (1-5 stars) and add mood tags
- Browse video list with thumbnails
- Calendar view with streaks and statistics
- Daily reminder notifications
- Light/Dark theme
- Cross-platform: Android, iOS, Web, Desktop

## Quick Start

```powershell
flutter pub get
flutter run
```

## Project Structure

- `lib/main.dart` – App entry point
- `lib/core/` – Theme and routing
- `lib/features/diary/` – Video diary features (record, player, calendar)
- `lib/features/settings/` – Settings screen
- `lib/services/` – Camera, storage, notifications

## Download

[Google Play](https://play.google.com/store/apps/details?id=com.videodiary)

## Dependencies

provider, camera, video_player, file_selector, flutter_local_notifications, permission_handler, path_provider, shared_preferences, hive, video_thumbnail, and more