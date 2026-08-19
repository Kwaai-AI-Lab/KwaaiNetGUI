import 'package:flutter/material.dart';

import '../../chat/kwaai_rpc_client.dart';

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

/// Headline for a tab whose daemon is unavailable.
///
/// Distinguishes the two cases, because the remedy differs: a local daemon can
/// be started from the Status tab, while one named by [kGrpcPortEnvVar] lives
/// elsewhere and this app cannot start it.
String unavailableHeadline() => grpcPortOverridden
    ? 'Cannot reach the daemon on port $grpcPort'
    : 'Daemon is not running';

/// Advice to pair with [unavailableHeadline].
///
/// [localHint] should complete "Start it from the Status tab to …".
String unavailableHint(String localHint) => grpcPortOverridden
    ? 'Check that the daemon is listening on 127.0.0.1:$grpcPort — '
          '$kGrpcPortEnvVar points this app at it.'
    : 'Start it from the Status tab to $localHint.';
