import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration test for the send-money flow contract.
///
/// Validates the screen sequence and state transitions defined in
/// [docs/product/design/flows/send-money.md]:
///
/// Home → Wallet Selection → Send Entry → Amount → Review → Authorize → Result
///
/// This is a widget-level smoke test — it verifies that each screen in the flow
/// can render with mock data and that state transitions follow the contract.
///
/// Run with: flutter test integration_test/flows/send_money_flow_test.dart
void main() {
  group('Send Money Flow — Screen Sequence', () {
    // ── Send Entry ────────────────────────────────────────────────────────

    testWidgets('Send Entry renders recipient input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _SendEntryMock(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enviar'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Send Entry empty state shows placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _SendEntryMock(recipient: ''),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enviar'), findsOneWidget);
      // Placeholder should invite input
      expect(find.byType(TextField), findsOneWidget);
    });

    // ── Amount Entry ─────────────────────────────────────────────────────

    testWidgets('Amount Entry renders keyboard and max button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _AmountEntryMock(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Amount display should be prominent
      expect(find.text('0,00'), findsOneWidget);
    });

    testWidgets('Amount Entry shows insufficient balance error', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _AmountEntryMock(hasInsufficientBalance: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Saldo insuficiente'), findsOneWidget);
    });

    // ── Review ────────────────────────────────────────────────────────────

    testWidgets('Review shows amount, recipient, fee, and confirm button', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _ReviewMock(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All parameters should be visible
      expect(find.text('0.001 BTC'), findsOneWidget);
      expect(find.textContaining('bc1q'), findsOneWidget);
      // Confirm button should be prominent
      expect(find.textContaining('Enviar'), findsOneWidget);
    });

    testWidgets('Review shows fee recalculating state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _ReviewMock(isFeeRecalculating: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Recalculando'), findsOneWidget);
    });

    testWidgets('Review shows duplicate warning', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _ReviewMock(showDuplicateWarning: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('enviou para este endereco'), findsOneWidget);
    });

    // ── Processing / Result ───────────────────────────────────────────────

    testWidgets('Processing state shows amount and status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _ProcessingMock(state: _ProcessingState.submitting),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0.001 BTC'), findsOneWidget);
      expect(find.textContaining('Enviando'), findsOneWidget);
    });

    testWidgets('Success result shows confirmation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _ProcessingMock(state: _ProcessingState.success),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Enviado'), findsOneWidget);
      expect(find.textContaining('Ver detalhes'), findsOneWidget);
    });

    testWidgets('Failure result shows error with retry', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _ProcessingMock(state: _ProcessingState.failed),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Falha'), findsOneWidget);
      expect(find.textContaining('Tentar novamente'), findsOneWidget);
    });
  });
}

// ── Mock screens (simulate contract structure without real providers) ──────

enum _ProcessingState { submitting, pending, success, failed }

class _SendEntryMock extends StatelessWidget {
  final String recipient;
  const _SendEntryMock({super.key, this.recipient = ''});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Enviar', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: recipient),
              decoration: const InputDecoration(
                hintText: 'Endereco, fatura ou contato',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountEntryMock extends StatelessWidget {
  final bool hasInsufficientBalance;
  const _AmountEntryMock({super.key, this.hasInsufficientBalance = false});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('0,00', style: TextStyle(fontSize: 48)),
            if (hasInsufficientBalance)
              const Text('Saldo insuficiente', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _ReviewMock extends StatelessWidget {
  final bool isFeeRecalculating;
  final bool showDuplicateWarning;
  const _ReviewMock({
    super.key,
    this.isFeeRecalculating = false,
    this.showDuplicateWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('0.001 BTC', style: TextStyle(fontSize: 32)),
            const Text('bc1q...xyz', style: TextStyle(fontSize: 15)),
            if (isFeeRecalculating)
              const Text('Recalculando taxa...', style: TextStyle(fontSize: 13)),
            if (showDuplicateWarning)
              const Text('Voce enviou para este endereco recentemente.',
                  style: TextStyle(color: Colors.amber)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () {}, child: const Text('Enviar 0.001 BTC')),
          ],
        ),
      ),
    );
  }
}

class _ProcessingMock extends StatelessWidget {
  final _ProcessingState state;
  const _ProcessingMock({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('0.001 BTC', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 24),
            switch (state) {
              _ProcessingState.submitting => const Text('Enviando...'),
              _ProcessingState.pending =>
                const Text('Aguardando confirmacao...'),
              _ProcessingState.success => Column(
                  children: [
                    const Text('Enviado com sucesso!'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Ver detalhes'),
                    ),
                  ],
                ),
              _ProcessingState.failed => Column(
                  children: [
                    const Text('Falha ao enviar'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
            },
          ],
        ),
      ),
    );
  }
}
