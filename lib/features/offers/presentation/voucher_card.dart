import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/voucher_capture.dart';
import '../domain/offer.dart';
import '../domain/offer_schedule.dart';
import '../domain/voucher_export.dart';
import 'offer_labels.dart';
import 'offers_widgets.dart';
import 'voucher_export_controller.dart';

class VoucherCardGroup extends ConsumerStatefulWidget {
  const VoucherCardGroup({
    super.key,
    required this.offer,
    required this.target,
    required this.shop,
    required this.summary,
    required this.design,
    required this.enabled,
    required this.dimmed,
    required this.overlap,
  });
  final Offer offer;
  final OfferTarget target;
  final String shop;
  final ScheduleSummary? summary;
  final int design;
  final bool enabled;
  final bool dimmed;
  final bool overlap;
  @override
  ConsumerState<VoucherCardGroup> createState() => _VoucherCardGroupState();
}

class _VoucherCardGroupState extends ConsumerState<VoucherCardGroup> {
  final _captureKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final export =
        ref.watch(voucherExportControllerProvider)[widget.target.id] ??
        const VoucherExportState();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.voucherGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Opacity(
            opacity: widget.dimmed ? AppTokens.voucherInactiveOpacity : 1,
            child: RepaintBoundary(
              key: _captureKey,
              child: VoucherCard(
                offer: widget.offer,
                target: widget.target,
                shop: widget.shop,
                summary: widget.summary ?? ScheduleSummary([], false),
                design: widget.design,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.smallGap),
          Wrap(
            spacing: AppTokens.smallGap,
            runSpacing: AppTokens.smallGap,
            children: [
              FilledButton.icon(
                onPressed: !widget.enabled || export.busy
                    ? null
                    : () => ref
                          .read(voucherExportControllerProvider.notifier)
                          .export(
                            widget.offer.id,
                            widget.target.id,
                            ExportAction.share,
                            FlutterVoucherCapture(_captureKey),
                          ),
                icon: const Icon(Icons.share),
                label: const Text(AppStrings.share),
              ),
              OutlinedButton.icon(
                onPressed: !widget.enabled || export.busy
                    ? null
                    : () => ref
                          .read(voucherExportControllerProvider.notifier)
                          .export(
                            widget.offer.id,
                            widget.target.id,
                            ExportAction.save,
                            FlutterVoucherCapture(_captureKey),
                          ),
                icon: const Icon(Icons.save_alt),
                label: const Text(AppStrings.saveImage),
              ),
              if (export.busy) const CircularProgressIndicator(),
            ],
          ),
          if (export.failure != null)
            Text(export.failure?.message ?? AppStrings.exportFailed),
          if (export.saved) const Text(AppStrings.imageSaved),
          if (widget.overlap)
            const Text(
              AppStrings.overlapWarning,
              style: TextStyle(color: AppTokens.accent),
            ),
        ],
      ),
    );
  }
}

/// Customer-facing card. Stripes are decorative and deliberately contain no code.
class VoucherCard extends StatelessWidget {
  const VoucherCard({
    super.key,
    required this.offer,
    required this.target,
    required this.shop,
    required this.summary,
    required this.design,
  });
  final Offer offer;
  final OfferTarget target;
  final String shop;
  final ScheduleSummary summary;
  final int design;
  @override
  Widget build(BuildContext context) {
    final classic = design == 3;
    final colors = switch (design) {
      0 => AppTokens.voucherGift,
      1 => AppTokens.voucherOcean,
      2 => AppTokens.voucherSunset,
      _ => [Theme.of(context).colorScheme.surface],
    };
    final ink = classic
        ? Theme.of(context).colorScheme.onSurface
        : AppTokens.white;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Container(
      constraints: const BoxConstraints(minHeight: AppTokens.voucherHeight),
      decoration: BoxDecoration(
        gradient: classic
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
        color: classic ? Theme.of(context).colorScheme.surface : null,
        border: Border.all(
          color: classic
              ? Theme.of(context).dividerColor
              : AppTokens.transparent,
        ),
        borderRadius: BorderRadius.circular(AppTokens.offerRadius),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: AppTokens.voucherShadowBlur,
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: ink, fontSize: AppTokens.offerCaption),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.offerPadding),
                  child: VoucherContent(
                    offer: offer,
                    target: target,
                    shop: shop,
                    summary: summary,
                    design: design,
                  ),
                ),
              ),
              if (scale <= AppTokens.homeLargeText) VoucherStub(ink: ink),
            ],
          ),
        ),
      ),
    );
  }
}

class VoucherContent extends StatelessWidget {
  const VoucherContent({
    super.key,
    required this.offer,
    required this.target,
    required this.shop,
    required this.summary,
    required this.design,
  });
  final Offer offer;
  final OfferTarget target;
  final String shop;
  final ScheduleSummary summary;
  final int design;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        shop,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: AppTokens.offerSmall,
          fontWeight: FontWeight.bold,
        ),
      ),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppTokens.smallGap,
        children: [
          Text(
            OfferLabels.value(offer),
            style: TextStyle(
              fontSize: OfferLabels.value(offer).length > 3
                  ? AppTokens.tileIcon
                  : AppTokens.voucherValueSize,
              fontWeight: FontWeight.bold,
              color: design == 3 ? AppTokens.primary : AppTokens.white,
            ),
          ),
          Text(
            OfferLabels.discount(offer),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTokens.voucherAccents[design],
            ),
          ),
        ],
      ),
      Text(
        offer.title,
        style: const TextStyle(
          fontSize: AppTokens.homeBodySize,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        OfferLabels.target(target),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: AppTokens.smallGap),
      Text(
        OfferLabels.fullSchedule(offer, summary),
        style: const TextStyle(fontSize: AppTokens.offerSmall),
      ),
    ],
  );
}

class VoucherStub extends StatelessWidget {
  const VoucherStub({super.key, required this.ink});
  final Color ink;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: AppTokens.voucherStub,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: AppTokens.progressStroke,
          child: CustomPaint(
            painter: TicketDivider(ink.withValues(alpha: 0.5)),
          ),
        ),
        Center(
          child: Semantics(
            label: AppStrings.decorativeBarcode,
            child: CustomPaint(
              size: const Size(
                AppTokens.voucherBarcodeWidth,
                AppTokens.voucherBarcodeHeight,
              ),
              painter: _Stripes(ink),
            ),
          ),
        ),
        for (final top in [true, false])
          Align(
            alignment: top ? Alignment.topLeft : Alignment.bottomLeft,
            child: Container(
              width: AppTokens.voucherNotch,
              height: AppTokens.voucherNotch,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ),
      ],
    ),
  );
}

class _Stripes extends CustomPainter {
  const _Stripes(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.5);
    for (
      var y = 0.0;
      y < size.height;
      y += AppTokens.ticketDash + AppTokens.ticketDashGap
    ) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, AppTokens.progressStroke),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => oldDelegate.color != color;
}
