import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

/// Marketing / landing surface tokens (layout + color only).
///
/// Editorial copy stays in the landing feature (or ARB), not here.
abstract final class LandingSurfaceTokens {
  static const ink = AppColors.hexFF000000;
  static const surface = AppColors.hexFF131313;
  static const panel = AppColors.hex99101010;
  static const panelSoft = AppColors.hexFF201F1F;
  static const line = AppColors.hexFF353534;
  static const muted = AppColors.hexFFD5C4AB;
  static const faint = AppColors.hexFF9E8F78;

  /// Landing gold leans brighter than product [KeroseneBrandTokens.brand].
  static const gold = AppColors.hexFFFFB800;
  static const goldSoft = AppColors.hexFFFFDCA1;
  static const green = AppColors.hexFF00E274;

  static const contentMaxWidth = 1280.0;

  /// Bridge to product brand when landing should match in-app chrome.
  static const Color productBrandGold = KeroseneBrandTokens.brand;
}
