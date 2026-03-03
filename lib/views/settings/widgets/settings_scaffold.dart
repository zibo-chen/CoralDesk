import 'package:flutter/material.dart';
import 'package:coraldesk/theme/app_theme.dart';

/// Reusable scaffold for settings / configuration pages.
///
/// Provides a consistent top-bar, loading state, and scrollable content area.
/// The [actions] slot can hold status labels, refresh buttons, etc.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    this.icon,
    required this.isLoading,
    required this.body,
    this.actions,
    this.useScrollView = true,
    this.topBarHeight = 56.0,
  });

  final String title;
  final IconData? icon;
  final bool isLoading;
  final Widget body;
  final List<Widget>? actions;

  /// When `false`, [body] is placed directly in the [Expanded] area without
  /// wrapping in a [SingleChildScrollView] (useful for pages that have their
  /// own scroll view, e.g. [ListView]).
  final bool useScrollView;

  /// Override the default top-bar height (56). Some pages use 64.
  final double topBarHeight;

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);

    return Column(
      children: [
        // Top bar
        Container(
          height: topBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: c.surfaceBg,
            border: Border(
              bottom: BorderSide(color: c.chatListBorder, width: 1),
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              if (actions != null) ...[const Spacer(), ...actions!],
            ],
          ),
        ),

        // Content
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : useScrollView
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: body,
                )
              : body,
        ),
      ],
    );
  }
}

/// Reusable card container for settings sections.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = CoralDeskColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.chatListBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Small coloured status label (success / error) used in top-bars.
class StatusLabel extends StatelessWidget {
  const StatusLabel({super.key, required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
