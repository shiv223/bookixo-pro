import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/voucher_export.dart';

/// Native plugins are isolated here; permission is requested only by Save.
class NativeVoucherPlatform implements VoucherPlatform {
  const NativeVoucherPlatform();
  void _supported() {
    if (kIsWeb ||
        !const {
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      throw const ExportFailure(ExportFailureKind.unsupported);
    }
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    _supported();
    try {
      return await operation();
    } on GalException catch (error, stack) {
      final kind = switch (error.type) {
        GalExceptionType.accessDenied => ExportFailureKind.denied,
        GalExceptionType.notEnoughSpace => ExportFailureKind.storageFull,
        _ => ExportFailureKind.platform,
      };
      Error.throwWithStackTrace(ExportFailure(kind), stack);
    } on PlatformException catch (_, stack) {
      Error.throwWithStackTrace(
        const ExportFailure(ExportFailureKind.platform),
        stack,
      );
    } on MissingPluginException catch (_, stack) {
      Error.throwWithStackTrace(
        const ExportFailure(ExportFailureKind.unsupported),
        stack,
      );
    } on AppFailure {
      rethrow;
    } catch (_, stack) {
      Error.throwWithStackTrace(
        const ExportFailure(ExportFailureKind.platform),
        stack,
      );
    }
  }

  @override
  Future<bool> requestSaveAccess() =>
      _guard(() async => await Gal.hasAccess() || await Gal.requestAccess());
  @override
  Future<void> save(Uint8List png) =>
      _guard(() => Gal.putImageBytes(png, name: 'bookixo-offer'));
  @override
  Future<void> share(Uint8List png, Rect origin) => _guard(() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: ['bookixo-offer.png'],
        sharePositionOrigin: origin,
      ),
    );
  });
}
