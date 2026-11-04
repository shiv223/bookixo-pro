import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/offer.dart';
import '../domain/offer_schedule.dart';
import 'offer_labels.dart';
import 'offers_controller.dart';

class OffersWebNotice extends StatelessWidget {
  const OffersWebNotice({super.key});
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).brightness == Brightness.dark
        ? AppTokens.infoDarkBackground
        : AppTokens.infoBackground,
    child: Padding(
      padding: const EdgeInsets.all(AppTokens.offerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppTokens.primary),
          Text(
            AppStrings.offersNotice,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTokens.infoDarkInk
                  : AppTokens.darkBlue,
            ),
          ),
          const TextButton(
            onPressed: null,
            child: Text(AppStrings.openWebUnavailable),
          ),
        ],
      ),
    ),
  );
}

/// Resource-specific recovery keeps the already loaded tickets visible.
class ResourceNotice<T> extends StatelessWidget {
  const ResourceNotice({
    super.key,
    required this.label,
    required this.resource,
    required this.onRetry,
  });
  final String label;
  final ResourceState<T>? resource;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final value = resource;
    if (value == null || value.complete) return const SizedBox.shrink();
    final message =
        value.failure?.message ??
        (value.capped ? AppStrings.resourceCap : AppStrings.resourcePending);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.offerGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.resourceNotice(label, message)),
          if (value.items.isNotEmpty && value.failure != null)
            const Text(AppStrings.resourcePartial),
          if (!value.loading)
            TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}

class OfferSkeleton extends StatelessWidget {
  const OfferSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: AppStrings.offersLoading,
    child: Container(
      height: AppTokens.voucherHeight,
      margin: const EdgeInsets.only(bottom: AppTokens.offerPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.offerRadius),
      ),
    ),
  );
}

class OfferTicket extends StatelessWidget {
  const OfferTicket({
    super.key,
    required this.offer,
    required this.status,
    required this.summary,
    required this.schedulesComplete,
    required this.onTap,
  });
  final Offer offer;
  final OfferListStatus status;
  final ScheduleSummary? summary;
  final bool schedulesComplete;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(AppTokens.offerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfferTicketHeading(title: offer.title, status: status),
          const SizedBox(height: AppTokens.smallGap),
          OfferScheduleContent(
            summary: summary,
            schedulesComplete: schedulesComplete,
          ),
          const SizedBox(height: AppTokens.smallGap),
          Text(
            OfferLabels.validity(offer),
            style: const TextStyle(
              fontSize: AppTokens.offerCaption,
              height: AppTokens.offerTicketLineHeight,
            ),
          ),
        ],
      ),
    );
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) > AppTokens.homeLargeText;
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.offerPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.offerRadius),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OfferValueBlock(offer: offer),
                  content,
                ],
              )
            : Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: AppTokens.offerTicketValueWidth,
                    child: OfferValueBlock(offer: offer),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppTokens.offerTicketValueWidth,
                    ),
                    child: content,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Promotional ticket colors depend on discount type, never rule activity.
