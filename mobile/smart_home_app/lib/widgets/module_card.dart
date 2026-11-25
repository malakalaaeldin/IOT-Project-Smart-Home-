import 'package:flutter/material.dart';

import '../models/home_state.dart';
import '../models/module_info.dart';
import 'status_chip.dart';

/// One student's module: header (name, owner, hardware, status) + content.
class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.module,
    required this.liveness,
    required this.child,
    this.highlight,
  });

  final ModuleInfo module;
  final Liveness liveness;
  final Widget child;

  /// Optional tint (e.g. red while fire is detected).
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: highlight,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(module.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(module.name, style: theme.textTheme.titleMedium),
                      Text('${module.hardware} · by ${module.owner}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusChip(liveness: liveness),
              ],
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}
