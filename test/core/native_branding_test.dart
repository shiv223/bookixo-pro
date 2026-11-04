import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void expectPngSize(String path, int size) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10], reason: path);
  final header = ByteData.sublistView(bytes);
  expect(header.getUint32(16), size, reason: path);
  expect(header.getUint32(20), size, reason: path);
}

void main() {
  test('Android launcher and splash images cover every density', () {
    const densities = {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    };
    for (final density in densities.entries) {
      final resources = 'android/app/src/main/res';
      expectPngSize(
        '$resources/mipmap-${density.key}/ic_launcher.png',
        (48 * density.value).round(),
      );
      expectPngSize(
        '$resources/drawable-${density.key}/launch_logo.png',
        (120 * density.value).round(),
      );
    }
    expectPngSize(
      'android/app/src/main/res/drawable-nodpi/launch_logo_android12.png',
      1152,
    );
  });

  test('Android launch themes reference branded resources in both modes', () {
    const resources = 'android/app/src/main/res';
    for (final folder in ['drawable', 'drawable-v21']) {
      final background = File('$resources/$folder/launch_background.xml')
          .readAsStringSync();
      expect(background, contains('@drawable/launch_logo'));
      expect(background, contains('@color/launch_background'));
      expect(background, isNot(contains('<!--')));
    }
    for (final folder in ['values-v31', 'values-night-v31']) {
      final theme = File('$resources/$folder/styles.xml').readAsStringSync();
      expect(theme, contains('android:windowSplashScreenAnimatedIcon'));
      expect(theme, contains('@drawable/launch_logo_android12'));
      expect(theme, contains('@color/launch_background'));
    }
  });

  test('iOS app icons match every asset catalog slot and are opaque RGB', () {
    const catalog = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents = jsonDecode(
      File('$catalog/Contents.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final images = contents['images'] as List<Object?>;
    for (final image in images.cast<Map<String, Object?>>()) {
      final size = double.parse((image['size'] as String).split('x').first);
      final scale = double.parse(
        (image['scale'] as String).replaceAll('x', ''),
      );
      final path = '$catalog/${image['filename']}';
      expectPngSize(path, (size * scale).round());
      expect(File(path).readAsBytesSync()[25], 2, reason: path);
    }
  });

  test('iOS launch screen centers the logo at a fixed logical size', () {
    const catalog = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    expectPngSize('$catalog/LaunchImage.png', 120);
    expectPngSize('$catalog/LaunchImage@2x.png', 240);
    expectPngSize('$catalog/LaunchImage@3x.png', 360);
    final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
        .readAsStringSync();
    expect(storyboard, contains('contentMode="scaleAspectFit"'));
    expect(storyboard, contains('firstAttribute="width" constant="120"'));
    expect(storyboard, contains('firstAttribute="height" constant="120"'));
    expect(storyboard, contains('secondAttribute="centerX"'));
    expect(storyboard, contains('secondAttribute="centerY"'));
  });
}
