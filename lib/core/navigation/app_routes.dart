import 'package:flutter/material.dart';
import '../../features/diary/view/diary_page.dart';
import '../../features/diary/view/player_page.dart';
import '../../features/diary/view/recording_page.dart';
import '../../features/settings/view/settings_page.dart';
import '../../features/settings/view/debug_page.dart';

/// Uygulama route tanımları
class AppRoutes {
  AppRoutes._();

  // Route isimleri
  static const String home = '/';
  static const String player = PlayerPage.route;
  static const String record = RecordingPage.route;
  static const String settings = SettingsPage.route;
  static const String debug = DebugPage.route;

  // Route map
  static Map<String, WidgetBuilder> get routes => {home: (context) => const DiaryPage()};

  // --- Custom Route Builders ---

  /// Sağdan sola açılan sayfa geçişi
  static Route<T> _slideRightToLeftRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  /// Aşağıdan yukarıya gelen sayfa geçişi
  static Route<T> _slideBottomToTopRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  /// Ortadan büyüyerek açılan sayfa geçişi
  static Route<T> _scaleFromCenterRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOut;
        var tween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
        return ScaleTransition(scale: animation.drive(tween), alignment: Alignment.center, child: child);
      },
    );
  }

  // --- onGenerateRoute ---
  static Route<dynamic>? onGenerateRoute(RouteSettings settingsRoute) {
    if (settingsRoute.name == player && settingsRoute.arguments is PlayerPageArgs) {
      final args = settingsRoute.arguments as PlayerPageArgs;
      return _slideBottomToTopRoute(PlayerPage(args: args));
    } else if (settingsRoute.name == record) {
      return _scaleFromCenterRoute(const RecordingPage());
    } else if (settingsRoute.name == settings) {
      return _slideRightToLeftRoute(const SettingsPage());
    } else if (settingsRoute.name == debug) {
      return _slideRightToLeftRoute(const DebugPage());
    }
    return null;
  }

  // --- Navigation Methods ---

  // Home sayfasına git ve geçmişi temizle
  static void goToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, home, (_) => false);
  }

  // Ayarlar sayfasına git - Sağdan Sola
  static void goToSettings(BuildContext context) {
    Navigator.push(context, _slideRightToLeftRoute(const SettingsPage()));
  }

  // Kayıt sayfasına git - Ortadan Büyüyerek
  static Future<dynamic> goToRecord(BuildContext context) {
    return Navigator.push(context, _scaleFromCenterRoute(const RecordingPage()));
  }

  // Video oynatıcıya git - Aşağıdan Yukarıya
  static void goToPlayer(BuildContext context, PlayerPageArgs args) {
    Navigator.push(context, _slideBottomToTopRoute(PlayerPage(args: args)));
  }

  // Debug sayfasına git - Sağdan Sola
  static void goToDebug(BuildContext context) {
    Navigator.push(context, _slideRightToLeftRoute(const DebugPage()));
  }

  // Geri dön
  static void goBack(BuildContext context) {
    Navigator.pop(context);
  }
}
