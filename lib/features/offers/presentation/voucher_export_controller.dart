import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../menu/presentation/menu_dependencies.dart';
import '../data/voucher_platform.dart';
import '../domain/voucher_export.dart';
import 'offers_controller.dart';
import '../../menu/presentation/scope_revision_provider.dart';

final voucherPlatformProvider = Provider<VoucherPlatform>(
  (ref) => const NativeVoucherPlatform(),
);
final voucherExportServiceProvider = Provider(
  (ref) => VoucherExportService(ref.watch(voucherPlatformProvider)),
);

class VoucherExportState {
  const VoucherExportState({
    this.busy = false,
    this.failure,
    this.saved = false,
  });
  final bool busy;
  final AppFailure? failure;
  final bool saved;
}

final voucherExportControllerProvider =
    NotifierProvider<VoucherExportController, Map<int, VoucherExportState>>(
      VoucherExportController.new,
      isAutoDispose: true,
    );

/// Single-flight per target, scoped to explicit login and current permissions.
class VoucherExportController extends Notifier<Map<int, VoucherExportState>> {
  int _epoch = 0;
  @override
  Map<int, VoucherExportState> build() {
    ref.watch(offersScopeProvider);
    ref.watch(salonSwitchRevisionProvider);
    _epoch++;
    return {};
  }

  Future<void> export(
    int offerId,
    int targetId,
    ExportAction action,
    VoucherCapture capture,
  ) async {
    if (state[targetId]?.busy == true) return;
    final epoch = _epoch;
    final switchRevision = ref.read(salonSwitchRevisionProvider);
    final scope = ref.read(offersScopeProvider);
    final offer = ref
        .read(offersControllerProvider)
        .asData
        ?.value
        ?.byId[offerId];
    final revision = ref
        .read(offersControllerProvider)
        .asData
        ?.value
        ?.scheduleRevision;
    final targets =
        ref
            .read(offersControllerProvider)
            .asData
            ?.value
            ?.targetsByOffer[offerId] ??
        [];
    final matching = targets.where((target) => target.id == targetId);
    final originalTarget = matching.isEmpty ? null : matching.first;
    bool current() =>
        ref.mounted &&
        epoch == _epoch &&
        switchRevision == ref.read(salonSwitchRevisionProvider) &&
        scope != null &&
        scope == ref.read(offersScopeProvider);
    bool eligible() {
      if (!current()) return false;
      final view = ref.read(offersControllerProvider).asData?.value;
      return view != null &&
          identical(offer, view.byId[offerId]) &&
          view.scheduleRevision == revision &&
          view.canExport(offerId, ref.read(offersTodayProvider)) &&
          (view.targetsByOffer[offerId]?.any(
                (target) =>
                    identical(target, originalTarget) && target.eligible,
              ) ??
              false);
    }

    if (!eligible()) return;
    state = {...state, targetId: const VoucherExportState(busy: true)};
    try {
      await ref
          .read(voucherExportServiceProvider)
          .export(action, capture, eligible);
      if (current()) {
        state = {
          ...state,
          targetId: VoucherExportState(saved: action == ExportAction.save),
        };
      }
    } on AppFailure catch (failure, stack) {
      if (!current()) return;
      ref.read(appLoggerProvider).offersFailure(stack);
      state = {...state, targetId: VoucherExportState(failure: failure)};
    }
  }
}
