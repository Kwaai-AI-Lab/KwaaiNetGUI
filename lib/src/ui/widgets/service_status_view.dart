import 'package:flutter/material.dart';

/// The canonical centered "service is doing something" view: an optional
/// spinner above a headline. Used for the startup transition (as the chat
/// body) and the shutdown takeover (as the whole window), so the two read
/// identically. Keep this the single source of truth for that treatment.
class ServiceStatusView extends StatelessWidget {
  const ServiceStatusView({
    super.key,
    required this.headline,
    this.spinner = true,
    this.spinnerColor,
    this.subtitle,
  });

  final String headline;
  final bool spinner;
  final Color? spinnerColor;

  /// Optional content shown below the headline (e.g. the "Open settings…"
  /// hint on the stopped state).
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner) ...[
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: spinnerColor == null
                    ? null
                    : AlwaysStoppedAnimation(spinnerColor!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(headline, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[const SizedBox(height: 4), subtitle!],
        ],
      ),
    );
  }
}
