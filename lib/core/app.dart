import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/diary/view/diary_page.dart';
import '../features/diary/viewmodel/diary_view_model.dart';
import '../features/settings/view/settings_page.dart';
import '../features/settings/viewmodel/settings_view_model.dart';

class VideoDiaryApp extends StatelessWidget {
  const VideoDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsViewModel()..load()),
        ChangeNotifierProvider(create: (_) => DiaryViewModel()),
      ],
      child: MaterialApp(
        title: 'Video Diary',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
        routes: {'/': (_) => const DiaryPage(), SettingsPage.route: (_) => const SettingsPage()},
      ),
    );
  }
}
