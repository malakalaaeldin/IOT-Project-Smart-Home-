import 'package:flutter/material.dart';

/// Shared loading / error / empty / offline views, so every screen handles
/// these states the same way (project requirement).

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading the house…'});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: isError ? scheme.error : scheme.primary),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final text = error.toString();
    final denied = text.contains('permission-denied') || text.contains('Permission denied');
    return MessageView(
      icon: denied ? Icons.lock_outline : Icons.error_outline,
      isError: true,
      title: denied ? 'Access denied' : "Couldn't load the data",
      message: denied
          ? 'Your account is not allowed to read this. Sign out and sign in again.'
          : 'Check your internet connection. Details: $text',
    );
  }
}

/// Thin banner shown at the top of every tab when Firebase is unreachable.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.wifi_off, color: scheme.onErrorContainer, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No internet. Showing the last known values; commands will send when you reconnect.',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
