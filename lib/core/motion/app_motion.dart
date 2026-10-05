import 'package:flutter/material.dart';

class KeroseneMotion {
  const KeroseneMotion._();

  static const int targetRefreshRateFps = 120;
  static const Duration frameBudget = Duration(microseconds: 8333);

  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration pageIn = Duration(milliseconds: 260);
  static const Duration pageOut = Duration(milliseconds: 220);
  static const Duration pageTransition = Duration(milliseconds: 280);
  static const Duration statusChange = Duration(milliseconds: 220);
  static const Duration sheet = Duration(milliseconds: 260);
  static const Duration success = Duration(milliseconds: 360);
  static const double pressScale = 0.985;
  static const Duration short = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration long = Duration(milliseconds: 420);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration calm = Duration(milliseconds: 1000);
  static const Duration status = Duration(milliseconds: 1500);
  static const Duration loop = Duration(milliseconds: 1800);
  static const Duration offlineRetryPulse = Duration(milliseconds: 520);
  static const Duration offlineRetryInterval = Duration(seconds: 4);
  static const Duration startupConnectionProgressTick = Duration(
    milliseconds: 420,
  );
  static const Duration startupConnectionTimeout = Duration(seconds: 55);
  static const Curve expressiveBack = Curves.easeOutBack;
  static const Duration route = pageIn;
  static const Duration ceremonial = Duration(milliseconds: 2600);
  static const Duration ambient = Duration(seconds: 20);
  static const Duration heroLoop = Duration(milliseconds: 2200);
  static const Duration secureLoop = Duration(milliseconds: 5200);
  static const Duration passkeyPulse = Duration(milliseconds: 5000);
  static const Duration passkeyScene = Duration(milliseconds: 900);
  static const Duration passkeySceneCompact = Duration(milliseconds: 760);
  static const Duration totpTransition = Duration(milliseconds: 850);
  static const Duration noticeHold = Duration(seconds: 3);
  static const Duration noticeExtendedHold = Duration(seconds: 4);
  static const Duration loadingMinimum = Duration(seconds: 3);
  static const Duration loadingRetryMedium = Duration(seconds: 6);
  static const Duration loadingRetryLong = Duration(seconds: 12);
  static const Duration loadingTimeout = Duration(seconds: 15);
  static const Duration notificationHold = Duration(seconds: 5);
  static const Duration notificationLongHold = Duration(seconds: 6);
  static const Duration walletLoop = Duration(seconds: 4);
  static const Duration nfcSceneIntro = Duration(milliseconds: 1600);
  static const Duration nfcSceneReady = Duration(milliseconds: 3900);
  static const Duration interactionCooldown = Duration(milliseconds: 500);

