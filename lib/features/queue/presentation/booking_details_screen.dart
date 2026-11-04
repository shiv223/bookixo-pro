import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';
import '../../auth/domain/role_policy.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/queue_item.dart';
import '../domain/booking_workspace.dart';
import '../domain/booking_service_group.dart';
import 'booking_workspace_controller.dart';
import 'queue_controller.dart';
import '../../menu/presentation/scope_revision_provider.dart';
import '../../shop_context/presentation/salon_switch_guard.dart';

class BookingDetailsScreen extends ConsumerWidget {
  const BookingDetailsScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(authControllerProvider).asData?.value.identity;
    final role = identity?.role;
    final viewer = BookingRolePolicy.modeFor(role ?? AppRole.unknown);
    final actorId = identity?.userId;
    final scope = (bookingId, actorId ?? '');
    final workspace = ref.watch(bookingWorkspaceProvider(scope));
    return Scaffold(
      body: Column(
        children: [
          const AppInnerHeader(
            title: AppStrings.bookingDetails,
            fallbackRoute: '/queue',
          ),
          Expanded(
            child: switch (viewer) {
              BookingViewerMode.unsupported => const Center(
                child: Text(AppStrings.unsupportedBookingRole),
              ),
              BookingViewerMode.employee ||
              BookingViewerMode.owner => workspace.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _LoadFailure(
                  message: error is AppFailure
                      ? error.message
                      : AppStrings.bookingDetailsUnavailable,
                  onRetry: () =>
                      ref.invalidate(bookingWorkspaceProvider(scope)),
                ),
                data: (value) => _BookingWorkspaceContent(
                  key: ValueKey((
                    value.details.id,
                    scope.$2,
                    ref.watch(scopeRevisionProvider),
                  )),
                  workspace: value,
                  viewer: viewer,
                  actorId: value.actorId,
                  actorName: value.actorName,
                  scopeActorId: actorId ?? '',
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppTokens.homeInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppTokens.smallGap),
          FilledButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    ),
  );
}

class _BookingWorkspaceContent extends ConsumerStatefulWidget {
  const _BookingWorkspaceContent({
    required this.workspace,
    required this.viewer,
    required this.actorId,
    required this.actorName,
    required this.scopeActorId,
    super.key,
  });

  final BookingWorkspace workspace;
  final BookingViewerMode viewer;
  final String actorId;
  final String actorName;
  final String scopeActorId;

  @override
  ConsumerState<_BookingWorkspaceContent> createState() =>
      _BookingWorkspaceContentState();
}

class _BookingWorkspaceContentState
    extends ConsumerState<_BookingWorkspaceContent> {
  late List<BookingDraftLine> _lines;
  final _searchController = TextEditingController();
  final _transactionIdController = TextEditingController();
  final _paymentNoteController = TextEditingController();
  final _invalidDiscounts = <String>{};
  final _discountErrors = <String, String>{};
  String _search = '';
  String? _paymentOption;
  BookingPaymentMode? _paymentMode;
  bool _isSaving = false;
  bool _isCompleting = false;
  bool _isEditingOwner = false;
  String? _operationError;
  bool _isDirty = false;
  late final SalonSwitchGuard _switchGuard;
  late final int _scopeRevision;

  bool get _currentScope =>
      mounted && ref.read(scopeRevisionProvider) == _scopeRevision;

  bool get _isOwner => widget.viewer == BookingViewerMode.owner;
  bool get _editingServices => !_isOwner || _isEditingOwner;
  String get _bookingId => widget.workspace.details.id;
  (String, String) get _scope => (_bookingId, widget.scopeActorId);
  OwnerCompletionRequest get _pricingScope => OwnerCompletionRequest(
    bookingId: _bookingId,
    draftRevision: widget.workspace.draft.revision,
    lines: _lines,
  );

  @override
  void initState() {
    super.initState();
    _scopeRevision = ref.read(scopeRevisionProvider);
    _switchGuard = ref.read(salonSwitchGuardProvider);
    _switchGuard.register(
      this,
      () =>
          _isDirty ||
          _invalidDiscounts.isNotEmpty ||
          _paymentMode != null ||
          _transactionIdController.text.isNotEmpty ||
          _paymentNoteController.text.isNotEmpty,
    );
    _lines = widget.viewer == BookingViewerMode.owner
        ? List.of(widget.workspace.draft.lines)
        : widget.workspace.draft.lines
              .where((line) => line.assigneeId == widget.actorId)
              .toList();
  }

  @override
  void didUpdateWidget(covariant _BookingWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.draft.revision != widget.workspace.draft.revision &&
        !_isDirty) {
      _lines = _isOwner
          ? List.of(widget.workspace.draft.lines)
          : widget.workspace.draft.lines
                .where((line) => line.assigneeId == widget.actorId)
                .toList();
    }
  }

  @override
  void dispose() {
    _switchGuard.unregister(this);
    _searchController.dispose();
    _transactionIdController.dispose();
    _paymentNoteController.dispose();
    super.dispose();
  }

  List<BookingDraftLine> get _otherLines => widget.workspace.draft.lines
      .where((line) => line.assigneeId != widget.actorId)
      .toList(growable: false);

  List<BookingDraftLine> get _ownLines => _lines
      .where((line) => line.assigneeId == widget.actorId)
      .toList(growable: false);

  Future<void> _saveServices() async {
    if (_isSaving || _isCompleting || _invalidDiscounts.isNotEmpty) return;
    final finish = _switchGuard.beginRequest();
    setState(() {
      _isSaving = true;
      _operationError = null;
    });
    try {
      final repository = ref.read(bookingRepositoryProvider);
      if (_isOwner) {
        await repository.saveOwnerDraft(
          bookingId: _bookingId,
          expectedRevision: widget.workspace.draft.revision,
          lines: _lines,
        );
      } else {
        await repository.saveOwnLines(
          bookingId: _bookingId,
          actorId: widget.actorId,
          expectedRevision: widget.workspace.draft.revision,
          ownLines: _ownLines,
        );
      }
      if (!mounted || !_currentScope) return;
      ref.invalidate(bookingWorkspaceProvider(_scope));
      if (_isOwner) {
        ref.invalidate(ownerCompletionContextProvider(_pricingScope));
      }
      setState(() {
        _isSaving = false;
        _isDirty = false;
        _isEditingOwner = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.servicesSaved)));
    } on AppFailure catch (failure) {
      if (!mounted || !_currentScope) return;
      if (!_isOwner &&
          failure is ConflictFailure &&
          failure.isRevisionConflict) {
        ref.invalidate(bookingWorkspaceProvider(_scope));
      }
      setState(() {
        _isSaving = false;
        _operationError =
            failure is ConflictFailure &&
                failure.isRevisionConflict &&
                !_isOwner
            ? AppStrings.bookingChanged
            : failure.message;
      });
    } finally {
      finish();
    }
  }

  Future<void> _completePayment() async {
    final mode = _paymentMode;
    if (_isCompleting ||
        _isSaving ||
        mode == null ||
        _isDirty ||
        _invalidDiscounts.isNotEmpty ||
        (mode == BookingPaymentMode.card && _paymentOption == null)) {
      return;
    }
    final finish = _switchGuard.beginRequest();
    setState(() {
      _isCompleting = true;
      _operationError = null;
    });
    var paymentDraftSaved = false;
    try {
      final repository = ref.read(bookingRepositoryProvider);
      final savedDraft = await repository.saveOwnerDraft(
        bookingId: _bookingId,
        expectedRevision: widget.workspace.draft.revision,
        lines: _lines,
        payment: BookingPaymentDraft(
          mode: mode,
          option: _paymentOption,
          transactionId: mode == BookingPaymentMode.upi
              ? _transactionIdController.text.trim()
              : null,
          note: mode == BookingPaymentMode.upi
              ? _paymentNoteController.text.trim()
              : null,
        ),
      );
      paymentDraftSaved = true;
      if (!_currentScope) return;
      await repository.complete(
        bookingId: _bookingId,
        expectedRevision: savedDraft.revision,
      );
      if (!mounted || !_currentScope) return;
      ref.invalidate(bookingWorkspaceProvider(_scope));
      ref.invalidate(ownerCompletionContextProvider(_pricingScope));
      ref.invalidate(queueItemsProvider(QueueTabSelector.pending));
      ref.invalidate(queueItemsProvider(QueueTabSelector.inProgress));
      setState(() {
        _isCompleting = false;
        _isDirty = false;
        _paymentMode = null;
        _paymentOption = null;
        _transactionIdController.clear();
        _paymentNoteController.clear();
      });
    } on AppFailure catch (failure) {
      if (!_currentScope) return;
      if (paymentDraftSaved) {
        ref.invalidate(bookingWorkspaceProvider(_scope));
        ref.invalidate(ownerCompletionContextProvider(_pricingScope));
      }
      setState(() {
        _isCompleting = false;
        _operationError = failure.message;
      });
    } finally {
      finish();
    }
  }

  Future<void> _retryCompletion() async {
    if (_isCompleting || _isSaving) return;
    final finish = _switchGuard.beginRequest();
    setState(() {
      _isCompleting = true;
      _operationError = null;
    });
    try {
      await ref.read(bookingRepositoryProvider).retryCompletion(_bookingId);
      if (!mounted || !_currentScope) return;
      ref.invalidate(bookingWorkspaceProvider(_scope));
      ref.invalidate(ownerCompletionContextProvider(_pricingScope));
      ref.invalidate(queueItemsProvider(QueueTabSelector.pending));
      ref.invalidate(queueItemsProvider(QueueTabSelector.inProgress));
      setState(() => _isCompleting = false);
    } on AppFailure catch (failure) {
      if (!_currentScope) return;
      setState(() {
        _isCompleting = false;
        _operationError = failure.message;
      });
    } finally {
      finish();
    }
  }

  Future<void> _discardDraft() async {
    if (_isSaving || _isCompleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.discardDraft),
        content: const Text(AppStrings.discardDraftConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.keepDraft),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.discardDraft),
          ),
        ],
      ),
    );
    if (confirmed != true || !_currentScope || _isSaving || _isCompleting) {
      return;
    }
    final finish = _switchGuard.beginRequest();
    setState(() {
      _isSaving = true;
      _operationError = null;
    });
    try {
      await ref
          .read(bookingRepositoryProvider)
          .discardDraft(
            bookingId: _bookingId,
            expectedRevision: widget.workspace.draft.revision,
          );
      if (!mounted || !_currentScope) return;
      ref.invalidate(bookingWorkspaceProvider(_scope));
      ref.invalidate(queueItemsProvider(QueueTabSelector.pending));
      ref.invalidate(queueItemsProvider(QueueTabSelector.inProgress));
      setState(() {
        _isSaving = false;
        _isDirty = false;
        _isEditingOwner = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.draftDiscarded)));
    } on AppFailure catch (failure) {
      if (!_currentScope) return;
      setState(() {
        _isSaving = false;
        _operationError = failure.message;
      });
    } finally {
      finish();
    }
  }

  void _addService(BookingService service) {
    final alreadyAddedByOther =
        !_isOwner &&
        widget.workspace.draft.lines.any(
          (line) =>
              line.serviceId == service.id && line.assigneeId != widget.actorId,
        );
    final selected = _lines.any((line) => line.serviceId == service.id);
    if (alreadyAddedByOther || selected) return;
    setState(() {
      _lines = [
        ..._lines,
        BookingDraftLine(
          serviceId: service.id,
          serviceName: service.name,
          quantity: AppTokens.defaultServiceQuantity,
          additionalDiscountPercent: 0,
          assigneeId: widget.actorId,
          assigneeName: widget.actorName,
        ),
      ];
      _isDirty = true;
    });
  }

  void _removeLine(BookingDraftLine line) {
    setState(() {
      _lines = _lines
          .where((item) => item.serviceId != line.serviceId)
          .toList();
      _invalidDiscounts.remove(line.serviceId);
      _discountErrors.remove(line.serviceId);
      _isDirty = true;
    });
  }

  void _updateLine(BookingDraftLine line, BookingDraftLine updated) {
    setState(() {
      _lines = _lines
          .map((item) => item.serviceId == line.serviceId ? updated : item)
          .toList();
      _isDirty = true;
    });
  }

  void _updateDiscount(BookingDraftLine line, String value) {
    final percent = double.tryParse(value);
    final limit = _isOwner
        ? AppTokens.maximumDiscountPercent
        : widget.workspace.employeeDiscountLimitPercent;
    if (percent == null || percent < 0 || percent > limit) {
      setState(() {
        _invalidDiscounts.add(line.serviceId);
        _discountErrors[line.serviceId] = AppStrings.discountInvalid;
      });
      return;
    }
    setState(() {
      _invalidDiscounts.remove(line.serviceId);
      _discountErrors.remove(line.serviceId);
      _lines = _lines
          .map(
            (item) => item.serviceId == line.serviceId
                ? item.copyWith(additionalDiscountPercent: percent)
                : item,
          )
          .toList();
      _isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final draft = workspace.draft;
    final isEditable = draft.status == BookingDraftStatus.editable;
    final ownerContext = _isOwner
        ? ref.watch(ownerCompletionContextProvider(_pricingScope))
        : null;
    return ListView(
      padding: const EdgeInsets.all(AppTokens.homeInset),
      children: [
        if (ref.watch(bookingWorkspaceIsMockProvider)) ...[
          const _MockNotice(),
          const SizedBox(height: AppTokens.smallGap),
        ],
        _CustomerCard(details: workspace.details, draft: draft),
        const SizedBox(height: AppTokens.gap),
        _BookingServiceSection(
          owner: _isOwner,
          editingOwner: _isEditingOwner,
          saving: _isSaving,
          editable: isEditable,
          services: workspace.services,
          selectedLines: _lines,
          draftLines: draft.lines,
          linesToDisplay: _editingServices ? _lines : draft.lines,
          canEditLines: _editingServices && isEditable && !_isSaving,
          actorId: widget.actorId,
          search: _search,
          searchController: _searchController,
          errors: _discountErrors,
          discountLimit: _isOwner
              ? AppTokens.maximumDiscountPercent
              : workspace.employeeDiscountLimitPercent,
          onSearch: (value) => setState(() => _search = value),
          onSelect: _addService,
          onEdit: () => setState(() {
            _isEditingOwner = true;
            _lines = List.of(draft.lines);
          }),
          onCancel: () => setState(() {
            _isEditingOwner = false;
            _lines = List.of(draft.lines);
            _isDirty = false;
            _invalidDiscounts.clear();
            _discountErrors.clear();
          }),
          onQuantity: (line, quantity) =>
              _updateLine(line, line.copyWith(quantity: quantity)),
          onDiscount: _updateDiscount,
          onRemove: _removeLine,
        ),
        if (!_isOwner && _otherLines.isNotEmpty) ...[
          const SizedBox(height: AppTokens.smallGap),
          _OtherStaffLines(lines: _otherLines),
        ],
        if (_isOwner) ...[
          const SizedBox(height: AppTokens.gap),
          _OwnerPaymentArea(
            completionContext:
                ownerContext ?? const AsyncLoading<OwnerCompletionContext>(),
            pricingMatchesRequest:
                ownerContext?.asData?.value.request == _pricingScope,
            selectedMode: _paymentMode,
            selectedOption: _paymentOption,
            transactionIdController: _transactionIdController,
            paymentNoteController: _paymentNoteController,
            busy: _isCompleting,
            draftStatus: draft.status,
            isDirty: _isDirty,
            hasServices: draft.lines.isNotEmpty || _lines.isNotEmpty,
            linesResolvable: _lines.every(
              (line) =>
                  workspace.services.any(
                    (service) => service.id == line.serviceId,
                  ) &&
                  line.assigneeId != null &&
                  line.assigneeName.isNotEmpty,
            ),
            onModeChanged: (mode) => setState(() {
              _paymentMode = mode;
              _paymentOption = null;
            }),
            onOptionChanged: (option) =>
                setState(() => _paymentOption = option),
            onRetryPricing: () =>
                ref.invalidate(ownerCompletionContextProvider(_pricingScope)),
            onComplete:
                draft.status == BookingDraftStatus.completionRecoveryRequired
                ? _retryCompletion
                : _completePayment,
          ),
        ],
        if (_operationError case final error?) ...[
          const SizedBox(height: AppTokens.smallGap),
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        _SaveServicesButton(
          visible:
              draft.status == BookingDraftStatus.editable &&
              (!_isOwner || _isEditingOwner),
          enabled: isEditable && _invalidDiscounts.isEmpty,
          busy: _isSaving,
          label: _isOwner
              ? AppStrings.saveChanges
              : AppStrings.saveServiceCount(_ownLines.length),
          onPressed: _saveServices,
        ),
        if (_isOwner &&
            draft.status == BookingDraftStatus.editable &&
            draft.revision > 0)
          TextButton(
            onPressed: _isSaving || _isCompleting ? null : _discardDraft,
            child: const Text(AppStrings.discardDraft),
          ),
        const SizedBox(height: AppTokens.gap),
      ],
    );
  }
}

class _MockNotice extends StatelessWidget {
  const _MockNotice();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(AppTokens.controlRadius),
    ),
    padding: const EdgeInsets.all(AppTokens.smallGap),
    child: const Text(AppStrings.mockBookingNotice),
  );
}

