import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/admin_chat_service.dart';
import '../services/agora_video_call_service.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';

class SupportCallScreen extends StatefulWidget {
  const SupportCallScreen({
    super.key,
    required this.chatId,
    required this.callId,
    required this.callType,
    required this.localUserId,
    required this.remoteUserId,
    required this.participantName,
    this.acceptOnOpen = false,
  });

  final String chatId;
  final String callId;
  final String callType;
  final int localUserId;
  final int remoteUserId;
  final String participantName;
  final bool acceptOnOpen;

  @override
  State<SupportCallScreen> createState() => _SupportCallScreenState();
}

class _SupportCallScreenState extends State<SupportCallScreen> {
  final AdminChatService _chatService = AdminChatService();
  bool _loading = true;
  bool _ending = false;
  bool _ended = false;
  String? _error;
  int _remoteUid = 0;
  bool _micOn = true;
  bool _cameraOn = true;
  AgoraVideoCallService? _agora;

  bool get _isVideo => widget.callType.toLowerCase() == 'video';
  String get _channelName => 'chat_${widget.chatId.hashCode.abs()}';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (widget.acceptOnOpen) {
        await _chatService.acceptCall(widget.chatId, widget.callId);
      }

      final Map<String, dynamic> tokenResp = await _fetchAgoraToken(
        channelName: _channelName,
        uid: widget.localUserId,
      );
      final String appId =
          ((tokenResp['appId'] as String?) ?? '').trim().isNotEmpty
              ? (tokenResp['appId'] as String).trim()
              : ApiConfig.agoraAppId;
      final String token = ((tokenResp['token'] as String?) ?? '').trim();
      final bool tokenRequired = tokenResp['tokenRequired'] == true;

      if (appId.isEmpty) {
        throw Exception('Agora app id missing');
      }
      if (tokenRequired && token.isEmpty) {
        throw Exception(
          (tokenResp['message'] ?? 'Agora token missing').toString(),
        );
      }

      _agora = AgoraVideoCallService(
        agoraAppId: appId,
        agoraToken: token,
        channelName: _channelName,
      );

      final bool permissionsOk = _isVideo
          ? await _agora!.requestVideoPermissions()
          : await _agora!.requestAudioPermission();
      if (!permissionsOk) {
        throw Exception('Microphone/Camera permission denied');
      }

      if (_isVideo) {
        await _agora!.joinVideoCall(
          userId: widget.localUserId,
          onRemoteUserJoined: _onRemoteUserJoined,
          onRemoteUserLeft: _onRemoteUserLeft,
          onError: _onAgoraError,
        );
      } else {
        await _agora!.joinAudioCall(
          userId: widget.localUserId,
          onRemoteUserJoined: _onRemoteUserJoined,
          onRemoteUserLeft: _onRemoteUserLeft,
          onError: _onAgoraError,
        );
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<Map<String, dynamic>> _fetchAgoraToken({
    required String channelName,
    required int uid,
  }) async {
    final Response<dynamic> response = await ApiClient().post(
      ApiConfig.agoraRtcToken,
      data: <String, dynamic>{
        'channelName': channelName,
        'uid': uid,
        'role': 'publisher',
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  void _onRemoteUserJoined(int uid) {
    if (!mounted) return;
    setState(() => _remoteUid = uid);
  }

  void _onRemoteUserLeft(int uid) {
    if (!mounted) return;
    setState(() => _remoteUid = 0);
  }

  void _onAgoraError(String error) {
    if (!mounted) return;
    setState(() => _error = error);
  }

  Future<void> _toggleMic() async {
    final bool next = !_micOn;
    await _agora!.enableAudio(next);
    if (!mounted) return;
    setState(() => _micOn = next);
  }

  Future<void> _toggleCamera() async {
    final bool next = !_cameraOn;
    await _agora!.enableVideo(next);
    if (!mounted) return;
    setState(() => _cameraOn = next);
  }

  Future<void> _switchCamera() async {
    await _agora!.switchCamera();
  }

  Future<void> _endCall() async {
    if (_ending || _ended) return;
    _ending = true;
    try {
      await _chatService.endCall(
        widget.chatId,
        widget.callId,
        widget.localUserId,
      );
    } catch (_) {}
    try {
      await _agora?.leaveCall();
    } catch (_) {}
    _ended = true;
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    if (!_ended) {
      _chatService.endCall(widget.chatId, widget.callId, widget.localUserId)
          .catchError((_) {});
    }
    final AgoraVideoCallService? agora = _agora;
    if (agora != null) {
      agora.dispose().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop || _loading || _ended) {
          return;
        }
        await _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: AdminAppTheme.royal,
          foregroundColor: Colors.white,
          title: Text(_isVideo ? 'Support Video Call' : 'Support Audio Call'),
        ),
        body: Stack(
          children: <Widget>[
            Positioned.fill(child: _buildStage()),
            Positioned(
              top: 28,
              left: 24,
              right: 24,
              child: Column(
                children: <Widget>[
                  Text(
                    widget.participantName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _remoteUid == 0
                        ? 'Connecting...'
                        : (_isVideo ? 'Video connected' : 'Audio connected'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStage() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!_isVideo) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.call,
              size: 84,
              color: Colors.white.withValues(alpha: 0.88),
            ),
            const SizedBox(height: 16),
            Text(
              _remoteUid == 0
                  ? 'Waiting for other participant...'
                  : 'Call in progress',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: _remoteUid == 0
              ? Center(
                  child: Text(
                    'Waiting for other participant...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                )
              : AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _agora!.engine,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection: RtcConnection(channelId: _channelName),
                  ),
                ),
        ),
        Positioned(
          top: 24,
          right: 20,
          width: 120,
          height: 164,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ColoredBox(
              color: Colors.black,
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _agora!.engine,
                  canvas: VideoCanvas(uid: widget.localUserId),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              IconButton.filled(
                onPressed: _loading ? null : _toggleMic,
                style: IconButton.styleFrom(
                  backgroundColor: _micOn
                      ? Colors.white.withValues(alpha: 0.14)
                      : AdminAppTheme.danger,
                ),
                icon: Icon(_micOn ? Icons.mic : Icons.mic_off),
              ),
              if (_isVideo)
                IconButton.filled(
                  onPressed: _loading ? null : _toggleCamera,
                  style: IconButton.styleFrom(
                    backgroundColor: _cameraOn
                        ? Colors.white.withValues(alpha: 0.14)
                        : AdminAppTheme.danger,
                  ),
                  icon: Icon(
                    _cameraOn ? Icons.videocam : Icons.videocam_off,
                  ),
                ),
              if (_isVideo)
                IconButton.filled(
                  onPressed: _loading ? null : _switchCamera,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                  ),
                  icon: const Icon(Icons.cameraswitch),
                ),
              IconButton.filled(
                onPressed: _loading ? null : _endCall,
                style: IconButton.styleFrom(
                  backgroundColor: AdminAppTheme.danger,
                ),
                icon: _ending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.call_end),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
