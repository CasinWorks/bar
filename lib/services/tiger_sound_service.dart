import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global Blind Tiger SFX — on by default, shared across welcome + lounge.
class TigerSoundService {
  TigerSoundService._();
  static final TigerSoundService instance = TigerSoundService._();

  static const prefsKey = 'welcome_sound_enabled';

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;
  bool _loaded = false;

  bool get enabled => _enabled;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(prefsKey) ?? true;
    _loaded = true;
    try {
      await _player.setVolume(0.55);
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
  }

  Future<void> setEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, on);
    _enabled = on;
    _loaded = true;
    if (on) await playKnock();
  }

  Future<void> playKnock() =>
      _play('sounds/velvet_knock.wav', HapticFeedback.mediumImpact);
  Future<void> playDoorLatch() =>
      _play('sounds/door_latch.wav', HapticFeedback.heavyImpact);
  Future<void> playCheckoutChime() =>
      _play('sounds/checkout_chime.wav', HapticFeedback.mediumImpact);
  Future<void> playTimePour() =>
      _play('sounds/time_pour.wav', HapticFeedback.heavyImpact);
  Future<void> playGlassClink() =>
      _play('sounds/glass_clink.wav', HapticFeedback.lightImpact);
  Future<void> playSoftThud() =>
      _play('sounds/soft_thud.wav', HapticFeedback.heavyImpact);
  Future<void> playTimerLow() =>
      _play('sounds/timer_low.wav', HapticFeedback.selectionClick);

  Future<void> _play(String asset, Future<void> Function() haptic) async {
    await ensureLoaded();
    try {
      await haptic();
    } catch (_) {}
    if (!_enabled || kIsWeb) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
