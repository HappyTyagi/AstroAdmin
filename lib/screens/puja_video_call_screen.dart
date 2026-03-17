import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../services/agora_video_call_service.dart';
import '../theme/app_theme.dart';

class PujaVideoCallScreen extends StatefulWidget {
  final String appId;
  final String token;
  final String channelName;
  final int uid;
  final String callType; // 'audio' | 'video'

  const PujaVideoCallScreen({
    super.key,
    required this.appId,
    required this.token,
    required this.channelName,
    required this.uid,
    this.callType = 'video',
  });

  @override
  State<PujaVideoCallScreen> createState() => _PujaVideoCallScreenState();
}

class _PujaVideoCallScreenState extends State<PujaVideoCallScreen> {
  late final AgoraVideoCallService _agora;
  bool _loading = true;
  String? _error;
  int _remoteUid = 0;

  bool _micOn = true;
  bool _cameraOn = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      _agora = AgoraVideoCallService(
        agoraAppId: widget.appId,
        agoraToken: widget.token,
        channelName: widget.channelName,
      );

      final permissionsOk = widget.callType == 'audio'
          ? await _agora.requestAudioPermission()
          : await _agora.requestVideoPermissions();
      if (!permissionsOk) {
        if (!mounted) return;
        setState(() {
          _error = 'Microphone/Camera permission denied';
          _loading = false;
        });
        return;
      }

      if (widget.callType == 'audio') {
        await _agora.joinAudioCall(
          userId: widget.uid,
          onRemoteUserJoined: (uid) {
            if (!mounted) return;
            setState(() => _remoteUid = uid);
          },
          onRemoteUserLeft: (uid) {
            if (!mounted) return;
            setState(() => _remoteUid = 0);
          },
          onError: (error) {
            if (!mounted) return;
            setState(() => _error = error);
          },
        );
      } else {
        await _agora.joinVideoCall(
          userId: widget.uid,
          onRemoteUserJoined: (uid) {
            if (!mounted) return;
            setState(() => _remoteUid = uid);
          },
          onRemoteUserLeft: (uid) {
            if (!mounted) return;
            setState(() => _remoteUid = 0);
          },
          onError: (error) {
            if (!mounted) return;
            setState(() => _error = error);
          },
        );
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _agora.leaveCall().catchError((_) {});
    _agora.dispose().catchError((_) {});
    super.dispose();
  }

  Future<void> _endCall() async {
    try {
      await _agora.leaveCall();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _toggleMic() async {
    final next = !_micOn;
    await _agora.enableAudio(next);
    if (!mounted) return;
    setState(() => _micOn = next);
  }

  Future<void> _toggleCamera() async {
    final next = !_cameraOn;
    await _agora.enableVideo(next);
    if (!mounted) return;
    setState(() => _cameraOn = next);
  }

  Future<void> _switchCamera() async {
    await _agora.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType != 'audio';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AdminAppTheme.royal,
        foregroundColor: Colors.white,
        title: Text(isVideo ? 'Puja Video Call' : 'Puja Audio Call'),
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (!isVideo)
            _buildAudioStage()
          else
            _buildVideoStage(),
          _buildControls(isVideo: isVideo),
        ],
      ),
    );
  }

  Widget _buildAudioStage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.call,
            size: 80,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 14),
          Text(
            _remoteUid == 0 ? 'Waiting for other participant...' : 'Connected',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoStage() {
    return Stack(
      children: [
        Positioned.fill(
          child: _remoteUid == 0
              ? Center(
                  child: Text(
                    'Waiting for other participant...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                )
              : AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _agora.engine,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection: RtcConnection(channelId: widget.channelName),
                  ),
                ),
        ),
        Positioned(
          top: 16,
          right: 16,
          width: 120,
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.black,
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _agora.engine,
                  canvas: VideoCanvas(uid: widget.uid),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls({required bool isVideo}) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filled(
                onPressed: _toggleMic,
                style: IconButton.styleFrom(
                  backgroundColor: _micOn
                      ? Colors.white.withValues(alpha: 0.14)
                      : AdminAppTheme.danger.withValues(alpha: 0.9),
                ),
                icon: Icon(_micOn ? Icons.mic : Icons.mic_off),
              ),
              if (isVideo)
                IconButton.filled(
                  onPressed: _toggleCamera,
                  style: IconButton.styleFrom(
                    backgroundColor: _cameraOn
                        ? Colors.white.withValues(alpha: 0.14)
                        : AdminAppTheme.danger.withValues(alpha: 0.9),
                  ),
                  icon: Icon(_cameraOn ? Icons.videocam : Icons.videocam_off),
                ),
              if (isVideo)
                IconButton.filled(
                  onPressed: _switchCamera,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                  ),
                  icon: const Icon(Icons.cameraswitch),
                ),
              IconButton.filled(
                onPressed: _endCall,
                style: IconButton.styleFrom(backgroundColor: AdminAppTheme.danger),
                icon: const Icon(Icons.call_end),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