class _ServiceEditingControls extends StatelessWidget {
  const _ServiceEditingControls({
    required this.owner,
    required this.editing,
    required this.saving,
    required this.editable,
    required this.services,
    required this.lines,
    required this.existingLines,
    required this.actorId,
    required this.search,
    required this.searchController,
    required this.onSearch,
    required this.onSelect,
    required this.onEdit,
    required this.onCancel,
  });

  final bool owner;
  final bool editing;
  final bool saving;
  final bool editable;
  final List<BookingService> services;
  final List<BookingDraftLine> lines;
  final List<BookingDraftLine> existingLines;
  final String actorId;
  final String search;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final ValueChanged<BookingService> onSelect;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (owner && !editing) {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(
          onPressed: editable && !saving ? onEdit : null,
          child: const Text(AppStrings.ownerEditServices),
        ),
      );
    }
    return Column(
      children: [
        if (owner)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: saving ? null : onCancel,
              child: const Text(AppStrings.cancelEditing),
            ),
          ),
        _ServicePicker(
          services: services,
          lines: lines,
          existingLines: existingLines,
          owner: owner,
          actorId: actorId,
          search: search,
          searchController: searchController,
          enabled: !saving && editable,
          onSearch: onSearch,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _BookingServiceSection extends StatelessWidget {
  const _BookingServiceSection({
    required this.owner,
    required this.editingOwner,
    required this.saving,
    required this.editable,
    required this.services,
    required this.selectedLines,
    required this.draftLines,
    required this.linesToDisplay,
    required this.canEditLines,
    required this.actorId,
    required this.search,
    required this.searchController,
    required this.errors,
    required this.discountLimit,
    required this.onSearch,
    required this.onSelect,
    required this.onEdit,
    required this.onCancel,
    required this.onQuantity,
    required this.onDiscount,
    required this.onRemove,
  });

  final bool owner;
  final bool editingOwner;
  final bool saving;
  final bool editable;
  final List<BookingService> services;
  final List<BookingDraftLine> selectedLines;
  final List<BookingDraftLine> draftLines;
  final List<BookingDraftLine> linesToDisplay;
  final bool canEditLines;
  final String actorId;
  final String search;
  final TextEditingController searchController;
  final Map<String, String> errors;
  final double discountLimit;
  final ValueChanged<String> onSearch;
  final ValueChanged<BookingService> onSelect;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final void Function(BookingDraftLine, int) onQuantity;
  final void Function(BookingDraftLine, String) onDiscount;
  final ValueChanged<BookingDraftLine> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ServiceEditingControls(
        owner: owner,
        editing: editingOwner,
        saving: saving,
        editable: editable,
        services: services,
        lines: selectedLines,
        existingLines: draftLines,
        actorId: actorId,
        search: search,
        searchController: searchController,
        onSearch: onSearch,
        onSelect: onSelect,
        onEdit: onEdit,
        onCancel: onCancel,
      ),
      const SizedBox(height: AppTokens.smallGap),
      _SelectedServicesCard(
        lines: linesToDisplay,
        editable: canEditLines,
        errors: errors,
        discountLimit: discountLimit,
        onQuantity: onQuantity,
        onDiscount: onDiscount,
        onRemove: onRemove,
      ),
    ],
  );
}