class OfferValueBlock extends StatelessWidget {
  const OfferValueBlock({super.key, required this.offer});
  final Offer offer;
  @override
  Widget build(BuildContext context) {
    final known = offer.knownDiscount;
    final percent = offer.discountType == 'PERCENT';
    final background = !known
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : percent
        ? AppTokens.accent
        : AppTokens.primary;
    final foreground = !known
        ? Theme.of(context).colorScheme.onSurface
        : AppTokens.white;
    return Container(
      key: ValueKey('discount-${offer.id}'),
      padding: const EdgeInsets.all(AppTokens.smallGap),
      decoration: BoxDecoration(
        color: background,
        gradient: known
            ? AppTokens.offerTicketGradient(percent: percent)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!known)
            Text(
              OfferLabels.value(offer),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground,
                fontSize: AppTokens.offerCaption,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                OfferLabels.value(offer),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  color: foreground,
                  fontSize: known
                      ? AppTokens.offerTicketValueSize
                      : AppTokens.offerCaption,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (known)
            Text(
              OfferLabels.discount(offer),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground,
                fontSize: AppTokens.offerTicketLabelSize,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// Status sits beside the title when space permits, stacked at large text.
class OfferTicketHeading extends StatelessWidget {
  const OfferTicketHeading({
    super.key,
    required this.title,
    required this.status,
  });
  final String title;
  final OfferListStatus status;
  @override
  Widget build(BuildContext context) {
    final name = Text(
      title,
      maxLines:
          MediaQuery.textScalerOf(context).scale(1) > AppTokens.homeLargeText
          ? null
          : 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: AppTokens.offerCaption,
        height: AppTokens.offerTicketLineHeight,
        fontWeight: FontWeight.bold,
      ),
    );
    final badge = Container(
      padding: const EdgeInsets.all(AppTokens.smallGap),
      decoration: BoxDecoration(
        color: status == OfferListStatus.active
            ? AppTokens.success.withValues(alpha: AppTokens.offerBadgeOpacity)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
      ),
      child: Text(
        OfferLabels.listStatus(status),
        style: const TextStyle(
          fontSize: AppTokens.offerCaption,
          height: AppTokens.offerTicketLineHeight,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppTokens.offerHeadingWidth ||
            MediaQuery.textScalerOf(context).scale(1) >
                AppTokens.homeLargeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              name,
              const SizedBox(height: AppTokens.smallGap),
              badge,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: name),
            const SizedBox(width: AppTokens.smallGap),
            badge,
          ],
        );
      },
    );
  }
}

class OfferScheduleContent extends StatelessWidget {
  const OfferScheduleContent({
    super.key,
    required this.summary,
    required this.schedulesComplete,
  });
  final ScheduleSummary? summary;
  final bool schedulesComplete;

  @override
  Widget build(BuildContext context) {
    final value = summary;
    if (value == null) {
      return const Text(AppStrings.scheduleUnavailable);
    }
    if (value.schedules.isEmpty && !value.hasDiagnostics) {
      return Text(
        schedulesComplete
            ? AppStrings.noScheduleRules
            : AppStrings.schedulesIncomplete,
      );
    }
    return ScheduleLines(summary: value);
  }
}

class ScheduleLines extends StatelessWidget {
  const ScheduleLines({super.key, required this.summary});
  final ScheduleSummary summary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final schedule in summary.schedules)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (schedule.type == 'WEEKLY' && schedule.days.length < 7)
              DayCircles(days: schedule.days),
            Text(
              OfferLabels.schedule(schedule),
              style: const TextStyle(
                fontSize: AppTokens.offerCaption,
                height: AppTokens.offerTicketLineHeight,
              ),
            ),
          ],
        ),
      if (summary.hasDiagnostics)
        const Text(
          AppStrings.invalidSchedule,
          style: TextStyle(fontSize: AppTokens.offerCaption),
        ),
    ],
  );
}

class DayCircles extends StatelessWidget {
  const DayCircles({super.key, required this.days});
  final Set<int> days;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppTokens.progressStroke,
    runSpacing: AppTokens.progressStroke,
    children: [
      for (var day = 1; day <= 7; day++)
        Semantics(
          label: AppStrings.weekdays[day - 1],
          selected: days.contains(day),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: AppTokens.offerDay,
              minHeight: AppTokens.offerDay,
            ),
            padding: const EdgeInsets.all(AppTokens.progressStroke),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: days.contains(day)
                  ? AppTokens.primary
                  : AppTokens.transparent,
              border: Border.all(color: AppTokens.primary),
            ),
            child: Text(
              AppStrings.weekdayLetters[day - 1],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTokens.offerDayText,
                color: days.contains(day)
                    ? AppTokens.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
    ],
  );
}

class TicketDivider extends CustomPainter {
  const TicketDivider(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = AppTokens.progressStroke;
    for (
      var y = 0.0;
      y < size.height;
      y += AppTokens.ticketDash + AppTokens.ticketDashGap
    ) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(
          size.width / 2,
          (y + AppTokens.ticketDash).clamp(0, size.height),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(TicketDivider oldDelegate) => oldDelegate.color != color;
}
