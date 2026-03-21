import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages in-app review prompts for loyal users.
///
/// Conditions to show the native review dialog:
/// - At least 5 days since first launch
/// - At least 3 successful logins
/// - Balance is positive (happy user)
/// - Review was not already shown
class ReviewService {
  static const _keyFirstLaunch = 'review_first_launch';
  static const _keyLoginCount = 'review_login_count';
  static const _keyReviewShown = 'review_shown';

  static final InAppReview _inAppReview = InAppReview.instance;

  /// Call on every successful login to increment counter.
  static Future<void> recordLogin() async {
    final prefs = await SharedPreferences.getInstance();

    // Set first launch date if not set
    if (!prefs.containsKey(_keyFirstLaunch)) {
      prefs.setInt(_keyFirstLaunch, DateTime.now().millisecondsSinceEpoch);
    }

    // Increment login count
    final count = (prefs.getInt(_keyLoginCount) ?? 0) + 1;
    prefs.setInt(_keyLoginCount, count);
  }

  /// Check conditions and show review dialog if appropriate.
  /// [balancePositive] — true if user's balance >= 0.
  static Future<void> tryRequestReview({bool balancePositive = true}) async {
    final prefs = await SharedPreferences.getInstance();

    // Already shown — don't annoy
    if (prefs.getBool(_keyReviewShown) == true) return;

    // Check login count >= 3
    final loginCount = prefs.getInt(_keyLoginCount) ?? 0;
    if (loginCount < 3) return;

    // Check 5+ days since first launch
    final firstLaunch = prefs.getInt(_keyFirstLaunch);
    if (firstLaunch == null) return;
    final daysSinceFirst = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(firstLaunch))
        .inDays;
    if (daysSinceFirst < 5) return;

    // Only ask happy users (positive balance)
    if (!balancePositive) return;

    // All conditions met — request review
    if (await _inAppReview.isAvailable()) {
      await _inAppReview.requestReview();
      prefs.setBool(_keyReviewShown, true);
    }
  }

  /// Open store listing directly (for "Rate app" button in profile).
  static Future<void> openStoreListing() async {
    await _inAppReview.openStoreListing(
      appStoreId: '6760686353',
    );
  }
}