class _SaveServicesButton extends StatelessWidget {
  const _SaveServicesButton({
    required this.visible,
    required this.enabled,
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  final bool visible;
  final bool enabled;
  final bool busy;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.smallGap),
      child: FilledButton(
        onPressed: enabled && !busy ? onPressed : null,
        child: busy ? const _ButtonSpinner() : Text(label),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.details, required this.draft});

  final BookingDetails details;
  final BookingDraft draft;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppTokens.offerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            details.customerName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.smallGap),
          Text('${AppStrings.servedBy} ${details.assigneeName}'),
          const SizedBox(height: AppTokens.smallGap),
          Text(_draftStatusLabel(draft.status)),
        ],
      ),
    ),
  );
}

class _ServicePicker extends StatelessWidget {
  const _ServicePicker({
    required this.services,
    required this.lines,
    required this.existingLines,
    required this.owner,
    required this.actorId,
    required this.search,
    required this.searchController,
    required this.enabled,
    required this.onSearch,
    required this.onSelect,
  });

  final List<BookingService> services;
  final List<BookingDraftLine> lines;
  final List<BookingDraftLine> existingLines;
  final bool owner;
  final String actorId;
  final String search;
  final TextEditingController searchController;
  final bool enabled;
  final ValueChanged<String> onSearch;
  final ValueChanged<BookingService> onSelect;

