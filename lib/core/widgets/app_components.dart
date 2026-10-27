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
              padding: EdgeInsets.all(
                constraints.maxWidth < AppLayout.compactBreakpoint
                    ? AppSpacing.lg
                    : AppSpacing.xl,
              ),
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
        AppColors.brandNavy,
        AppColors.brandMist,
        Icons.circle_outlined,
      ),
      AppStatusTone.info => (
        AppColors.brandNavy,
        AppColors.brandMist,
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
            borderRadius: AppShape.field,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: foreground),
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

enum AppActionStyle { primary, secondary, destructive }

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
    final indicator = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: busyLabel,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          )
        : icon == null
        ? null
        : Icon(icon);
    final destructive = style == AppActionStyle.destructive
        ? FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          )
        : null;
    final button = style == AppActionStyle.secondary
        ? indicator == null
              ? OutlinedButton(
                  onPressed: callback,
                  child: Text(label, textAlign: TextAlign.center),
                )
              : OutlinedButton.icon(
                  onPressed: callback,
                  icon: indicator,
                  label: Text(label, textAlign: TextAlign.center),
                )
        : indicator == null
        ? FilledButton(
            onPressed: callback,
            style: destructive,
            child: Text(label, textAlign: TextAlign.center),
          )
        : FilledButton.icon(
            onPressed: callback,
            icon: indicator,
            style: destructive,
            label: Text(label, textAlign: TextAlign.center),
          );
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
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String label;
  final String? hintText;
  final bool enabled;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppShape.action,
              borderSide: BorderSide.none,
            ),
            disabledBorder: const OutlineInputBorder(
              borderRadius: AppShape.action,
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search),
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
      );
}
