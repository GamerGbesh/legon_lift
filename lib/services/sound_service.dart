// Owner: WS3. Short gym sounds that duck music instead of stopping it (SPEC 4.1 rule 8, 11.6).
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api.dart';

/// [SoundService] playing `assets/sounds/*.ogg` with transient, ducking audio focus.
///
/// Uses the media-player mode (the low-latency SoundPool mode does not request audio focus, so
/// it could not duck the user's music). Players are created on first use and reused.
class AudioSoundService implements SoundService {
  AudioSoundService();

  static const String beepAsset = 'sounds/beep_short.ogg';
  static const String restDoneAsset = 'sounds/rest_done.ogg';

  /// Transient focus that lets other audio keep playing at a lower volume (SPEC 11.6).
  static final AudioContext duckingContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      // Alarm usage: plays on the alarm volume, so it is heard with the phone on vibrate/silent
      // (sonification is muted then, and the timer ring went unheard in the gym).
      usageType: AndroidUsageType.alarm,
      contentType: AndroidContentType.sonification,
    ),
  );

  AudioPlayer? _beep;
  AudioPlayer? _restDone;

  @override
  Future<void> beep() async => _beep = await _play(_beep, beepAsset);

  @override
  Future<void> restDone() async => _restDone = await _play(_restDone, restDoneAsset);

  Future<AudioPlayer?> _play(AudioPlayer? existing, String asset) async {
    try {
      final player = existing ?? AudioPlayer();
      if (existing == null) {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setAudioContext(duckingContext);
      } else {
        await player.stop();
      }
      await player.play(AssetSource(asset));
      return player;
    } on PlatformException catch (e) {
      debugPrint('Sound failed: ${e.code} ${e.message}');
    } on MissingPluginException {
      // Not on a device.
    } on AudioPlayerException catch (e) {
      debugPrint('Sound failed: $e');
    }
    return existing;
  }
}
