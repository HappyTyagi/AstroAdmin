import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraVideoCallService {
  late final RtcEngine _engine;
  final String agoraAppId;
  final String agoraToken;
  final String channelName;

  bool _initialized = false;

  AgoraVideoCallService({
    required this.agoraAppId,
    required this.agoraToken,
    required this.channelName,
  });

  Future<void> initialize() async {
    if (_initialized) return;
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: agoraAppId));
    await _engine.setChannelProfile(
      ChannelProfileType.channelProfileCommunication,
    );
    await _engine.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );
    _initialized = true;
    debugPrint('[Agora][Admin] initialized channel=$channelName');
  }

  Future<bool> requestVideoPermissions() async {
    final mic = await Permission.microphone.request();
    final cam = await Permission.camera.request();
    return mic.isGranted && cam.isGranted;
  }

  Future<bool> requestAudioPermission() async {
    final mic = await Permission.microphone.request();
    return mic.isGranted;
  }

  Future<void> joinVideoCall({
    required int userId,
    required void Function(int uid) onRemoteUserJoined,
    required void Function(int uid) onRemoteUserLeft,
    required void Function(String error) onError,
  }) async {
    await initialize();
    await _engine.enableVideo();
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.startPreview();

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint(
            '[Agora][Admin] join ok uid=${connection.localUid} elapsed=$elapsed',
          );
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('[Agora][Admin] remote joined uid=$remoteUid');
          onRemoteUserJoined(remoteUid);
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          debugPrint('[Agora][Admin] remote left uid=$remoteUid');
          onRemoteUserLeft(remoteUid);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[Agora][Admin] error code=$err msg=$msg');
          onError('$err: $msg');
        },
      ),
    );

    await _engine.joinChannel(
      token: agoraToken,
      channelId: channelName,
      uid: userId,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
  }

  Future<void> joinAudioCall({
    required int userId,
    required void Function(int uid) onRemoteUserJoined,
    required void Function(int uid) onRemoteUserLeft,
    required void Function(String error) onError,
  }) async {
    await initialize();
    await _engine.disableVideo();
    await _engine.enableAudio();
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint(
            '[Agora][Admin] audio join ok uid=${connection.localUid} elapsed=$elapsed',
          );
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          onRemoteUserJoined(remoteUid);
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          onRemoteUserLeft(remoteUid);
        },
        onError: (ErrorCodeType err, String msg) {
          onError('$err: $msg');
        },
      ),
    );

    await _engine.joinChannel(
      token: agoraToken,
      channelId: channelName,
      uid: userId,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
      ),
    );
  }

  Future<void> enableVideo(bool enable) async {
    if (enable) {
      await _engine.enableVideo();
      await _engine.startPreview();
      await _engine.muteLocalVideoStream(false);
    } else {
      await _engine.muteLocalVideoStream(true);
      await _engine.stopPreview();
    }
  }

  Future<void> enableAudio(bool enable) async {
    if (enable) {
      await _engine.enableAudio();
      await _engine.muteLocalAudioStream(false);
    } else {
      await _engine.muteLocalAudioStream(true);
    }
  }

  Future<void> switchCamera() async {
    await _engine.switchCamera();
  }

  Future<void> leaveCall() async {
    await _engine.leaveChannel();
    await _engine.stopPreview();
  }

  Future<void> dispose() async {
    try {
      await _engine.release();
    } catch (_) {}
    _initialized = false;
  }

  RtcEngine get engine => _engine;
}

