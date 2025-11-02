import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Video çekimleri sonrası kullanıcıdan değerlendirme isteyen servis
/// Kullanıcı uygulamayı değerlendirmediyse her 2 video çekiminde bir değerlendirme ister
class VideoReviewService {
  static const String _videoCountKey = 'recorded_video_count';
  static const String _reviewCompletedKey = 'review_completed';

  // Her kaç video çekiminde bir review isteneceği
  static const int _reviewRequestInterval = 2;

  final InAppReview _inAppReview = InAppReview.instance;

  /// Video çekim sayısını artırır ve gerekirse review dialog'unu gösterir
  Future<void> incrementVideoCountAndRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Kullanıcı review'u tamamladı mı kontrol et
      final reviewCompleted = prefs.getBool(_reviewCompletedKey) ?? false;

      if (reviewCompleted) {
        // Review tamamlandı, sadece sayacı artır
        final currentCount = prefs.getInt(_videoCountKey) ?? 0;
        await prefs.setInt(_videoCountKey, currentCount + 1);
        return;
      }

      // Mevcut video sayısını al
      final currentCount = prefs.getInt(_videoCountKey) ?? 0;
      final newCount = currentCount + 1;

      // Yeni sayıyı kaydet
      await prefs.setInt(_videoCountKey, newCount);

      // Her 2 video çekiminde review sor
      if (newCount % _reviewRequestInterval == 0) {
        await _requestReview();
      }
    } catch (e) {
      // Hata durumunda sessizce devam et
      debugPrint('VideoReviewService: Video sayısı güncellenirken hata: $e');
    }
  }

  /// Review dialog'unu gösterir
  Future<void> _requestReview() async {
    try {
      // Review özelliği cihazda mevcut mu kontrol et
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      }
    } catch (e) {
      debugPrint('VideoReviewService: Review isteği sırasında hata: $e');
    }
  }

  /// Video sayısını ve review durumunu sıfırlar (test amaçlı)
  Future<void> resetVideoCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_videoCountKey);
      await prefs.remove(_reviewCompletedKey);
    } catch (e) {
      debugPrint('VideoReviewService: Sıfırlama hatası: $e');
    }
  }

  /// Mevcut video çekim sayısını getirir
  Future<int> getVideoCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_videoCountKey) ?? 0;
    } catch (e) {
      debugPrint('VideoReviewService: Video sayısı alınırken hata: $e');
      return 0;
    }
  }

  /// Review'un tamamlanıp tamamlanmadığını kontrol eder
  Future<bool> isReviewCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_reviewCompletedKey) ?? false;
    } catch (e) {
      debugPrint('VideoReviewService: Review tamamlanma durumu kontrol edilirken hata: $e');
      return false;
    }
  }

  /// Kullanıcının review'u tamamladığını işaretle
  /// Bu metod kullanıcı store'da review bıraktıktan sonra manuel olarak çağrılabilir
  Future<void> markReviewAsCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reviewCompletedKey, true);
    } catch (e) {
      debugPrint('VideoReviewService: Review tamamlanma durumu kaydedilirken hata: $e');
    }
  }
}
