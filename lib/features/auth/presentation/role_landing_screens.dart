import 'package:flutter/material.dart';

import 'unsupported_role_screen.dart';

/// Only the existing unsupported-account gate remains role-related.
final Map<String, WidgetBuilder> roleLandingBuilders = {
  '/unsupported': (_) => const UnsupportedRoleScreen(),
};
