import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/diary/view/diary_page.dart';
import '../features/diary/viewmodel/diary_view_model.dart';
import '../features/settings/view/settings_page.dart';
import '../features/diary/view/recording_page.dart';
import '../features/diary/view/player_page.dart';
import '../features/diary/view/calendar_page.dart';
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
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          themeMode: settings.state.darkMode ? ThemeMode.dark : ThemeMode.light,
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
            } else if (settingsRoute.name == CalendarPage.route) {
              return PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const CalendarPage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
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
