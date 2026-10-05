import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/features/movement/kernel/intent/nfc_payment_request_codec.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

enum _NfcReadState { preparing, scanning, read, unavailable, invalid }

class NfcScanDialog extends StatefulWidget {
  const NfcScanDialog({super.key});
  @override
  State<NfcScanDialog> createState() => _NfcScanDialogState();
}

class _NfcScanDialogState extends State<NfcScanDialog> {
  _NfcReadState _state = _NfcReadState.preparing;
  bool _sessionActive = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _stop() async {
    if (!_sessionActive) return;
    _sessionActive = false;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  Future<void> _start() async {
    if (_sessionActive) return;
    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (!mounted) return;
      if (availability != NfcAvailability.enabled) {
        setState(() => _state = _NfcReadState.unavailable);
        return;
      }
      setState(() => _state = _NfcReadState.scanning);
      _sessionActive = true;
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092
        },
        onDiscovered: (tag) async {
          String? payload;
          try {
            final ndef = Ndef.from(tag);
            final message = ndef?.cachedMessage ?? await ndef?.read();
            if (message != null) {
              payload = NfcPaymentRequestCodec.decodeMessage(message);
            }
          } catch (_) {}
          await _stop();
          if (!mounted) return;
          if (payload == null || payload.trim().isEmpty) {
            setState(() => _state = _NfcReadState.invalid);
          } else {
            setState(() => _state = _NfcReadState.read);
            Navigator.of(context).pop(payload);
          }
        },
      );
    } catch (_) {
      await _stop();
      if (mounted) setState(() => _state = _NfcReadState.unavailable);
    }
  }

  @override
  void dispose() {
    unawaited(_stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error =
        _state == _NfcReadState.unavailable || _state == _NfcReadState.invalid;
    final message = switch (_state) {
      _NfcReadState.preparing => context.tr.nfcReadyToScan,
      _NfcReadState.scanning => context.tr.nfcHoldNearTag,
      _NfcReadState.read => context.tr.nfcPaymentRequestRead,
      _NfcReadState.unavailable => context.tr.nfcUnavailableDevice,
      _NfcReadState.invalid => context.tr.nfcTagDetected,
    };
    return AlertDialog(
      title: Text(context.tr.nfcScannerTitle),
      content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(error ? KeroseneIcons.warning : KeroseneIcons.nfc,
            size: 48, color: error ? scheme.error : scheme.onSurface),
        const SizedBox(height: 24),
        Semantics(
            liveRegion: true,
            child: Text(message, textAlign: TextAlign.center)),
      ])),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr.cancel)),
        if (error)
          TextButton(onPressed: _start, child: Text(context.tr.tryAgain)),
      ],
    );
  }
}