  // Shared financial-input motion values. Keeping these here prevents the
  // keypad, amount hero, and send CTA from growing unrelated raw timings.
  static const Duration inputTitle = Duration(milliseconds: 200);
  static const Duration inputPress = Duration(milliseconds: 90);
  static const Duration inputPressReverse = Duration(milliseconds: 140);
  static const Duration inputPressReverseFast = Duration(milliseconds: 120);
  static const Duration inputPressReverseSoft = Duration(milliseconds: 160);
  static const Duration inputCountUp = Duration(milliseconds: 300);
  static const Duration inputDigit = Duration(milliseconds: 220);
  static const Duration inputCursor = Duration(milliseconds: 900);
  static const Duration inputAmountMorph = Duration(milliseconds: 231);
  static const Duration inputSwap = Duration(milliseconds: 200);
  static const Duration inputCta = Duration(milliseconds: 300);
  static const Duration inputSpin = Duration(seconds: 1);
  static const Duration inputHeroDigit = Duration(milliseconds: 160);
  static const Duration inputHeroSettle = Duration(milliseconds: 220);
  static const Duration inputHeroShake = Duration(milliseconds: 280);
  static const Duration onboardingStagger = Duration(milliseconds: 24);
  static const Duration revolutFlip = Duration(milliseconds: 280);
  static const Duration sceneTransition = Duration(milliseconds: 560);
  static const Duration sceneTransitionReverse = Duration(milliseconds: 360);
  static const Duration detailClipboardHold = Duration(seconds: 1);
  static const Duration pinSuccess = Duration(milliseconds: 1400);
  static const Duration pinTransition = Duration(milliseconds: 250);
  static const Duration educationPoll = Duration(seconds: 15);
  static const Duration educationKick = Duration(seconds: 50);
  static const Duration educationAuthWarmup = Duration(milliseconds: 1200);
  static const Duration educationAuthRetry = Duration(seconds: 2);
  static const Curve standardInOut = Curves.easeInOutCubic;
  static const Curve standardEaseInOut = Curves.easeInOut;
  static const Curve decelerated = Curves.easeOut;
  static const Curve linearIn = Curves.easeIn;
  static const Curve linearOut = Curves.easeOut;
  static const Duration torLoadingDots = Duration(milliseconds: 900);
  static const Duration seedReveal = Duration(milliseconds: 300);
  static const Duration seedValidationTimeout = Duration(seconds: 8);
  static const Duration homeEducation = Duration(milliseconds: 280);
  static const Duration homeDistribution = Duration(milliseconds: 300);
  static const Duration homeGreeting = Duration(milliseconds: 220);
  static const Duration homeLoadingCompact = Duration(milliseconds: 250);
  static const Duration homeLoadingFull = Duration(milliseconds: 750);
  static const Duration receiveWallet = Duration(milliseconds: 180);
  static const Duration receiveWalletToHub = Duration(milliseconds: 520);
  static const Duration sendAmount = Duration(milliseconds: 240);
  static const Duration sendAmountExpanded = Duration(milliseconds: 400);
  static const Duration progressShimmer = Duration(milliseconds: 1400);
  static const Duration progressFill = Duration(milliseconds: 400);
  static const Duration progressRing = Duration(milliseconds: 1100);
  static const Duration educationHold = Duration(milliseconds: 4200);

  static const Duration frameInterval = Duration(milliseconds: 16);
  static const Duration homePricePoll = Duration(seconds: 12);

  static Duration fromMilliseconds(int milliseconds) =>
      Duration(milliseconds: milliseconds);

  /// Legacy long spin (avoid on home — use [odometerCeremony] instead).
  static const Duration odometerInitial = Duration(milliseconds: 3000);

  /// One short session ceremony when the home balance first appears.
  static const Duration odometerCeremony = Duration(milliseconds: 1000);

  /// Digit roll only on large real balance deltas (not tab swipe).
  static const Duration odometerUpdate = Duration(milliseconds: 700);
  static const Duration microStagger = Duration(milliseconds: 50);
  static const Duration authStagger = Duration(milliseconds: 34);
  static const Duration listStagger = Duration(milliseconds: 60);
  static const Duration compactStagger = Duration(milliseconds: 45);
  static const Duration surfaceStagger = Duration(milliseconds: 28);

  static Duration stagger(
    int index, {
    Duration step = microStagger,
    int maxIndex = 100,
  }) {
    final safeIndex = index.clamp(0, maxIndex);
    return Duration(microseconds: step.inMicroseconds * safeIndex);
  }

  static Duration exponentialBackoff(
    int retryCount, {
    Duration base = short,
    int maxRetryCount = 5,
  }) {
    final safeRetryCount = retryCount.clamp(0, maxRetryCount).toInt();
    return Duration(microseconds: base.inMicroseconds * (1 << safeRetryCount));
  }

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutExpo;
  static const Curve entrance = Curves.easeOutQuart;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.elasticOut;

  static bool reduceMotion(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return media?.disableAnimations == true ||
        media?.accessibleNavigation == true;
  }

  static Duration duration(BuildContext context, Duration duration) {
    return reduceMotion(context) ? instant : duration;
  }
}
