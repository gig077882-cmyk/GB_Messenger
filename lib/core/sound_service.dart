import 'package:audioplayers/audioplayers.dart';

/// Звуковые эффекты приложения.
class SoundService {
  static final SoundService instance = SoundService._();
  SoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool enabled = true;

  Future<void> playSend() async {
    if (!enabled) return;
    // System sound for message sent
    await _player.play(AssetSource('sounds/send.mp3'));
  }

  Future<void> playReceive() async {
    if (!enabled) return;
    await _player.play(AssetSource('sounds/receive.mp3'));
  }

  Future<void> playCall() async {
    if (!enabled) return;
    await _player.play(AssetSource('sounds/call.mp3'));
  }

  Future<void> playNotification() async {
    if (!enabled) return;
    await _player.play(AssetSource('sounds/notification.mp3'));
  }

  void dispose() => _player.dispose();
}
