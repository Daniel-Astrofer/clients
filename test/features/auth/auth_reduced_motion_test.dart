import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kerosene/features/auth/presentation/widgets/auth_action_illustration.dart';
import 'package:kerosene/features/auth/presentation/widgets/totp_input_container.dart';
import 'package:kerosene/features/auth/presentation/screens/signup/signup_flow_components.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
  });

  testWidgets('auth illustration stops and resumes with motion preference',
      (tester) async {
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder(
        valueListenable: reduced,
        builder: (context, value, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: value),
          child: const AuthActionIllustration(
            mode: AuthActionIllustrationMode.fingerprintScan,
            color: Colors.white,
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    final animation = tester
        .widget<AnimatedBuilder>(find
            .descendant(
                of: find.byType(AuthActionIllustration),
                matching: find.byType(AnimatedBuilder))
            .first)
        .animation as AnimationController;
    expect(animation.isAnimating, isTrue);
    reduced.value = true;
    await tester.pumpAndSettle();
    expect(animation.isAnimating, isFalse);
    expect(animation.value, 1);
    reduced.value = false;
    await tester.pump(const Duration(milliseconds: 100));
    expect(animation.isAnimating, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('focused TOTP stops continuous animation for reduced motion',
      (tester) async {
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder(
        valueListenable: reduced,
        builder: (context, value, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: value),
          child: Scaffold(
            body: TotpInputContainer(onCompleted: (_) {}),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.hasScheduledFrame, isTrue);
    reduced.value = true;
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    reduced.value = false;
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup loading feedback stops its ticker with reduced motion',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const SignupSpinner(size: 48, strokeWidth: 3),
              )),
    ));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
