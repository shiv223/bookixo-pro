import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../domain/queue_item.dart';
import 'booking_flow_controller.dart';
import 'queue_controller.dart';
import '../../shop_context/presentation/salon_switch_guard.dart';
import '../../menu/presentation/scope_revision_provider.dart';

/// Walk-in uses the selected repository; failed lookup never blocks creation.
class NewBookingScreen extends StatelessWidget {
  const NewBookingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ProviderScope(child: _NewBookingForm());
}

class _NewBookingForm extends ConsumerStatefulWidget {
  const _NewBookingForm();

  @override
  ConsumerState<_NewBookingForm> createState() => _NewBookingFormState();
}

class _NewBookingFormState extends ConsumerState<_NewBookingForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _gender;
  DateTime? _dateOfBirth;
  bool _startImmediately = true;
  String? _lookedUpPhone;
  late final SalonSwitchGuard _switchGuard;
  late final int _scopeRevision;

  bool get _currentScope =>
      mounted && ref.read(scopeRevisionProvider) == _scopeRevision;

  @override
  void initState() {
    super.initState();
    _scopeRevision = ref.read(scopeRevisionProvider);
    _switchGuard = ref.read(salonSwitchGuardProvider);
    _switchGuard.register(
      this,
      () =>
          _phoneController.text.isNotEmpty ||
          _firstNameController.text.isNotEmpty ||
          _lastNameController.text.isNotEmpty ||
          _gender != null ||
          _dateOfBirth != null ||
          !_startImmediately,
    );
    // Providers cannot be modified while the widget tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(bookingFlowControllerProvider.notifier).startNewBooking();
      }
    });
  }

  @override
  void dispose() {
    _switchGuard.unregister(this);
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _lookup(String phoneNumber) async {
    _lookedUpPhone = phoneNumber;
    await ref
        .read(bookingFlowControllerProvider.notifier)
        .lookupCustomer(phoneNumber);
    // A newer number may have been typed while this lookup was running.
    if (!_currentScope || _lookedUpPhone != phoneNumber) return;
    final flow = ref.read(bookingFlowControllerProvider);
    if (flow.lookupStatus == CustomerLookupStatus.found) {
      final customer = flow.customer;
      if (customer == null) return;
      setState(() {
        _firstNameController.text = customer.firstName;
        _lastNameController.text = customer.lastName;
        _gender = customer.gender;
        _dateOfBirth = customer.dateOfBirth;
      });
    } else if (flow.lookupStatus == CustomerLookupStatus.newCustomer) {
      setState(() {
        _firstNameController.clear();
        _lastNameController.clear();
        _gender = null;
        _dateOfBirth = null;
      });
    }
  }

  /// Looks the customer up once, as soon as the number is a full 10 digits.
  void _onPhoneChanged(String value) {
    final phoneNumber = completeIndianPhone(value);
    if (phoneNumber == _lookedUpPhone) return;
    if (_lookedUpPhone != null) {
      _lookedUpPhone = null;
      ref.read(bookingFlowControllerProvider.notifier).clearLookup();
    }
    if (phoneNumber != null) _lookup(phoneNumber);
  }

  void _retryLookup() {
    final phoneNumber = completeIndianPhone(_phoneController.text);
    if (phoneNumber != null) _lookup(phoneNumber);
  }

  Future<void> _selectDateOfBirth() async {
    final today = ref.read(clockProvider).now();
    final latestDate = DateTime(today.year, today.month, today.day);
    final currentDate = _dateOfBirth;
    final selected = await showDatePicker(
      context: context,
      initialDate: currentDate == null || currentDate.isAfter(latestDate)
          ? latestDate
          : currentDate,
      firstDate: DateTime(AppTokens.minimumCustomerBirthYear),
      lastDate: latestDate,
      helpText: AppStrings.dateOfBirth,
    );
    if (!_currentScope || selected == null) return;
    setState(() {
      _dateOfBirth = DateTime(selected.year, selected.month, selected.day);
    });
  }

  Future<void> _create() async {
    final controller = ref.read(bookingFlowControllerProvider.notifier);
    final initialFlow = ref.read(bookingFlowControllerProvider);
    if (initialFlow.createdBooking != null) {
      final started = await controller.startCreatedBooking();
      if (!_currentScope) return;
      if (started != null) {
        _invalidateQueue();
        _openQueue(started);
      }
      return;
    }
    if (_formKey.currentState?.validate() != true) return;
    final today = ref.read(clockProvider).now();
    final dateOfBirth = _dateOfBirth;
    if (dateOfBirth != null && dateOfBirth.isAfter(today)) {
      controller.showValidationError(AppStrings.dateCannotBeFuture);
      return;
    }
    final created = await controller.createWalkIn(
      NewBookingRequest(
        phoneNumber: _phoneController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        gender: _gender,
        dateOfBirth: dateOfBirth,
      ),
      startImmediately: _startImmediately,
    );
    if (!_currentScope) return;
    final flow = ref.read(bookingFlowControllerProvider);
    if (flow.createdBooking != null) _invalidateQueue();
    if (created != null) _openQueue(created);
  }

  void _invalidateQueue() {
    ref.invalidate(queueItemsProvider(QueueTabSelector.pending));
    ref.invalidate(queueItemsProvider(QueueTabSelector.inProgress));
  }

  void _openQueue(QueueItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item.status == QueueBookingStatus.inProgress
              ? AppStrings.bookingStarted
              : AppStrings.bookingCreated,
        ),
      ),
    );
    final tab = item.status == QueueBookingStatus.pending
        ? QueueTabSelector.pending
        : QueueTabSelector.inProgress;
    context.go(Uri(path: '/queue', queryParameters: {'tab': tab}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canCreateWalkInProvider);
    final flow = ref.watch(bookingFlowControllerProvider);
    final dateOfBirth = _dateOfBirth;
    final errorMessage = flow.errorMessage;
    return Scaffold(
      body: Column(
        children: [
          AppInnerHeader(
            title: AppStrings.newBooking,
            onBack: () => context.go('/queue'),
          ),
          Expanded(
            child: !canCreate
                ? const Center(child: Text(AppStrings.noAccess))
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(AppTokens.homeInset),
                      children: [
                        TextFormField(
                          key: const ValueKey('booking-phone'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: AppStrings.phoneNumber,
                          ),
                          onChanged: _onPhoneChanged,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? AppStrings.phoneRequired
                              : completeIndianPhone(value) == null
                              ? AppStrings.phoneInvalid
                              : null,
                        ),
                        if (flow.lookupStatus != CustomerLookupStatus.idle) ...[
                          const SizedBox(height: AppTokens.smallGap),
                          _LookupNotice(
                            state: flow.lookupStatus,
                            onRetry: _retryLookup,
                          ),
                        ],
                        const SizedBox(height: AppTokens.gap),
                        TextFormField(
                          key: const ValueKey('booking-first-name'),
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: AppStrings.firstName,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? AppStrings.firstNameRequired
                              : null,
                        ),
                        const SizedBox(height: AppTokens.smallGap),
                        TextFormField(
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: AppStrings.lastName,
                            helperText: AppStrings.optional,
                          ),
                        ),
                        const SizedBox(height: AppTokens.gap),
                        Text(
                          AppStrings.gender,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppTokens.smallGap),
                        Wrap(
                          spacing: AppTokens.smallGap,
                          children: [
                            for (final option in _genderOptions)
                              ChoiceChip(
                                label: Text(option),
                                selected: _gender == option,
                                onSelected: (selected) => setState(
                                  () => _gender = selected ? option : null,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.gap),
                        Text(
                          AppStrings.dateOfBirth,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppTokens.smallGap),
                        OutlinedButton.icon(
                          onPressed: _selectDateOfBirth,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            dateOfBirth == null
                                ? AppStrings.optional
                                : AppStrings.offerDate(dateOfBirth),
                          ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _startImmediately,
                          title: const Text(AppStrings.startServiceImmediately),
                          onChanged:
                              flow.isCreating ||
                                  flow.startingBookingId != null ||
                                  flow.createdBooking != null
                              ? null
                              : (value) => setState(
                                  () => _startImmediately = value ?? false,
                                ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: AppTokens.smallGap),
                          Text(
                            errorMessage,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppTokens.gap),
                        FilledButton(
                          onPressed:
                              flow.isCreating || flow.startingBookingId != null
                              ? null
                              : _create,
                          child:
                              flow.isCreating || flow.startingBookingId != null
                              ? const SizedBox.square(
                                  dimension: AppTokens.progressSize,
                                  child: CircularProgressIndicator(
                                    strokeWidth: AppTokens.progressStroke,
                                    color: AppTokens.white,
                                  ),
                                )
                              : Text(
                                  flow.createdBooking == null
                                      ? AppStrings.createBooking
                                      : AppStrings.startBooking,
                                ),
                        ),
                        const SizedBox(height: AppTokens.gap),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

const _genderOptions = [AppStrings.genderMale, AppStrings.genderFemale];

class _LookupNotice extends StatelessWidget {
  const _LookupNotice({required this.state, required this.onRetry});

  final CustomerLookupStatus state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (message, color) = switch (state) {
      CustomerLookupStatus.loading => (
        AppStrings.lookupInProgress,
        AppTokens.muted,
      ),
      CustomerLookupStatus.found => (
        AppStrings.customerFound,
        AppTokens.success,
      ),
      CustomerLookupStatus.newCustomer => (
        AppStrings.newCustomerNotice,
        AppTokens.accent,
      ),
      CustomerLookupStatus.failed => (
        AppStrings.lookupFailedCreateAnyway,
        Theme.of(context).colorScheme.error,
      ),
      CustomerLookupStatus.idle => ('', AppTokens.muted),
    };
    final notice = Semantics(
      liveRegion: true,
      child: Text(message, style: TextStyle(color: color)),
    );
    if (state != CustomerLookupStatus.failed) return notice;
    return Row(
      children: [
        Expanded(child: notice),
        TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
      ],
    );
  }
}