  @override
  Widget build(BuildContext context) {
    final usual = BookingServiceGroup.filter(
      services,
      usual: true,
      search: search,
    );
    final other = BookingServiceGroup.filter(
      services,
      usual: false,
      search: search,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.offerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.bookingServices,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.smallGap),
            TextField(
              controller: searchController,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: AppStrings.serviceSearch,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: onSearch,
            ),
            const SizedBox(height: AppTokens.smallGap),
            if (usual.isEmpty && other.isEmpty)
              const Text(AppStrings.noMatchingServices)
            else ...[
              if (usual.isNotEmpty) ...[
                Text(AppStrings.yourUsualServices),
                for (final group in usual)
                  _ServicePickerGroup(group: group, picker: this),
              ],
              if (other.isNotEmpty) ...[
                const SizedBox(height: AppTokens.smallGap),
                Text(AppStrings.bookingServices),
                for (final group in other)
                  _ServicePickerGroup(group: group, picker: this),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ServicePickerGroup extends StatelessWidget {
  const _ServicePickerGroup({required this.group, required this.picker});

  final BookingServiceGroup group;
  final _ServicePicker picker;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (group.name case final name?) ...[
        const SizedBox(height: AppTokens.smallGap),
        Semantics(
          header: true,
          child: Text(name, style: Theme.of(context).textTheme.titleSmall),
        ),
      ],
      Wrap(
        spacing: AppTokens.smallGap,
        children: [
          for (final service in group.services)
            _ServiceChip(
              service: service,
              lines: picker.lines,
              existingLines: picker.existingLines,
              owner: picker.owner,
              actorId: picker.actorId,
              enabled: picker.enabled,
              onSelect: picker.onSelect,
            ),
        ],
      ),
    ],
  );
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    required this.service,
    required this.lines,
    required this.existingLines,
    required this.owner,
    required this.actorId,
    required this.enabled,
    required this.onSelect,
  });

