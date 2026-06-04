import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// ── APP CARD ──────────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  const AppCard({super.key, required this.child, this.padding, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.shadow,
      ),
      child: child,
    );
  }
}

// ── CARD TITLE ────────────────────────────────────────────────────────────────
class CardTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const CardTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (trailing == null) {
      return Text(
        title.toUpperCase(),
        style: t.labelMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.08,
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: t.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.08,
            ),
          ),
        ),
        trailing!,
      ],
    );
  }
}

// ── METRIC CARD ───────────────────────────────────────────────────────────────
enum MetricAccent { green, red, blue, amber }

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final MetricAccent accent;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.accent = MetricAccent.green,
  });

  Color get _accentColor {
    switch (accent) {
      case MetricAccent.red: return AppColors.red;
      case MetricAccent.blue: return AppColors.blue;
      case MetricAccent.amber: return AppColors.amber;
      default: return AppColors.greenMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.shadow,
      ),
      child: Stack(
        children: [
          Positioned(
            left: -16,
            top: -14,
            bottom: -14,
            child: Container(width: 3, color: _accentColor),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: t.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(value,
                    style: t.bodyLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                if (sub != null) ...[
                  const SizedBox(height: 3),
                  Text(sub!,
                      style: t.labelSmall?.copyWith(color: AppColors.textTertiary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── BADGE ─────────────────────────────────────────────────────────────────────
enum BadgeVariant { green, amber, blue, red, grey }

class AppBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;

  const AppBadge({super.key, required this.label, this.variant = BadgeVariant.green});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (variant) {
      case BadgeVariant.amber: bg = AppColors.amberPale; fg = AppColors.amber; break;
      case BadgeVariant.blue: bg = AppColors.bluePale; fg = AppColors.blue; break;
      case BadgeVariant.red: bg = AppColors.redPale; fg = AppColors.red; break;
      case BadgeVariant.grey: bg = AppColors.surface2; fg = AppColors.textTertiary; break;
      default: bg = AppColors.greenPale; fg = AppColors.greenMid;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}

// ── EMPTY STATE ────────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    this.icon = '🌱',
    required this.title,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text(title, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: t.labelSmall),
          ],
        ],
      ),
    );
  }
}

// ── ADD BUTTON ─────────────────────────────────────────────────────────────────
class AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const AddButton({super.key, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.greenMid;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }
}

// ── ICON ACTION BUTTON (edit/delete) ─────────────────────────────────────────
class ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;

  const ActionIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 14, color: AppColors.textTertiary),
      ),
    );
  }
}

// ── PROGRESS ROW ──────────────────────────────────────────────────────────────
class ProgressRow extends StatelessWidget {
  final String label;
  final double fraction;
  final String valueLabel;
  final Color? barColor;

  const ProgressRow({
    super.key,
    required this.label,
    required this.fraction,
    required this.valueLabel,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                backgroundColor: AppColors.surface2,
                color: barColor ?? AppColors.greenMid,
                minHeight: 7,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(valueLabel,
                textAlign: TextAlign.right,
                style: t.labelSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

// ── CONFIRM DIALOG ────────────────────────────────────────────────────────────
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String message,
  String title = 'Please confirm',
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Delete',
  bool isDangerous = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message,
          style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: isDangerous ? AppColors.red : AppColors.greenMid),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ── FILTER DROPDOWN ───────────────────────────────────────────────────────────
class FilterDropdown extends StatelessWidget {
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const FilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border2, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontFamily: 'Sora'),
          dropdownColor: AppColors.surface,
          isDense: true,
          iconSize: 16,
        ),
      ),
    );
  }
}

// ── SEARCH FIELD ──────────────────────────────────────────────────────────────
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      width: 160,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.border2, width: 1.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.border2, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.greenLight, width: 1.5)),
          filled: true,
          fillColor: AppColors.surface2,
        ),
      ),
    );
  }
}
