import '../localization/app_strings.dart';

/// Sanitized error vocabulary crossing the data/domain boundary.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => runtimeType.toString();
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure() : super(AppStrings.network);
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure() : super(AppStrings.unauthorized);
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure() : super(AppStrings.forbidden);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure() : super(AppStrings.unknown);
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure({this.isRevisionConflict = false})
    : super(AppStrings.validation);

  /// Revision conflicts may be reconciled once by the employee draft flow.
  final bool isRevisionConflict;
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure([this.fields = const {}])
    : super(AppStrings.validation);
  final Map<String, String> fields;
}

final class ServerFailure extends AppFailure {
  const ServerFailure() : super(AppStrings.server);
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure() : super(AppStrings.unknown);
}

final class ContractFailure extends AppFailure {
  const ContractFailure() : super(AppStrings.contract);
}

final class StorageFailure extends AppFailure {
  const StorageFailure() : super(AppStrings.storage);
}

final class LogoImageFailure extends AppFailure {
  const LogoImageFailure() : super(AppStrings.logoUnavailable);
}

enum ExportFailureKind {
  denied,
  storageFull,
  unsupported,
  changed,
  capture,
  platform,
}

final class ExportFailure extends AppFailure {
  const ExportFailure(this.kind)
    : super(
        kind == ExportFailureKind.denied
            ? AppStrings.galleryDenied
            : kind == ExportFailureKind.storageFull
            ? AppStrings.galleryFull
            : kind == ExportFailureKind.unsupported
            ? AppStrings.exportUnsupported
            : kind == ExportFailureKind.changed
            ? AppStrings.exportChanged
            : AppStrings.exportFailed,
      );
  final ExportFailureKind kind;
}
