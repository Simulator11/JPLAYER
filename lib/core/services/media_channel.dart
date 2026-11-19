import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart side of the native MediaStore bridge (`com.jplayer/media`).
class MediaChannel {
  MediaChannel();

  static const MethodChannel _channel = MethodChannel('com.jplayer/media');

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<List<Map<String, dynamic>>> querySongs() async {
    if (!isAndroid) return const [];
    final result = await _channel.invokeMethod<List<Object?>>('querySongs');
    return _toMaps(result);
  }

  Future<List<Map<String, dynamic>>> queryVideos() async {
    if (!isAndroid) return const [];
    final result = await _channel.invokeMethod<List<Object?>>('queryVideos');
    return _toMaps(result);
  }

  Future<String?> getArtwork({int? albumId, int? songId, String? path}) async {
    if (!isAndroid) return null;
    return _channel.invokeMethod<String>('getArtwork', {
      'albumId': albumId,
      'songId': songId,
      'path': path,
    });
  }

  Future<String?> getVideoThumbnail({
    required int videoId,
    String? path,
  }) async {
    if (!isAndroid) return null;
    return _channel.invokeMethod<String>('getVideoThumbnail', {
      'videoId': videoId,
      'path': path,
    });
  }

  Future<int> refreshMediaStore(List<String> paths) async {
    if (!isAndroid) return 0;
    return await _channel.invokeMethod<int>('refreshMediaStore', {
          'paths': paths,
        }) ??
        0;
  }

  Future<void> clearArtworkCache() async {
    if (!isAndroid) return;
    await _channel.invokeMethod<bool>('clearArtworkCache');
  }

  Future<void> setScreenBrightness(double? value) async {
    if (!isAndroid) return;
    await _channel.invokeMethod<bool>('setScreenBrightness', {'value': value});
  }

  int? _cachedSdkInt;

  Future<int> androidSdkInt() async {
    if (!isAndroid) return 0;
    if (_cachedSdkInt != null) return _cachedSdkInt!;
    final info = await _channel.invokeMapMethod<String, dynamic>(
      'getPlatformInfo',
    );
    _cachedSdkInt = (info?['sdkInt'] as num?)?.toInt() ?? 0;
    return _cachedSdkInt!;
  }

  static List<Map<String, dynamic>> _toMaps(List<Object?>? raw) {
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
}
