import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';

/// Запись и воспроизведение голосовых сообщений.
class VoiceRecorder {
  static final VoiceRecorder instance = VoiceRecorder._();
  VoiceRecorder._();

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;
  DateTime? _startTime;

  bool get isRecording => _currentPath != null;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<Amplitude> getAmplitude() async {
    try {
      return await _recorder.getAmplitude();
    } catch (_) {
      return Amplitude(current: 0.0, max: 0.0);
    }
  }

  Future<void> start() async {
    if (!await hasPermission()) return;
    final dir = await getTemporaryDirectory();
    _currentPath = p.join(
      dir.path,
      'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    _startTime = DateTime.now();
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100),
        path: _currentPath!,
      );
    } catch (_) {
      _currentPath = null;
      _startTime = null;
      rethrow;
    }
  }

  Future<VoiceResult?> stop() async {
    final path = await _recorder.stop();
    if (path == null || _startTime == null) return null;
    final duration = DateTime.now().difference(_startTime!);
    _currentPath = null;
    _startTime = null;
    final file = File(path);
    final size = await file.length();
    return VoiceResult(
      path: path,
      durationMs: duration.inMilliseconds,
      size: size,
    );
  }

  Future<void> cancel() async {
    if (_currentPath != null) {
      await _recorder.stop();
      await deleteFile(_currentPath!);
    }
    _currentPath = null;
    _startTime = null;
  }

  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void dispose() => _recorder.dispose();
}

class VoiceResult {
  final String path;
  final int durationMs;
  final int size;
  VoiceResult({
    required this.path,
    required this.durationMs,
    required this.size,
  });
}

/// Плеер для воспроизведения голосовых сообщений.
class VoicePlayer {
  static final VoicePlayer instance = VoicePlayer._();
  VoicePlayer._();

  final AudioPlayer _player = AudioPlayer();
  String? _currentSource;
  final _onCompleteController = StreamController<String>.broadcast();
  final _onPositionController = StreamController<PlayerStateData>.broadcast();
  Stream<String> get onComplete => _onCompleteController.stream;
  Stream<PlayerStateData> get onStateChange => _onPositionController.stream;

  Future<void> play(String url) async {
    if (_currentSource == url && _player.state == PlayerState.playing) {
      await _player.pause();
      _onPositionController.add(PlayerStateData(url: url, isPlaying: false));
      return;
    }
    if (_currentSource == url && _player.state == PlayerState.paused) {
      await _player.resume();
      _onPositionController.add(PlayerStateData(url: url, isPlaying: true));
      return;
    }
    await stop();
    _currentSource = url;
    final source = url.startsWith('http')
        ? UrlSource(url)
        : DeviceFileSource(url);
    await _player.play(source);
    _onPositionController.add(PlayerStateData(url: url, isPlaying: true));
  }

  Future<void> pause() async {
    await _player.pause();
    _onPositionController.add(
      PlayerStateData(url: _currentSource ?? '', isPlaying: false),
    );
  }

  Future<void> stop() async {
    await _player.stop();
    _currentSource = null;
    _onPositionController.add(PlayerStateData(url: '', isPlaying: false));
  }

  void dispose() {
    _onCompleteController.close();
    _onPositionController.close();
    _player.dispose();
  }
}

class PlayerStateData {
  final String url;
  final bool isPlaying;
  final Duration? position;
  final Duration? duration;
  PlayerStateData({
    required this.url,
    required this.isPlaying,
    this.position,
    this.duration,
  });
}
