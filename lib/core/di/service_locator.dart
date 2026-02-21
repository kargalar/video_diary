import '../../features/diary/data/day_data_repository.dart';
import '../../features/diary/data/diary_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../services/video_service.dart';

/// A simple service locator for dependency injection.
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final DiaryRepository diaryRepository;
  late final SettingsRepository settingsRepository;
  late final StorageService storageService;
  late final VideoService videoService;
  late final DayDataRepository dayDataRepository;
  late final NotificationService notificationService;

  Future<void> setup() async {
    diaryRepository = DiaryRepository();
    settingsRepository = SettingsRepository();
    storageService = StorageService();
    videoService = VideoService();
    dayDataRepository = DayDataRepository();
    notificationService = NotificationService();

    await dayDataRepository.init();
    await notificationService.init();
  }
}

final sl = ServiceLocator();
