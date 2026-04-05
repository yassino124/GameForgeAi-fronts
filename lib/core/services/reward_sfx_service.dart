import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RewardSfxService {
  static const String _kPrefRewardSfxEnabled = 'reward_sfx_enabled';

  static Future<void> _playPattern(List<Duration> delays, {SystemSoundType sound = SystemSoundType.click}) async {
    try {
      final enabled = await isEnabled();
      if (!enabled) return;
      for (final d in delays) {
        if (d.inMilliseconds > 0) {
          await Future<void>.delayed(d);
        }
        await SystemSound.play(sound);
      }
    } catch (_) {}
  }

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kPrefRewardSfxEnabled) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPrefRewardSfxEnabled, enabled);
  }

  static Future<void> playWin() async {
    await _playPattern([
      Duration.zero,
      const Duration(milliseconds: 80),
    ]);
  }

  static Future<void> playCoins() async {
    await _playPattern([
      Duration.zero,
      const Duration(milliseconds: 45),
      const Duration(milliseconds: 45),
    ]);
  }

  static Future<void> playRareWin() async {
    await _playPattern([
      Duration.zero,
      const Duration(milliseconds: 60),
      const Duration(milliseconds: 120),
      const Duration(milliseconds: 60),
    ]);
  }

  static Future<void> playOpenBox() async {
    await _playPattern([
      Duration.zero,
      const Duration(milliseconds: 90),
      const Duration(milliseconds: 160),
    ]);
  }
}
