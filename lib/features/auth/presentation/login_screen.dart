import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import 'auth_dependencies.dart';
import 'auth_controller.dart';
import 'login_controller.dart';
import 'login_branding.dart';

/// Accessible sign-in form without a local role chooser.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    return _LoginLayout(
      form: _LoginForm(
        identifier: _identifier,
        password: _password,
        state: state,
        submit: _submit,
        demo: ref.watch(configProvider).demo,
        actionRequired:
            ref.watch(authControllerProvider).asData?.value.actionRequired ??
            false,
      ),
    );
  }

  void _submit() => ref
      .read(loginControllerProvider.notifier)
      .submit(_identifier.text, _password.text);
}

class _LoginLayout extends StatelessWidget {
  const _LoginLayout({required this.form});
  final Widget form;

  @override
  Widget build(BuildContext context) {
    // Scaffold removes the consumed keyboard inset from its resized body.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, bounds) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppTokens.loginGradient(bounds.biggest),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppTokens.padding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - AppTokens.padding * 2)
                        .clamp(0, double.infinity),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const LoginBranding(),
                          const SizedBox(height: AppTokens.sectionGap),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: AppTokens.formWidth,
                              ),
                              child: Theme(
                                data: AppTheme.loginForm,
                                child: form,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!keyboardOpen)
                        const Padding(
                          padding: EdgeInsets.only(top: AppTokens.sectionGap),
                          child: LoginToolsIllustration(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.identifier,
    required this.password,
    required this.state,
    required this.submit,
    required this.demo,
    required this.actionRequired,
  });
  final TextEditingController identifier;
  final TextEditingController password;
  final AsyncValue<LoginFeedback> state;
  final VoidCallback submit;
  final bool demo;
  final bool actionRequired;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppTokens.padding),
      child: AutofillGroup(
        child: Column(
          children: [
            if (demo) const Text(AppStrings.demo),
            _CredentialsFields(
              identifier: identifier,
              password: password,
              enabled: !state.isLoading,
              feedback: state.asData?.value,
              submit: submit,
            ),
            const SizedBox(height: AppTokens.gap),
            _SubmissionFeedback(
              state: state,
              onSubmit: submit,
              actionRequired: actionRequired,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CredentialsFields extends StatefulWidget {
  const _CredentialsFields({
    required this.identifier,
    required this.password,
    required this.enabled,
    required this.feedback,
    required this.submit,
  });
  final TextEditingController identifier;
  final TextEditingController password;
  final bool enabled;
  final LoginFeedback? feedback;
  final VoidCallback submit;
  @override
  State<_CredentialsFields> createState() => _CredentialsFieldsState();
}

class _CredentialsFieldsState extends State<_CredentialsFields> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        controller: widget.identifier,
        enabled: widget.enabled,
        autocorrect: false,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: AppStrings.loginIdentifier,
          errorText: widget.feedback?.identifierError,
        ),
      ),
      const SizedBox(height: AppTokens.gap),
      TextField(
        controller: widget.password,
        enabled: widget.enabled,
        obscureText: _obscurePassword,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => widget.submit(),
        decoration: InputDecoration(
          labelText: AppStrings.password,
          errorText: widget.feedback?.passwordError,
          suffixIcon: IconButton(
            tooltip: _obscurePassword
                ? AppStrings.showPassword
                : AppStrings.hidePassword,
            onPressed: widget.enabled
                ? () => setState(() => _obscurePassword = !_obscurePassword)
                : null,
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
    ],
  );
}

class _SubmissionFeedback extends StatelessWidget {
  const _SubmissionFeedback({
    required this.state,
    required this.onSubmit,
    required this.actionRequired,
  });
  final AsyncValue<LoginFeedback> state;
  final VoidCallback onSubmit;
  final bool actionRequired;
  @override
  Widget build(BuildContext context) {
    final failure = state.error;
    final message = state.asData?.value.message;
    return Column(
      children: [
        if (failure != null)
          _InlineFeedback(
            message: failure is UnauthorizedFailure
                ? AppStrings.invalidCredentials
                : failure is AppFailure
                ? failure.message
                : AppStrings.unknown,
          ),
        if (message != null) _InlineFeedback(message: message),
        if (actionRequired && message == null)
          const _InlineFeedback(message: AppStrings.challenge),
        const SizedBox(height: AppTokens.gap),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: state.isLoading ? null : onSubmit,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.isLoading) ...[
                  const SizedBox(
                    width: AppTokens.progressSize,
                    height: AppTokens.progressSize,
                    child: CircularProgressIndicator(
                      strokeWidth: AppTokens.progressStroke,
                    ),
                  ),
                  const SizedBox(width: AppTokens.smallGap),
                ],
                Flexible(
                  child: Text(
                    state.isLoading
                        ? AppStrings.signingIn
                        : failure != null
                        ? AppStrings.retry
                        : AppStrings.login,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineFeedback extends StatelessWidget {
  const _InlineFeedback({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.error),
    ),
  );
}
