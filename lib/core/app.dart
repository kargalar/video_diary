import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/diary/view/diary_page.dart';
import '../features/diary/viewmodel/diary_view_model.dart';
import '../features/settings/view/settings_page.dart';
import '../features/diary/view/recording_page.dart';
import '../features/diary/view/player_page.dart';
import '../features/settings/viewmodel/settings_view_model.dart';
import '../features/diary/data/day_data_repository.dart';

class VideoDiaryApp extends StatelessWidget {
  const VideoDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure Hive ready for day data
    DayDataRepository().init();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsViewModel()..load()),
        ChangeNotifierProvider(create: (_) => DiaryViewModel()),
      ],
      child: Consumer<SettingsViewModel>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Video Diary',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C2C2C), brightness: Brightness.light, primary: const Color(0xFF2C2C2C), secondary: const Color(0xFF5C5C5C), surface: Colors.white, surfaceContainerHighest: const Color(0xFFF5F5F5)),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true, backgroundColor: Colors.white, foregroundColor: Color(0xFF2C2C2C)),
            dividerColor: const Color(0xFFE0E0E0),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF2C2C2C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
            iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: const Color(0xFF5C5C5C))),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C2C2C), brightness: Brightness.dark, primary: const Color(0xFFE0E0E0), secondary: const Color(0xFFB0B0B0), surface: const Color(0xFF1A1A1A), surfaceContainerHighest: const Color(0xFF2C2C2C)),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF1A1A1A),
            appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true, backgroundColor: Color(0xFF1A1A1A), foregroundColor: Color(0xFFE0E0E0)),
            dividerColor: const Color(0xFF3C3C3C),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF3C3C3C), width: 1),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
            iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: const Color(0xFFE0E0E0))),
          ),
          themeMode: ThemeMode.dark,
          routes: {'/': (_) => const DiaryPage()},
          onGenerateRoute: (settingsRoute) {
            if (settingsRoute.name == PlayerPage.route && settingsRoute.arguments is PlayerPageArgs) {
              final args = settingsRoute.arguments as PlayerPageArgs;
              return PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => PlayerPage(args: args),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  return SlideTransition(position: offsetAnimation, child: child);
                },
              );
            } else if (settingsRoute.name == RecordingPage.route) {
              return PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const RecordingPage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, -1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  return SlideTransition(position: offsetAnimation, child: child);
                },
              );
            } else if (settingsRoute.name == SettingsPage.route) {
              return PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const SettingsPage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(-1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  return SlideTransition(position: offsetAnimation, child: child);
                },
              );
            }
            return null;
          },
        ),
      ),
    );
  }
}
