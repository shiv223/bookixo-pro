import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/brand_background.dart';

enum TileKind { native, webOnly }

/// Tab bindings live alongside the sole key-to-mobile registry.
class QueueTabDefinition {
  const QueueTabDefinition(this.key, this.title, this.selector);
  final String key;
  final String title;
  final String selector;
}

/// Mobile metadata is never copied from API web metadata.
class MobileTileDefinition {
  const MobileTileDefinition(
    this.keys,
    this.title,
    this.subtitle,
    this.icon,
    this.route,
    this.kind,
    this.order, {
    this.tabs = const [],
    this.benefits = const [],
    this.background = BrandBackgroundKind.dashboard,
  });
  final Set<String> keys;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final TileKind kind;
  final int order;
  final List<QueueTabDefinition> tabs;
  final List<String> benefits;
  final BrandBackgroundKind background;
}

abstract final class MobileMenuRegistry {
  static const tiles = [
    MobileTileDefinition(
      {'bookings-pending', 'bookings-in-progress'},
      AppStrings.operations,
      AppStrings.operationsSubtitle,
      Icons.content_cut,
      '/queue',
      TileKind.native,
      10,
      background: BrandBackgroundKind.operations,
      tabs: [
        QueueTabDefinition('bookings-pending', AppStrings.pending, 'pending'),
        QueueTabDefinition(
          'bookings-in-progress',
          AppStrings.inProgress,
          'in-progress',
        ),
      ],
    ),
    MobileTileDefinition(
      {'shopdashboard'},
      AppStrings.homeDashboard,
      AppStrings.dashboardSubtitle,
      Icons.bar_chart,
      '/dashboard',
      TileKind.native,
      20,
    ),
    MobileTileDefinition(
      {'shop-offers-2'},
      AppStrings.offers,
      AppStrings.offersSubtitle,
      Icons.local_offer_outlined,
      '/web/offers',
      TileKind.native,
      30,
      background: BrandBackgroundKind.offers,
      benefits: [AppStrings.offersBenefit],
    ),
    MobileTileDefinition(
      {'shop-credits-packages'},
      AppStrings.creditsPackages,
      AppStrings.webOnly,
      Icons.card_giftcard,
      '/web/credits-packages',
      TileKind.webOnly,
      40,
      background: BrandBackgroundKind.credits,
      benefits: [AppStrings.creditsBenefit],
    ),
    MobileTileDefinition(
      {'shop-memberships'},
      AppStrings.membership,
      AppStrings.webOnly,
      Icons.diamond_outlined,
      '/web/membership',
      TileKind.webOnly,
      50,
      background: BrandBackgroundKind.membership,
      benefits: [AppStrings.membershipBenefit],
    ),
    MobileTileDefinition(
      {'shop-services-list'},
      AppStrings.catalogueServices,
      AppStrings.catalogueSubtitle,
      Icons.design_services_outlined,
      '/services',
      TileKind.native,
      60,
      background: BrandBackgroundKind.services,
    ),
    MobileTileDefinition(
      {'users-shop'},
      AppStrings.shopUsers,
      AppStrings.shopUsersSubtitle,
      Icons.people_outline,
      '/shop-users',
      TileKind.native,
      70,
      background: BrandBackgroundKind.shopUsers,
    ),
    MobileTileDefinition(
      {'shop-setup'},
      AppStrings.shopSettings,
      AppStrings.shopSettingsSubtitle,
      Icons.settings_outlined,
      '/shop-settings',
      TileKind.native,
      80,
      background: BrandBackgroundKind.shopSettings,
    ),
  ];
}

/// Only these mobile-owned children have informational destinations.
class ShopSetupDestination {
  const ShopSetupDestination(this.key, this.title, this.icon);
  final String key;
  final String title;
  final IconData icon;
  String get route => '/shop-settings/$key';
}

abstract final class ShopSetupRegistry {
  static const children = [
    ShopSetupDestination('workday', AppStrings.workday, Icons.calendar_month),
    ShopSetupDestination(
      'shop-gst-settings',
      AppStrings.gstSettings,
      Icons.receipt_long_outlined,
    ),
    ShopSetupDestination(
      'shop-booking-qr',
      AppStrings.bookingQr,
      Icons.qr_code,
    ),
    ShopSetupDestination(
      'shop-payment-config',
      AppStrings.paymentSettings,
      Icons.payment,
    ),
    ShopSetupDestination(
      'shop-logo',
      AppStrings.shopLogo,
      Icons.image_outlined,
    ),
  ];
}
