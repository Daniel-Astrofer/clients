import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/motion/motion_catalog.dart';

void main() {
  group('KeroseneMotionRegistry', () {
    test('all KeroseneMotion tokens are registered', () {
      // Spot-check critical tokens exist in registry
      const requiredTokens = [
        'fast',
        'short',
        'medium',
        'pageIn',
        'pageOut',
        'ceremonial',
        'ambient',
        'loadingMinimum',
        'microStagger',
        'nfcSceneIntro',
      ];

      for (final token in requiredTokens) {
        final contract = KeroseneMotionRegistry.contractFor(token);
        expect(contract, isNotNull, reason: 'Token "$token" not in registry');
        expect(
          contract!.enter,
          isNot(Duration.zero),
          reason: 'Token "$token" has zero duration',
        );
      }
    });

    test('every registry entry maps to real KeroseneMotion constant', () {
      // Verify that the durations in the registry match the actual constants
      final contractToConstant = <String, Duration>{
        'fast': KeroseneMotion.fast,
        'short': KeroseneMotion.short,
        'medium': KeroseneMotion.medium,
        'long': KeroseneMotion.long,
        'pageIn': KeroseneMotion.pageIn,
        'pageOut': KeroseneMotion.pageOut,
        'ceremonial': KeroseneMotion.ceremonial,
        'ambient': KeroseneMotion.ambient,
        'calm': KeroseneMotion.calm,
        'slow': KeroseneMotion.slow,
        'status': KeroseneMotion.status,
        'heroLoop': KeroseneMotion.heroLoop,
        'secureLoop': KeroseneMotion.secureLoop,
        'walletLoop': KeroseneMotion.walletLoop,
        'loadingMinimum': KeroseneMotion.loadingMinimum,
        'loadingRetryMedium': KeroseneMotion.loadingRetryMedium,
        'loadingRetryLong': KeroseneMotion.loadingRetryLong,
        'loadingTimeout': KeroseneMotion.loadingTimeout,
        'offlineRetryPulse': KeroseneMotion.offlineRetryPulse,
        'offlineRetryInterval': KeroseneMotion.offlineRetryInterval,
        'microStagger': KeroseneMotion.microStagger,
        'authStagger': KeroseneMotion.authStagger,
        'listStagger': KeroseneMotion.listStagger,
        'compactStagger': KeroseneMotion.compactStagger,
        'surfaceStagger': KeroseneMotion.surfaceStagger,
        'nfcSceneIntro': KeroseneMotion.nfcSceneIntro,
        'nfcSceneReady': KeroseneMotion.nfcSceneReady,
        'odometerCeremony': KeroseneMotion.odometerCeremony,
        'odometerUpdate': KeroseneMotion.odometerUpdate,
        'passkeyScene': KeroseneMotion.passkeyScene,
        'passkeyPulse': KeroseneMotion.passkeyPulse,
        'totpTransition': KeroseneMotion.totpTransition,
        'noticeHold': KeroseneMotion.noticeHold,
        'noticeExtendedHold': KeroseneMotion.noticeExtendedHold,
        'notificationHold': KeroseneMotion.notificationHold,
        'notificationLongHold': KeroseneMotion.notificationLongHold,
      };

      for (final entry in contractToConstant.entries) {
        final contract = KeroseneMotionRegistry.contractFor(entry.key);
        expect(contract, isNotNull, reason: '${entry.key} not registered');
        expect(
          contract!.enter,
          entry.value,
          reason:
              '${entry.key}: registry=${contract.enter}, constant=${entry.value}',
        );
      }
    });

    test('categories have expected token counts', () {
      final functional =
          KeroseneMotionRegistry.byCategory(KeroseneMotionCategory.functional);
      final continuity =
          KeroseneMotionRegistry.byCategory(KeroseneMotionCategory.continuity);
      final brand =
          KeroseneMotionRegistry.byCategory(KeroseneMotionCategory.brand);
      final ambient =
          KeroseneMotionRegistry.byCategory(KeroseneMotionCategory.ambient);
      final loading =
          KeroseneMotionRegistry.byCategory(KeroseneMotionCategory.loading);

      expect(functional.length, greaterThanOrEqualTo(8));
      expect(continuity.length, greaterThanOrEqualTo(3));
      // Brand: ceremonial, secureLoop, status
      expect(brand.length, greaterThanOrEqualTo(3));
      // Ambient: ambient, calm, slow, heroLoop, walletLoop
      expect(ambient.length, greaterThanOrEqualTo(5));
      // Loading: loadingMinimum, loadingRetryMedium, loadingRetryLong,
      //          loadingTimeout, offlineRetryPulse, offlineRetryInterval,
      //          startupConnectionProgressTick
      expect(loading.length, greaterThanOrEqualTo(7));
    });
  });

  group('MotionContract', () {
    test('resolvedEnter returns enter when reduceMotion is false', () {
      const contract = MotionContract(
        enter: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        category: KeroseneMotionCategory.functional,
      );
      expect(contract.resolvedEnter(false), const Duration(milliseconds: 300));
    });

    test('resolvedEnter collapses functional to instant on reduceMotion', () {
      const contract = MotionContract(
        enter: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        category: KeroseneMotionCategory.functional,
      );
      expect(contract.resolvedEnter(true), Duration.zero);
    });

    test('resolvedEnter collapses continuity to instant on reduceMotion', () {
      const contract = MotionContract(
        enter: KeroseneMotion.pageIn,
        curve: Curves.easeOutQuart,
        category: KeroseneMotionCategory.continuity,
      );
      expect(contract.resolvedEnter(true), Duration.zero);
    });

    test('resolvedEnter removes ambient entirely on reduceMotion', () {
      const contract = MotionContract(
        enter: KeroseneMotion.ambient,
        curve: Curves.linear,
        category: KeroseneMotionCategory.ambient,
      );
      expect(contract.resolvedEnter(true), Duration.zero);
    });

    test('resolvedEnter removes brand movement on reduceMotion', () {
      const contract = MotionContract(
        enter: Duration(milliseconds: 2600),
        curve: Curves.easeOutExpo,
        category: KeroseneMotionCategory.brand,
      );
      expect(contract.resolvedEnter(true), Duration.zero);
    });
  });

  group('KeroseneMotionCategory', () {
    test('ambient is removed on reduceMotion', () {
      expect(
        KeroseneMotionCategory.ambient.removeOnReduceMotion,
        isTrue,
      );
    });

    test('functional collapses on reduceMotion', () {
      expect(
        KeroseneMotionCategory.functional.collapseOnReduceMotion,
        isTrue,
      );
    });

    test('brand collapses on reduceMotion', () {
      expect(KeroseneMotionCategory.brand.removeOnReduceMotion, isFalse);
      expect(KeroseneMotionCategory.brand.collapseOnReduceMotion, isTrue);
    });

    test('every category has a non-empty label', () {
      for (final cat in KeroseneMotionCategory.values) {
        expect(cat.label, isNotEmpty);
        expect(cat.label, isNot(contains('.')));
      }
    });
  });

  group('KeroseneMotionRegistry.curveFor', () {
    test('returns correct curves for semantic roles', () {
      expect(
        KeroseneMotionRegistry.curveFor('pageEnter'),
        Curves.easeOutQuart,
      );
      expect(KeroseneMotionRegistry.curveFor('pageExit'), Curves.easeInCubic);
      expect(
        KeroseneMotionRegistry.curveFor('default'),
        Curves.easeOutCubic,
      );
      expect(
        KeroseneMotionRegistry.curveFor('emphasized'),
        Curves.easeOutExpo,
      );
    });

    test('returns easeOutCubic for unknown roles', () {
      expect(
        KeroseneMotionRegistry.curveFor('unknown_role_xyz'),
        Curves.easeOutCubic,
      );
    });
  });
}
