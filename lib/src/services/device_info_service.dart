import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceInfoService {
  const DeviceInfoService._();

  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static PackageInfo? _cachedPackageInfo;

  /// Retrieves cached or live PackageInfo for the application.
  static Future<PackageInfo> get packageInfo async {
    if (_cachedPackageInfo != null) return _cachedPackageInfo!;
    try {
      _cachedPackageInfo = await PackageInfo.fromPlatform();
      return _cachedPackageInfo!;
    } catch (e) {
      debugPrint('[DEVICE_INFO] PackageInfo error: $e');
      return PackageInfo(
        appName: 'CBI HR',
        packageName: 'com.cbi.cbihr',
        version: '1.0.0',
        buildNumber: '13',
      );
    }
  }

  /// Helper to get the display app version.
  static Future<String> getAppVersion() async {
    final info = await packageInfo;
    return info.version;
  }

  /// Collects detailed device and application metadata matching the API schema.
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final info = await packageInfo;
    final appVersion = info.version;

    try {
      if (kIsWeb) {
        final web = await _deviceInfoPlugin.webBrowserInfo;
        return {
          'platform': 'Web',
          'model': web.browserName.name,
          'manufacturer': web.vendor ?? 'Browser',
          'brand': web.browserName.name,
          'osVersion': web.userAgent ?? 'Unknown',
          'sdkInt': 0,
          'buildId': web.platform ?? 'Web',
          'isPhysicalDevice': true,
          'hardware': 'Web',
          'appVersion': appVersion,
        };
      }

      if (Platform.isAndroid) {
        final android = await _deviceInfoPlugin.androidInfo;
        return {
          'platform': 'Android',
          'model': android.model,
          'manufacturer': android.manufacturer,
          'brand': android.brand,
          'osVersion': android.version.release,
          'sdkInt': android.version.sdkInt,
          'buildId': android.id,
          'isPhysicalDevice': android.isPhysicalDevice,
          'hardware': android.hardware.isNotEmpty ? android.hardware : android.device,
          'appVersion': appVersion,
        };
      }

      if (Platform.isIOS) {
        final ios = await _deviceInfoPlugin.iosInfo;
        return {
          'platform': 'iOS',
          'model': ios.model,
          'manufacturer': 'Apple',
          'brand': 'Apple',
          'osVersion': ios.systemVersion,
          'sdkInt': 0,
          'buildId': ios.utsname.machine,
          'isPhysicalDevice': ios.isPhysicalDevice,
          'hardware': ios.utsname.machine,
          'appVersion': appVersion,
        };
      }

      if (Platform.isWindows) {
        final windows = await _deviceInfoPlugin.windowsInfo;
        return {
          'platform': 'Windows',
          'model': 'Windows PC',
          'manufacturer': 'PC',
          'brand': 'Microsoft',
          'osVersion': '${windows.majorVersion}.${windows.minorVersion}.${windows.buildNumber}',
          'sdkInt': 0,
          'buildId': windows.buildNumber.toString(),
          'isPhysicalDevice': true,
          'hardware': 'x86_64',
          'appVersion': appVersion,
        };
      }

      if (Platform.isMacOS) {
        final mac = await _deviceInfoPlugin.macOsInfo;
        return {
          'platform': 'macOS',
          'model': mac.model,
          'manufacturer': 'Apple',
          'brand': 'Apple',
          'osVersion': '${mac.majorVersion}.${mac.minorVersion}.${mac.patchVersion}',
          'sdkInt': 0,
          'buildId': mac.osRelease,
          'isPhysicalDevice': true,
          'hardware': mac.arch,
          'appVersion': appVersion,
        };
      }
    } catch (e) {
      debugPrint('[DEVICE_INFO] Error reading device info: $e');
    }

    return {
      'platform': Platform.operatingSystem,
      'model': 'Generic',
      'manufacturer': 'Generic',
      'brand': 'Generic',
      'osVersion': 'Unknown',
      'sdkInt': 0,
      'buildId': 'Unknown',
      'isPhysicalDevice': true,
      'hardware': 'Generic',
      'appVersion': appVersion,
    };
  }
}
