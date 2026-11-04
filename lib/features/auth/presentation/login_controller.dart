import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../domain/auth_models.dart';
import '../domain/login_identifier.dart';
import 'auth_controller.dart';

/// Form-specific feedback; passwords are never held in provider state.
class LoginFeedback {
  const LoginFeedback({this.identifierError, this.passwordError, this.message});
  final String? identifierError;
  final String? passwordError;
  final String? message;
}

final loginControllerProvider =
    AsyncNotifierProvider<LoginController, LoginFeedback>(
      LoginController.new,
      retry: (_, _) => null,
    );

class LoginController extends AsyncNotifier<LoginFeedback> {
  @override
  LoginFeedback build() => const LoginFeedback();

  Future<void> submit(String identifier, String password) async {
    if (state.isLoading) return;
    final identifierError = LoginIdentifier.isValid(identifier)
        ? null
        : AppStrings.identifierRequired;
    final passwordError = password.isEmpty ? AppStrings.passwordRequired : null;
    if (identifierError != null || passwordError != null) {
      state = AsyncData(
        LoginFeedback(
          identifierError: identifierError,
          passwordError: passwordError,
        ),
      );
      return;
    }
    state = const AsyncLoading();
    try {
      final outcome = await ref
          .read(authControllerProvider.notifier)
          .signIn(identifier.trim(), password);
      if (!ref.mounted) return;
      state = AsyncData(
        LoginFeedback(
          message: outcome is ActionRequired ? AppStrings.challenge : null,
        ),
      );
    } on AppFailure catch (e, s) {
      if (!ref.mounted) return;
      state = AsyncError(e, s);
    }
  }
}
