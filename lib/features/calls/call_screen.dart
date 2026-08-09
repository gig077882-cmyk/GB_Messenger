import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/widgets.dart';

class CallScreen extends StatefulWidget {
  final String chatId;
  final String? type;
  final IncomingCall? incoming;
  final bool isGroup;

  const CallScreen({super.key, required this.chatId, this.type = 'VIDEO', this.incoming, this.isGroup = false});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final ApiService _api = ApiService.instance;
  lk.Room? _room;
  bool _joining = false;
  bool _microOn = true;
  bool _cameraOn = true;
  bool _isVideo = true;
  bool _failed = false;
  bool _answered = false;
  bool _speakerOn = false;
  String _roomId = '';
  String? _error;
  Timer? _durationTimer;
  DateTime? _callStart;
  Duration _callDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _isVideo = (widget.incoming?.type ?? widget.type) != 'AUDIO';
    _roomId = 'chat-${widget.chatId}';
    if (widget.incoming != null) {
      _roomId = widget.incoming!.callId;
    } else {
      _startCall();
    }
  }

  String get _durationText {
    final d = _callDuration;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _startDurationTimer() {
    _callStart = DateTime.now();
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration = DateTime.now().difference(_callStart!));
    });
  }

  Future<void> _startCall() async {
    final app = context.read<AppState>();
    setState(() => _joining = true);
    app.socket.emitCallInvite(widget.chatId, _isVideo ? 'VIDEO' : 'AUDIO');
    _answered = true;
    _joinRoom();
  }

  Future<void> _accept() async {
    setState(() { _answered = true; _joining = true; });
    await _joinRoom();
  }

  Future<void> _decline() async {
    if (widget.incoming != null) {
      context.read<AppState>().socket.emitCallEnd(widget.incoming!.callId);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _joinRoom() async {
    try {
      final creds = await _api.callToken(_roomId);
      final room = lk.Room();
      await room.connect(creds.serverUrl, creds.token);
      await room.localParticipant?.setMicrophoneEnabled(_microOn);
      if (_isVideo) {
        await room.localParticipant?.setCameraEnabled(_cameraOn);
      }
      _room = room;
      if (mounted) setState(() { _joining = false; _failed = false; });
      _startDurationTimer();
      room.addListener(() {
        if (mounted && room.connectionState == lk.ConnectionState.disconnected) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() { _joining = false; _failed = true; _error = e.toString(); });
      }
    }
  }

  Future<void> _toggleMicro() async {
    setState(() => _microOn = !_microOn);
    await _room?.localParticipant?.setMicrophoneEnabled(_microOn);
  }

  Future<void> _toggleCamera() async {
    setState(() => _cameraOn = !_cameraOn);
    await _room?.localParticipant?.setCameraEnabled(_cameraOn);
  }

  Future<void> _hangUp() async {
    final socket = context.read<AppState>().socket;
    if (_room != null) {
      await _room?.dispose();
    }
    if (widget.incoming == null || _answered) {
      socket.emitCallEnd(_roomId);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _speakerOn = !_speakerOn);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _room?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incoming = widget.incoming;
    final caller = incoming?.caller;
    final title = incoming != null
        ? (caller?.displayName ?? 'Р’С…РѕРґСЏС‰РёР№ Р·РІРѕРЅРѕРє')
        : 'РСЃС…РѕРґСЏС‰РёР№ Р·РІРѕРЅРѕРє';
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isVideo && _remoteVideoTrack() != null)
              lk.VideoTrackRenderer(
                _remoteVideoTrack()!,
                fit: lk.VideoViewFit.cover,
              )
            else if (widget.isGroup && _room != null)
              _remoteParticipantsGrid()
            else
              _gradientBg(title, caller),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => _hangUp(),
                      ),
                      const Spacer(),
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Text('GB Call',
                            style: TextStyle(
                                color: Colors.white38,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                      ),
                    ],
                  ),
                  if (_isVideo && _room?.localParticipant != null)
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _localVideo(),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (!_failed)
                    Column(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (!_joining && _callDuration.inSeconds > 0)
                          Text(_durationText,
                              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
                        if (_joining)
                          const Text('Соединение…',
                              style: TextStyle(color: Colors.white54, fontSize: 15)),
                        if (!_joining && _callDuration.inSeconds == 0 && incoming == null)
                          const Text('Вызов…',
                              style: TextStyle(color: Colors.white54, fontSize: 15)),
                        if (!_joining && incoming != null && _callDuration.inSeconds == 0)
                          const Text('Входящий вызов',
                              style: TextStyle(color: Colors.white54, fontSize: 15)),
                      ],
                    )
                  else ...[
                    const Text('РќРµ СѓРґР°Р»РѕСЃСЊ СѓСЃС‚Р°РЅРѕРІРёС‚СЊ СЃРІСЏР·СЊ',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'LiveKit-SFU РЅРµРґРѕСЃС‚СѓРїРµРЅ: $_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (incoming != null && !_answered)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CircleBtn(
                          icon: Icons.call_end_rounded,
                          color: const Color(0xFFFF4D4D),
                          onTap: _decline,
                        ),
                        const SizedBox(width: 60),
                        _CircleBtn(
                          icon: Icons.call_rounded,
                          color: const Color(0xFF2ECC71),
                          onTap: _accept,
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CircleBtn(
                          icon: _microOn ? Icons.mic : Icons.mic_off,
                          color: _microOn ? const Color(0xFF1E1E1E) : Colors.white24,
                          onTap: _toggleMicro,
                        ),
                        const SizedBox(width: 20),
                        _CircleBtn(
                          icon: _speakerOn ? Icons.volume_up : Icons.hearing,
                          color: _speakerOn ? const Color(0xFF1E1E1E) : Colors.white24,
                          onTap: _toggleSpeaker,
                        ),
                        const SizedBox(width: 20),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: glow(blur: 30),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4D4D),
                              padding: const EdgeInsets.all(22),
                            ),
                            onPressed: _hangUp,
                          ),
                        ),
                        const SizedBox(width: 20),
                        _CircleBtn(
                          icon: _isVideo ? Icons.videocam : Icons.videocam_off,
                          color: _isVideo ? const Color(0xFF1E1E1E) : Colors.white24,
                          onTap: _isVideo ? _toggleCamera : null,
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  lk.VideoTrack? _remoteVideoTrack() {
    if (_room == null) return null;
    for (final p in _room!.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        final t = pub.track;
        if (t is lk.VideoTrack) return t;
      }
    }
    return null;
  }

  Widget _remoteParticipantsGrid() {
    final participants = _room?.remoteParticipants.values.toList() ?? [];
    if (participants.isEmpty) return _gradientBg('Group Call', null);
    final count = participants.length;
    int crossAxisCount = count <= 1 ? 1 : (count <= 4 ? 2 : 3);
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: count == 1 ? 16 / 9 : 1,
      ),
      itemCount: count,
      itemBuilder: (_, i) {
        final p = participants[i];
        final videoTrack = p.videoTrackPublications.isNotEmpty
            ? p.videoTrackPublications.first.track
            : null;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: const Color(0xFF1A1A1A),
            child: videoTrack is lk.VideoTrack
                ? lk.VideoTrackRenderer(videoTrack as lk.VideoTrack, fit: lk.VideoViewFit.cover)
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, color: Colors.white38, size: 32),
                        const SizedBox(height: 4),
                        Text(p.identity, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _localVideo() {
    final p = _room?.localParticipant;
    if (p == null) return const SizedBox.shrink();
    for (final pub in p.videoTrackPublications) {
      final t = pub.track;
      if (t is lk.LocalVideoTrack) {
        return SizedBox(
          width: 110,
          height: 160,
          child: lk.VideoTrackRenderer(t, fit: lk.VideoViewFit.cover),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _gradientBg(String title, GbUser? caller) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.1,
          colors: [const Color(0xFF1E1E1E), const Color(0xFF0A0A0A), Colors.black],
        ),
      ),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GBTheme.whatsAppGreen.withValues(alpha: 0.5), width: 2),
            boxShadow: glow(blur: 40),
          ),
          padding: const EdgeInsets.all(6),
          child: GBAvatar(url: caller?.avatarUrl, name: title, size: 110),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _CircleBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, color: Colors.white, size: 26),
        style: IconButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.all(18),
        ),
        onPressed: onTap,
      );
}
