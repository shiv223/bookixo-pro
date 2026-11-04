import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/voucher_export.dart';

/// Captures only the customer-facing boundary, never buttons or warnings.
class FlutterVoucherCapture implements VoucherCapture {
  const FlutterVoucherCapture(this.key, {this.waitForPaint = _nextFrame});
  final GlobalKey key;
  final Future<void> Function() waitForPaint;
  static Future<void> _nextFrame() => WidgetsBinding.instance.endOfFrame;
  RenderRepaintBoundary _boundary() {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary || !object.attached) {
      throw const ExportFailure(ExportFailureKind.capture);
    }
    return object;
  }

  @override
  ui.Rect get origin {
    final object = _boundary();
    return object.localToGlobal(Offset.zero) & object.size;
  }

  @override
  Future<Uint8List> capture() async {
    try {
      // Flush pending builds as well as paint before capturing current terms.
      await waitForPaint();
      final boundary = _boundary();
      final image = await boundary.toImage(
        pixelRatio: AppTokens.voucherPixelRatio,
      );
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw const ExportFailure(ExportFailureKind.capture);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
    } on ExportFailure {
      rethrow;
    } catch (_, stack) {
      Error.throwWithStackTrace(
        const ExportFailure(ExportFailureKind.capture),
        stack,
      );
    }
  }
}
