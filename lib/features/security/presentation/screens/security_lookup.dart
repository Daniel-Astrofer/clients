import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/utils/app_date_time.dart';
import 'package:kerosene/design_system/kerosene_design_system.dart';

bool securityLookupIsCurrent<T>(AsyncValue<T> source) =>
    source.hasValue && !source.isLoading && !source.hasError;

/// Account-local presentation metadata, never an authorization source.
/// Retained by the screen so hiding sensitive content does not erase the lookup.
class SecurityLookup<T> {
  String? _scope;
  T? _last;
  Object? _observedResponse;
  Object? _discardedResponse;
  Object? _acceptedResponse;
  bool _waiting = true;
  DateTime? _checkedAt;
  bool current = false;
  bool loading = true;
  bool failed = false;

  T? get last => _last;
  DateTime? get checkedAt => _checkedAt;

  void observe(String? scope, AsyncValue<T> source, {DateTime? now}) {
    scope = scope?.trim();
    if (_scope != scope) {
      _discardedResponse = _observedResponse;
      _scope = scope;
      _last = null;
      _checkedAt = null;
      _acceptedResponse = null;
      _waiting = true;
    }
    loading = source.isLoading;
    failed = source.hasError;
    current = scope?.isNotEmpty == true &&
        securityLookupIsCurrent(source) &&
        !identical(source, _discardedResponse);
    if (loading) _waiting = true;
    if (current && (_waiting || !identical(source, _acceptedResponse))) {
      _last = source.requireValue;
      _checkedAt = now ?? DateTime.now();
      _acceptedResponse = source;
      _waiting = false;
    }
    _observedResponse = source;
  }
}

/// One update notice, with individually identified last successful lookups.
/// Missing responses are never represented as disabled protection or zero codes.
class SecurityLookupNotice extends StatelessWidget {
  final List<({String label, SecurityLookup<Object?> lookup})> sources;
  final VoidCallback? onRetry;
  final String retryKey;
  final String? failureMessage;
  final String? updatingMessage;
  const SecurityLookupNotice(
      {super.key,
      required this.sources,
      required this.onRetry,
      this.retryKey = 'security-lookup-retry',
      this.failureMessage,
      this.updatingMessage});

  @override
  Widget build(BuildContext context) {
    final stale = sources.where((item) => !item.lookup.current).toList();
    if (stale.isEmpty ||
        !sources
            .any((item) => item.lookup.last != null || item.lookup.failed)) {
      return const SizedBox.shrink();
    }
    final updating =
        stale.every((item) => item.lookup.loading && !item.lookup.failed);
    final tr = context.tr;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KeroseneIcon(updating ? KeroseneIcons.sync : KeroseneIcons.warning,
            size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(
                  updating
                      ? (updatingMessage ?? tr.securityProfileUpdating)
                      : (failureMessage ?? tr.securityProfileStale),
                  style: Theme.of(context).textTheme.bodyMedium),
              for (final item in stale)
                if (item.lookup.checkedAt != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          '${item.label} · ${tr.securityProfileCheckedAt(AppDateTime.formatFull(context, item.lookup.checkedAt!))}',
                          style: Theme.of(context).textTheme.bodySmall)),
              if (!updating)
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        key: ValueKey(retryKey),
                        onPressed: onRetry,
                        child: Text(tr.tryAgain))),
            ])),
      ]),
    );
  }
}