  final BookingService service;
  final List<BookingDraftLine> lines;
  final List<BookingDraftLine> existingLines;
  final bool owner;
  final String actorId;
  final bool enabled;
  final ValueChanged<BookingService> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = lines.any((line) => line.serviceId == service.id);
    final existing = existingLines
        .where((line) => line.serviceId == service.id)
        .firstOrNull;
    final addedByOther =
        !owner && existing != null && existing.assigneeId != actorId;
    return ChoiceChip(
      label: Text(
        !addedByOther
            ? service.name
            : '${service.name} · ${AppStrings.alreadyAddedBy} ${existing.assigneeName}',
      ),
      selected: selected || addedByOther,
      onSelected: enabled && !addedByOther && !selected
          ? (_) => onSelect(service)
          : null,
    );
  }
}

class _SelectedServicesCard extends StatelessWidget {
  const _SelectedServicesCard({
    required this.lines,
    required this.editable,
    required this.errors,
    required this.discountLimit,
    required this.onQuantity,
    required this.onDiscount,
    required this.onRemove,
  });

  final List<BookingDraftLine> lines;
  final bool editable;
  final Map<String, String> errors;
  final double discountLimit;
  final void Function(BookingDraftLine, int) onQuantity;
  final void Function(BookingDraftLine, String) onDiscount;
  final ValueChanged<BookingDraftLine> onRemove;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppTokens.offerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.selectedServices,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.smallGap),
          if (lines.isEmpty)
            const Text(AppStrings.noSelectedServices)
          else
            for (final line in lines) ...[
              _EditableLine(
                line: line,
                editable: editable,
                errors: errors,
                discountLimit: discountLimit,
                onQuantity: onQuantity,
                onDiscount: onDiscount,
                onRemove: onRemove,
              ),
              if (line != lines.last) const Divider(),
            ],
        ],
      ),
    ),
  );
}

