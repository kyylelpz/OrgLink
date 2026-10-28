import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// A scrollable, width-bounded body for a Scaffold; do not nest in another scroller.
class AppPageBody extends StatelessWidget {
  const AppPageBody({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.contentWidth,
  });
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

class AppSectionHeading extends StatelessWidget {
  const AppSectionHeading({
    super.key,
    required this.title,
    this.description,
    this.action,
  });
  final String title;
  final String? description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (description != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(description!),
      ],
      if (action != null) ...[const SizedBox(height: AppSpacing.sm), action!],
    ],
  );
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: onTap == null
        ? Padding(padding: padding, child: child)
        : InkWell(
            onTap: onTap,
            borderRadius: AppShape.card,
            child: Padding(padding: padding, child: child),
          ),
  );
}

enum AppStatusTone { neutral, info, success, warning, error }

/// Presentation only: callers supply display labels, never authorization values.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
  });
  final String label;
  final AppStatusTone tone;
  @override
  Widget build(BuildContext context) {
    final (foreground, background, icon) = switch (tone) {
      AppStatusTone.neutral => (
        AppColors.muted,
        AppColors.brandMist,
        Icons.circle_outlined,
      ),
      AppStatusTone.info => (
        AppColors.brandBlue,
        AppColors.tonal,
        Icons.info_outline,
      ),
      AppStatusTone.success => (
        AppColors.success,
        AppColors.successSurface,
        Icons.check_circle_outline,
      ),
      AppStatusTone.warning => (
        AppColors.warning,
        AppColors.warningSurface,
        Icons.schedule,
      ),
      AppStatusTone.error => (
        AppColors.error,
        AppColors.errorSurface,
        Icons.error_outline,
      ),
    };
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppShape.pill,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.chipHorizontal,
              vertical: AppSpacing.chipVertical,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: AppIconSize.small),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Keep secondary as the existing outlined contract; tonal is opt-in.
enum AppActionStyle { primary, secondary, outlined, tonal, text, destructive }

class AppActionButton extends StatelessWidget {
  const AppActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppActionStyle.primary,
    this.icon,
    this.busy = false,
    this.busyLabel = 'In progress',
  });
  final String label;
  final VoidCallback? onPressed;
  final AppActionStyle style;
  final IconData? icon;
  final bool busy;
  final String busyLabel;
  @override
  Widget build(BuildContext context) {
    final callback = busy ? null : onPressed;
    final colors = Theme.of(context).colorScheme;
    final filled =
        style == AppActionStyle.primary || style == AppActionStyle.destructive;
    final foreground = style == AppActionStyle.destructive
        ? colors.onError
        : filled
        ? colors.onPrimary
        : colors.primary;
    final indicator = busy
        ? SizedBox.square(
            dimension: AppIconSize.small,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: busyLabel,
              color: foreground,
            ),
          )
        : icon == null
        ? null
        : Icon(icon, size: AppIconSize.small);
    // Busy actions retain the Figma filled/tonal appearance while disabling taps.
    final ButtonStyle? appearance = style == AppActionStyle.destructive || busy
        ? ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled) && !busy
                  ? AppColors.muted
                  : foreground,
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled) && !busy
                  ? AppColors.border
                  : style == AppActionStyle.destructive
                  ? colors.error
                  : filled
                  ? colors.primary
                  : style == AppActionStyle.tonal
                  ? AppColors.tonal
                  : colors.surface,
            ),
          )
        : null;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (indicator != null) ...[
          indicator,
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    final button = switch (style) {
      AppActionStyle.secondary || AppActionStyle.outlined => OutlinedButton(
        onPressed: callback,
        style: appearance,
        child: content,
      ),
      AppActionStyle.tonal => FilledButton.tonal(
        onPressed: callback,
        style: appearance,
        child: content,
      ),
      AppActionStyle.text => TextButton(
        onPressed: callback,
        style: appearance,
        child: content,
      ),
      AppActionStyle.primary || AppActionStyle.destructive => FilledButton(
        onPressed: callback,
        style: appearance,
        child: content,
      ),
    };
    return Semantics(liveRegion: busy, child: button);
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.label = 'Search',
    this.hintText,
    this.enabled = true,
    this.compact = false,
    this.leading,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String label;
  final String? hintText;
  final bool enabled;
  final bool compact;
  final Widget? leading;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => Semantics(
          label: compact ? label : null,
          child: TextField(
            controller: controller,
            enabled: enabled,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: compact ? null : label,
              hintText: hintText,
              prefixIcon: leading ?? const Icon(Icons.search),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear Search',
                      onPressed: !enabled
                          ? null
                          : () {
                              controller.clear();
                              onChanged('');
                            },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
      );
}

/// Chip presentation only; selected values and filtering stay with callers.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label, softWrap: true),
    selected: selected,
    onSelected: onSelected,
    labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: onSelected == null
          ? AppColors.muted
          : selected
          ? AppColors.white
          : AppColors.muted,
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
