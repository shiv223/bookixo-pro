import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android development HTTP is debug-only, with secure backup disabled',
    () {
      final main = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final debug = File('android/app/src/debug/AndroidManifest.xml')
          .readAsStringSync();
      final profile = File('android/app/src/profile/AndroidManifest.xml')
          .readAsStringSync();
      expect(main, contains('android:usesCleartextTraffic="false"'));
      expect(main, contains('android:allowBackup="false"'));
      expect(main, contains('android.permission.INTERNET'));
      expect(main, isNot(contains('CAMERA')));
      expect(debug, contains('android:usesCleartextTraffic="true"'));
      expect(debug, contains('tools:replace="android:usesCleartextTraffic"'));
      expect(profile, isNot(contains('usesCleartextTraffic="true"')));
    },
  );
  test('iOS Debug selects separate development transport plist', () {
    final release = File('ios/Runner/Info.plist').readAsStringSync();
    final debug = File('ios/Runner/Info-Debug.plist').readAsStringSync();
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    expect(release, isNot(contains('NSAllowsArbitraryLoads')));
    expect(debug, contains('NSAllowsArbitraryLoads'));
    expect(project, contains('INFOPLIST_FILE = "Runner/Info-Debug.plist"'));
    expect(release, isNot(contains('NSCameraUsageDescription')));
  });
}