class _EditableLine extends StatelessWidget {
  const _EditableLine({
    required this.line,
    required this.editable,
    required this.errors,
    required this.discountLimit,
    required this.onQuantity,
    required this.onDiscount,
    required this.onRemove,
  });

  final BookingDraftLine line;
  final bool editable;
  final Map<String, String> errors;
  final double discountLimit;
  final void Function(BookingDraftLine, int) onQuantity;
  final void Function(BookingDraftLine, String) onDiscount;
  final ValueChanged<BookingDraftLine> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text('${line.serviceName} · ${line.assigneeName}')),
          if (editable)
            IconButton(
              tooltip: AppStrings.removeService,
              onPressed: () => onRemove(line),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      if (editable) ...[
        Row(
          children: [
            Text(AppStrings.serviceQuantity),
            IconButton(
              tooltip: AppStrings.decreaseQuantity,
              onPressed: line.quantity > AppTokens.minimumServiceQuantity
                  ? () => onQuantity(line, line.quantity - 1)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Text('${line.quantity}'),
            IconButton(
              tooltip: AppStrings.increaseQuantity,
              onPressed: () => onQuantity(line, line.quantity + 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        TextFormField(
          key: ValueKey('discount-${line.serviceId}'),
          initialValue: line.additionalDiscountPercent == 0
              ? ''
              : line.additionalDiscountPercent.toString(),
          enabled: editable,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: AppStrings.employeeDiscount,
            suffixText: '%',
            helperText: AppStrings.discountLimitHint(discountLimit),
            errorText: errors[line.serviceId],
          ),
          onChanged: (value) => onDiscount(line, value.isEmpty ? '0' : value),
        ),
      ],
    ],
  );
}

class _OtherStaffLines extends StatelessWidget {
  const _OtherStaffLines({required this.lines});

  final List<BookingDraftLine> lines;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppTokens.offerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.otherStaffLines,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.smallGap),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppTokens.smallGap / 2,
              ),
              child: Text(
                '${line.serviceName} · ${line.assigneeName} · ${AppStrings.readOnly}',
              ),
            ),
        ],
      ),
    ),
  );
}

class _OwnerPaymentArea extends StatelessWidget {
  const _OwnerPaymentArea({
    required this.completionContext,
    required this.pricingMatchesRequest,
    required this.selectedMode,
    required this.selectedOption,
    required this.transactionIdController,
    required this.paymentNoteController,
    required this.busy,
    required this.draftStatus,
    required this.isDirty,
    required this.hasServices,
    required this.linesResolvable,
    required this.onModeChanged,
    required this.onOptionChanged,
    required this.onRetryPricing,
    required this.onComplete,
  });

  final AsyncValue<OwnerCompletionContext> completionContext;
  final bool pricingMatchesRequest;
  final BookingPaymentMode? selectedMode;
  final String? selectedOption;
  final TextEditingController transactionIdController;
  final TextEditingController paymentNoteController;
  final bool busy;
  final BookingDraftStatus draftStatus;
  final bool isDirty;
  final bool hasServices;
  final bool linesResolvable;
  final ValueChanged<BookingPaymentMode> onModeChanged;
  final ValueChanged<String?> onOptionChanged;
  final VoidCallback onRetryPricing;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final ownerContext = completionContext.asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        completionContext.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(AppTokens.gap),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.offerPadding),
              child: Column(
                children: [
                  Text(
                    error is AppFailure
                        ? error.message
                        : AppStrings.pricingUnavailable,
                  ),
                  TextButton(
                    onPressed: onRetryPricing,
                    child: const Text(AppStrings.retry),
                  ),
                ],
              ),
            ),
          ),
          data: (value) => switch (value.pricing) {
            null => const Card(
              child: Padding(
                padding: EdgeInsets.all(AppTokens.offerPadding),
                child: Text(AppStrings.pricingRequiresService),
              ),
            ),
            final pricing => _PricingCard(
              result: pricing,
              currencySymbol: value.paymentConfig.currencySymbol,
            ),
          },
        ),
        if (draftStatus == BookingDraftStatus.completionRecoveryRequired) ...[
          _CompletionStatus(
            label: AppStrings.completionRecovery,
            actionLabel: AppStrings.retryCompletion,
            busy: busy,
            onAction: onComplete,
          ),
        ] else if (draftStatus == BookingDraftStatus.completionPending) ...[
          const _CompletionStatus(label: AppStrings.completionAwaitingPayment),
        ] else if (draftStatus == BookingDraftStatus.completed) ...[
          const _CompletionStatus(label: AppStrings.bookingCompleted),
        ] else ...[
          if (hasServices && !linesResolvable)
            const Padding(
              padding: EdgeInsets.only(top: AppTokens.smallGap),
              child: Text(AppStrings.bookingLineUnavailable),
            ),
          if (ownerContext != null)
            _OwnerPaymentControls(
              config: ownerContext.paymentConfig,
              selectedMode: selectedMode,
              selectedOption: selectedOption,
              transactionIdController: transactionIdController,
              paymentNoteController: paymentNoteController,
              busy: busy,
              isDirty: isDirty,
              hasServices: hasServices,
              linesResolvable: linesResolvable,
              pricingMatchesRequest: pricingMatchesRequest,
              onModeChanged: onModeChanged,
              onOptionChanged: onOptionChanged,
              onComplete: onComplete,
            ),
        ],
      ],
    );
  }
}

