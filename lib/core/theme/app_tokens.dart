import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared visual and layout tokens.
abstract final class AppTokens {
  static const servicesStart = Color(0xFF285C45);
  static const servicesEnd = Color(0xFF193C2D);
  static const shopUsersStart = Color(0xFF85405A);
  static const shopUsersEnd = Color(0xFF582A3C);
  static const shopSettingsStart = Color(0xFF48546D);
  static const shopSettingsEnd = Color(0xFF2D3548);
  static const catalogueIndent = 16.0;
  static const catalogueMaxDepth = 4;
  static const primary = Color(0xFF1A73E8);
  static const darkBlue = Color(0xFF1560C4);
  static const accent = Color(0xFFF59309);
  static const brightBlue = Color(0xFF4A8DF0);
  static const white = Color(0xFFFFFFFF);
  static const transparent = Colors.transparent;
  static const background = Color(0xFFF4F6FB);
  static const text = Color(0xFF14213D);
  static const muted = Color(0xFF6B778C);
  static const border = Color(0xFFE4E8F0);
  static const darkBackground = Color(0xFF0F1624);
  static const darkCard = Color(0xFF1A2335);
  static const darkText = Color(0xFFEEF2FA);
  static const darkMuted = Color(0xFF98A4BB);
  static const darkBorder = Color(0xFF2A3550);
  static const success = Color(0xFF12A150);
  static const accentInk = Color(0xFF241A00);
  static const dashboardStart = Color(0xFFF7A41D);
  static const dashboardEnd = Color(0xFFE8820C);
  static const homeDashboardTileStart = Color(0xFFC2410C);
  static const homeDashboardTileEnd = Color(0xFF9A3412);
  static const offersStart = Color(0xFF394C9C);
  static const offersEnd = Color(0xFF24346E);
  static const creditsStart = Color(0xFF25688E);
  static const creditsEnd = Color(0xFF184660);
  static const membershipStart = Color(0xFF75498F);
  static const membershipEnd = Color(0xFF4D2E60);
  static const homeBadgeInset = 8.0;
  static const offerRadius = 18.0;
  static const offerPadding = 14.0;
  static const offerGap = 10.0;
  static const offerTitleSize = 19.0;
  static const offerCaption = 13.0;
  static const offerSmall = 10.0;
  static const offerDay = 21.0;
  static const offerDayText = 10.0;
  static const offerTicketValueWidth = 90.0;
  static const offerTicketValueSize = 26.0;
  static const offerTicketLabelSize = 10.0;
  static const offerTicketLineHeight = 1.2;
  static const offerBadgeOpacity = 0.15;
  static const voucherInactiveOpacity = 0.55;
  static const voucherHeight = 190.0;
  static const voucherStub = 70.0;
  static const voucherGap = 22.0;
  static const voucherNotch = 18.0;
  static const voucherValueSize = 44.0;
  static const voucherBarcodeWidth = 34.0;
  static const voucherBarcodeHeight = 110.0;
  static const voucherPixelRatio = 3.0;
  static const voucherGift = [
    Color(0xFF4B2AA8),
    Color(0xFF7B3FE4),
    Color(0xFFB45FE9),
  ];
  static const voucherOcean = [darkBlue, Color(0xFF2AA3E8)];
  static const voucherSunset = [dashboardStart, Color(0xFFE8456B)];
  static const voucherAccents = [
    Color(0xFFFF6FB8),
    Color(0xFFFFD166),
    white,
    primary,
  ];
  static const voucherShadowBlur = 8.0;
  static const ticketDash = 4.0;
  static const ticketDashGap = 4.0;
  static const offerHeadingWidth = 210.0;
  static LinearGradient offerTicketGradient({required bool percent}) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: percent
            ? [dashboardStart, dashboardEnd]
            : [brightBlue, darkBlue],
      );
  static const infoBackground = Color(0xFFE3EEFD);
  static const infoDarkBackground = Color(0xFF183354);
  static const infoDarkInk = Color(0xFFD5E5FF);
  static const queuePendingBackground = Color(0xFFFFF1DC);
  static const queuePendingInk = Color(0xFFB86100);
  static const queueInfoBackground = Color(0xFFE3EEFD);
  static const queueInfoInk = Color(0xFF1560C4);
  static const queueReadyBackground = Color(0xFFE3F6EA);
  static const queueReadyInk = Color(0xFF0B7A3B);
  static const dashboardHeroStart = Color(0xFF14213D);
  static const dashboardHeroEnd = Color(0xFF0F1B2E);
  static const dashboardNegative = Color(0xFFD93025);
  static const dashboardCash = Color(0xFF17A590);
  static const dashboardCard = Color(0xFFF59309);
  static const dashboardOther = Color(0xFF98A4BB);
  static const dashboardCompleted = Color(0xFF12A150);
  static const dashboardPending = Color(0xFFF59309);
  static const dashboardCancelled = Color(0xFFD93025);
  static const dashboardRadius = 18.0;
  static const dashboardHeroRadius = 22.0;
  static const dashboardInset = 20.0;
  static const dashboardCardPadding = 14.0;
  static const dashboardBlockGap = 14.0;
  static const dashboardHeroPadding = 18.0;
  static const dashboardHeroAmount = 34.0;
  static const dashboardValueSize = 24.0;
  static const dashboardAvatar = 44.0;
  static const dashboardBarHeight = 14.0;
  static const dashboardSplitBarRadius = 8.0;
  static const dashboardMoreWidth = 140.0;
  static const dashboardMoreAmountHeight = 30.0;
  static const dashboardLabelSize = 12.0;
  static const dashboardTracking = 0.96;
  static const dashboardLegendDot = 5.0;
  static const dashboardBarCorner = 7.0;
  static const dashboardTrackHeight = 5.0;
  static const dashboardRankGap = 3.0;
  static const dashboardRankDivider = 1.0;
  static const dashboardErrorIcon = 14.0;
  static const dashboardChangeOpacity = 0.2;
  static const dashboardChangePaddingX = 10.0;
  static const dashboardChangePaddingY = 6.0;
  static const dashboardTapPadding = 4.0;
  static const dashboardClientGap = 6.0;
  static const dashboardPaymentFallbacks = [dashboardOther, muted, border];
  static const innerHeaderTranslucency = 0.18;
  static const innerHeaderRadius = 22.0;
  static const innerHeaderTop = 16.0;
  static const innerHeaderBottom = 18.0;
  static const innerHeaderHorizontal = 20.0;
  static const innerHeaderTitleSize = 19.0;
  static const innerHeaderGap = 12.0;
  static const innerHeaderStackWidth = 360.0;
  static const innerHeaderTrailingFraction = 0.6;
  static const innerHeaderBadgeSize = 13.0;
  static const homeWidth = 800.0;
  static const homeLargeText = 1.5;
  static const homeInset = 20.0;
  static const homeHeaderBottom = 40.0;
  static const homeOverlap = 8.0;
  static const homeLogo = 42.0;
  static const homeLogoBorderOpacity = 0.33;
  static const homeHeaderGap = 12.0;
  static const homeHeaderRadius = 28.0;
  static const homeTileRadius = 22.0;
  static const homeTilePadding = 22.0;
  static const homeTileGap = 12.0;
  static const homeTitleSize = 18.0;
  static const homeOperationIconSize = 34.0;
  static const homeOperationTextGap = 12.0;
  static const homeOperationSubtitleSize = 13.0;
  static const homeCardRadius = 18.0;
  static const homeCardPadding = 16.0;
  static const homeCardBorderOpacity = 0.2;
  static const homeCardSubtitleOpacity = 0.86;
  static const homeCardIconSize = 44.0;
  static const homeCardIconRadius = 12.0;
  static const homeOffersIconBackground = offersStart;
  static const homeOffersIconDarkBackground = Color(0xFF2B3556);
  static const homeCreditsIconBackground = creditsStart;
  static const homeCreditsIconDarkBackground = Color(0xFF233E4A);
  static const homeMembershipIconBackground = membershipStart;
  static const homeMembershipIconDarkBackground = Color(0xFF44304F);
  static const homeDashboardIconStart = Color(0xFFC2410C);
  static const homeDashboardIconEnd = Color(0xFF9A3412);
  static const homeIconEntranceDuration = Duration(milliseconds: 220);
  static const homeIconEntranceScale = 0.94;
  static const homeIconPressDuration = Duration(milliseconds: 100);
  static const homeIconPressScale = 0.96;
  static const homeIconMotionCurve = Curves.easeOutCubic;
  static const homeCardGlyphSize = 24.0;
  static const homeCardIconGap = 12.0;
  static const homeCardTextGap = 8.0;
  static const homeCardTitleSize = 16.0;
  static const homeCardSubtitleSize = 13.0;
  static const homeGridGap = 12.0;
  static const homeGridMinCardWidth = 160.0;
  static const homeGridTextScaleLimit = 1.3;
  static const homeHeaderCompactWidth = 340.0;
  static const homeSalonChevronSize = 20.0;
  static const homeShopSize = 17.0;
  static const homeBodySize = 15.0;
  static const homeWelcomeSize = 13.0;
  static const homeWelcomeOpacity = 0.85;
  static const homeTextHeight = 1.4;
  static const tileIcon = 34.0;
  static const tileGradientDegrees = 135.0;
  static const operationsStart = Color(0xFF17A590);
  static const operationsEnd = Color(0xFF0B7D6E);
  static LinearGradient tileGradient(Size size, {required bool operations}) {
    return _angledGradient(
      size,
      tileGradientDegrees,
      operations
          ? [operationsStart, operationsEnd]
          : [homeDashboardTileStart, homeDashboardTileEnd],
    );
  }

  static LinearGradient homeHeaderGradient(Size size) =>
      _angledGradient(size, 160.0, [brightBlue, darkBlue]);

  static LinearGradient webTileGradient(Size size, List<Color> colors) =>
      _angledGradient(size, tileGradientDegrees, colors);

  static LinearGradient homeDashboardIconGradient(Size size) => _angledGradient(
    size,
    tileGradientDegrees,
    [homeDashboardIconStart, homeDashboardIconEnd],
  );

  static LinearGradient _angledGradient(
    Size size,
    double degrees,
    List<Color> colors,
  ) {
    final angle = degrees * math.pi / 180;
    final dx = math.sin(angle);
    final dy = -math.cos(angle);
    final length = size.width * dx.abs() + size.height * dy.abs();
    final end = Alignment(dx * length / size.width, dy * length / size.height);
    return LinearGradient(
      begin: Alignment(-end.x, -end.y),
      end: end,
      colors: colors,
    );
  }

  static const loginGradientDegrees = 170.0;
  static const loginGradientColors = [brightBlue, primary, darkBlue];
  static const loginGradientStops = [0.0, 0.45, 1.0];

  /// CSS angle and corner projections, converted to box-relative alignments.
  static LinearGradient loginGradient(Size size) {
    assert(size.width > 0 && size.height > 0 && size.isFinite);
    final angle = loginGradientDegrees * math.pi / 180;
    final dx = math.sin(angle);
    final dy = -math.cos(angle);
    final length = size.width * dx.abs() + size.height * dy.abs();
    final end = Alignment(dx * length / size.width, dy * length / size.height);
    return LinearGradient(
      begin: Alignment(-end.x, -end.y),
      end: end,
      colors: loginGradientColors,
      stops: loginGradientStops,
    );
  }

  static const smallGap = 8.0;
  static const gap = 16.0;
  static const padding = 24.0;
  static const sectionGap = 32.0;
  static const target = 48.0;
  static const minimumCustomerBirthYear = 1900;
  static const formWidth = 480.0;
  static const controlRadius = 12.0;
  static const cardRadius = 24.0;
  static const logoSize = 72.0;
  static const illustrationWidth = 360.0;
  static const illustrationHeight = 100.0;
  static const illustrationOpacity = 0.28;
  static const subtitleOpacity = 0.92;
  static const progressSize = 20.0;
  static const progressStroke = 2.0;
  static const minimumServiceQuantity = 1;
  static const defaultServiceQuantity = 1;
  static const maximumDiscountPercent = 100.0;
  static const titleSize = 30.0;
  static const subtitleSize = 20.0;
  static const titleTracking = 2.0;
  static const bodySize = 16.0;
  static const labelSize = 16.0;
  static const textHeight = 1.4;
  static const errorLines = 4;
  static const outlineWidth = 1.0;
  static const focusOutlineWidth = 2.0;
}
