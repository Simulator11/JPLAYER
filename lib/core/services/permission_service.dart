import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'media_channel.dart';

/// Handles Android media permissions.
///
/// JPlayer never asks for unrestricted storage access:
/// - Android 13+ -> READ_MEDIA_AUDIO / READ_MEDIA_VIDEO
/// - Android 12 and below -> READ_EXTERNAL_STORAGE (scoped as far as the OS allows)
class PermissionService {
  PermissionService(this._channel);

  final MediaChannel _channel;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<Permission> _audioPermission() async {
    final sdk = await _channel.androidSdkInt();
    return sdk >= 33 ? Permission.audio : Permission.storage;
  }

  Future<Permission> _videoPermission() async {
    final sdk = await _channel.androidSdkInt();
    return sdk >= 33 ? Permission.videos : Permission.storage;
  }

  Future<bool> hasAudioPermission() async {
    if (!_isAndroid) return false;
    return (await _audioPermission()).status.isGranted;
  }

  Future<bool> requestAudioPermission() async {
    if (!_isAndroid) return false;
    final permission = await _audioPermission();
    final status = await permission.request();
    return status.isGranted;
  }

  Future<bool> audioPermanentlyDenied() async {
    if (!_isAndroid) return false;
    final permission = await _audioPermission();
    return permission.status.isPermanentlyDenied;
  }

  /// Android 13+ shows media notifications in the media carousel even without
  /// POST_NOTIFICATIONS, but requesting it gives the notification drawer
  /// controls too. Denial never blocks playback.
  Future<void> requestNotificationPermission() async {
    if (!_isAndroid) return;
    final sdk = await _channel.androidSdkInt();
    if (sdk >= 33) {
      await Permission.notification.request();
    }
  }

  Future<bool> hasVideoPermission() async {
    if (!_isAndroid) return false;
    return (await _videoPermission()).status.isGranted;
  }

  Future<bool> requestVideoPermission() async {
    if (!_isAndroid) return false;
    final permission = await _videoPermission();
    final status = await permission.request();
    return status.isGranted;
  }

  Future<bool> videoPermanentlyDenied() async {
    if (!_isAndroid) return false;
    final permission = await _videoPermission();
    return permission.status.isPermanentlyDenied;
  }

  Future<void> openSettings() => openAppSettings();
}