class _CompletionStatus extends StatelessWidget {
  const _CompletionStatus({
    required this.label,
    this.actionLabel,
    this.busy = false,
    this.onAction,
  });

  final String label;
  final String? actionLabel;
  final bool busy;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppTokens.smallGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        if (actionLabel != null) ...[
          const SizedBox(height: AppTokens.smallGap),
          FilledButton(
            onPressed: busy ? null : onAction,
            child: busy
                ? const _ButtonSpinner()
                : Text(actionLabel ?? AppStrings.retryCompletion),
          ),
        ],
      ],
    ),
  );
}

class _OwnerPaymentControls extends StatelessWidget {
  const _OwnerPaymentControls({
    required this.config,
    required this.selectedMode,
    required this.selectedOption,
    required this.transactionIdController,
    required this.paymentNoteController,
    required this.busy,
    required this.isDirty,
    required this.hasServices,
    required this.linesResolvable,
    required this.pricingMatchesRequest,
    required this.onModeChanged,
    required this.onOptionChanged,
    required this.onComplete,
  });

  final BookingPaymentConfig config;
  final BookingPaymentMode? selectedMode;
  final String? selectedOption;
  final TextEditingController transactionIdController;
  final TextEditingController paymentNoteController;
  final bool busy;
  final bool isDirty;
  final bool hasServices;
  final bool linesResolvable;
  final bool pricingMatchesRequest;
  final ValueChanged<BookingPaymentMode> onModeChanged;
  final ValueChanged<String?> onOptionChanged;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _PaymentMethodFields(
        config: config,
        selectedMode: selectedMode,
        selectedOption: selectedOption,
        transactionIdController: transactionIdController,
        paymentNoteController: paymentNoteController,
        busy: busy,
        onModeChanged: onModeChanged,
        onOptionChanged: onOptionChanged,
      ),
      if (isDirty) ...[
        const SizedBox(height: AppTokens.smallGap),
        const Text(AppStrings.pricingOutOfDate),
      ],
      const SizedBox(height: AppTokens.smallGap),
      _CompletePaymentButton(
        selectedMode: selectedMode,
        selectedOption: selectedOption,
        busy: busy,
        isDirty: isDirty,
        hasServices: hasServices,
        linesResolvable: linesResolvable,
        pricingMatchesRequest: pricingMatchesRequest,
        onComplete: onComplete,
      ),
    ],
  );
}

class _PaymentMethodFields extends StatelessWidget {
  const _PaymentMethodFields({
    required this.config,
    required this.selectedMode,
    required this.selectedOption,
    required this.transactionIdController,
    required this.paymentNoteController,
    required this.busy,
    required this.onModeChanged,
    required this.onOptionChanged,
  });

  final BookingPaymentConfig config;
  final BookingPaymentMode? selectedMode;
  final String? selectedOption;
  final TextEditingController transactionIdController;
  final TextEditingController paymentNoteController;
  final bool busy;
  final ValueChanged<BookingPaymentMode> onModeChanged;
  final ValueChanged<String?> onOptionChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: AppTokens.gap),
      Text(
        AppStrings.paymentMode,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppTokens.smallGap),
      Wrap(
        spacing: AppTokens.smallGap,
        children: [
          for (final mode in config.enabledModes)
            ChoiceChip(
              label: Text(_paymentModeLabel(mode)),
              selected: selectedMode == mode,
              onSelected: busy ? null : (_) => onModeChanged(mode),
            ),
        ],
      ),
      if (selectedMode == BookingPaymentMode.card) ...[
        const SizedBox(height: AppTokens.smallGap),
        DropdownButtonFormField<String>(
          key: ValueKey(selectedOption),
          initialValue: selectedOption,
          decoration: const InputDecoration(
            labelText: AppStrings.paymentOption,
          ),
          items: [
            for (final option in config.cardOptions)
              DropdownMenuItem(value: option.code, child: Text(option.label)),
          ],
          onChanged: busy ? null : onOptionChanged,
        ),
      ],
      if (selectedMode == BookingPaymentMode.upi) ...[
        const SizedBox(height: AppTokens.smallGap),
        TextField(
          controller: transactionIdController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: AppStrings.paymentTransactionId,
            helperText: AppStrings.optional,
          ),
        ),
        const SizedBox(height: AppTokens.smallGap),
        TextField(
          controller: paymentNoteController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: AppStrings.paymentNote,
            helperText: AppStrings.optional,
          ),
        ),
      ],
    ],
  );
}

