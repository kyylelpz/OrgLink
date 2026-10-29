import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../theme/app_tokens.dart';

/// Existing poster slots are responsive widths with fixed heights, not 16:9.
abstract final class EventPosterLayout {
  static const detailsHeight = 184.0;
  static const featuredHeight = 174.0;

  static double contentWidth(BuildContext context) {
    final media = MediaQuery.of(context);
    // SafeArea may have removed padding from this subtree's MediaQuery.
    final physicalPadding = MediaQueryData.fromView(
      View.of(context),
    ).padding.horizontal;
    final available =
        media.size.width - math.max(media.padding.horizontal, physicalPadding);
    return math.max(
      1,
      math.min(available, AppLayout.contentWidth) - AppSpacing.xl * 2,
    );
  }

  static double aspectRatio(BuildContext context) =>
      contentWidth(context) / detailsHeight;
  static double featuredAspectRatio(BuildContext context) =>
      contentWidth(context) / featuredHeight;
}