class _CompletePaymentButton extends StatelessWidget {
  const _CompletePaymentButton({
    required this.selectedMode,
    required this.selectedOption,
    required this.busy,
    required this.isDirty,
    required this.hasServices,
    required this.linesResolvable,
    required this.pricingMatchesRequest,
    required this.onComplete,
  });

  final BookingPaymentMode? selectedMode;
  final String? selectedOption;
  final bool busy;
  final bool isDirty;
  final bool hasServices;
  final bool linesResolvable;
  final bool pricingMatchesRequest;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed:
        busy ||
            isDirty ||
            !hasServices ||
            !linesResolvable ||
            !pricingMatchesRequest ||
            selectedMode == null ||
            (selectedMode == BookingPaymentMode.card && selectedOption == null)
        ? null
        : onComplete,
    child: busy
        ? const _ButtonSpinner()
        : const Text(AppStrings.completePayment),
  );
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.result, required this.currencySymbol});

  final OwnerPricingResult result;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppTokens.offerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.bookingServices,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.smallGap),
          _PricingLines(lines: result.lines, currencySymbol: currencySymbol),
          const Divider(),
          _PricingSummary(result: result, currencySymbol: currencySymbol),
          if (result.hasActiveMembership && !result.membershipApplied)
            _MembershipPricingNote(
              name: result.membershipName ?? AppStrings.membership,
            ),
          if (result.appliedRules.isNotEmpty)
            _AppliedPricingRules(rules: result.appliedRules),
        ],
      ),
    ),
  );
}

class _PricingLines extends StatelessWidget {
  const _PricingLines({required this.lines, required this.currencySymbol});

  final List<OwnerPricingLine> lines;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final line in lines)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.smallGap / 2),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.serviceName} · ${line.quantity} · ${line.assigneeName}',
                    ),
                  ),
                  Text(_money(line.subtotal, currencySymbol)),
                ],
              ),
              if (line.additionalDiscountAmount > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppStrings.lineDiscount(
                      line.additionalDiscountPercent,
                      _money(line.additionalDiscountAmount, currencySymbol),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

class _PricingSummary extends StatelessWidget {
  const _PricingSummary({required this.result, required this.currencySymbol});

  final OwnerPricingResult result;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (result.subtotal > 0)
        _MoneyRow(
          label: AppStrings.subtotal,
          amount: result.subtotal,
          currencySymbol: currencySymbol,
        ),
      if (result.employeeDiscount > 0)
        _MoneyRow(
          label: AppStrings.employeeDiscountSummary,
          amount: -result.employeeDiscount,
          currencySymbol: currencySymbol,
        ),
      if (result.otherDiscounts > 0)
        _MoneyRow(
          label: AppStrings.otherDiscounts,
          amount: -result.otherDiscounts,
          currencySymbol: currencySymbol,
        ),
      if (result.gstApplied && result.gstAmount > 0)
        _MoneyRow(
          label:
              '${AppStrings.gst} (${result.gstPercent}% ${result.gstIncluded ? AppStrings.included : AppStrings.added})',
          amount: result.gstAmount,
          currencySymbol: currencySymbol,
        ),
      const Divider(),
      _MoneyRow(
        label: AppStrings.finalAmount,
        amount: result.finalAmount,
        currencySymbol: currencySymbol,
        emphasized: true,
      ),
    ],
  );
}

class _MembershipPricingNote extends StatelessWidget {
  const _MembershipPricingNote({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppTokens.smallGap),
    child: Text(
      '$name · ${AppStrings.membershipNoDiscount}',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _AppliedPricingRules extends StatelessWidget {
  const _AppliedPricingRules({required this.rules});

  final List<String> rules;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text(AppStrings.appliedPricingRules),
    subtitle: Text(AppStrings.appliedPricingRuleCount(rules.length)),
    children: [
      for (final rule in rules)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(rule),
        ),
    ],
  );
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amount,
    required this.currencySymbol,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final String currencySymbol;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTokens.smallGap / 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasized
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          _money(amount, currencySymbol),
          style: emphasized
              ? Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)
              : null,
        ),
      ],
    ),
  );
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: AppTokens.progressSize,
    child: CircularProgressIndicator(
      strokeWidth: AppTokens.progressStroke,
      color: AppTokens.white,
    ),
  );
}

String _money(double amount, String currencySymbol) =>
    '$currencySymbol${amount.toStringAsFixed(2)}';

String _draftStatusLabel(BookingDraftStatus status) => switch (status) {
  BookingDraftStatus.editable => AppStrings.inProgress,
  BookingDraftStatus.completionPending => AppStrings.completionAwaitingPayment,
  BookingDraftStatus.completionRecoveryRequired =>
    AppStrings.completionRecovery,
  BookingDraftStatus.completed => AppStrings.bookingCompleted,
};

String _paymentModeLabel(BookingPaymentMode mode) => switch (mode) {
  BookingPaymentMode.cash => AppStrings.cash,
  BookingPaymentMode.card => AppStrings.card,
  BookingPaymentMode.upi => AppStrings.upi,
  BookingPaymentMode.bookixo => AppStrings.bookixo,
};
