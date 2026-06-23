import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/secure_storage_service.dart';

class EulaScreen extends StatefulWidget {
  final VoidCallback? onAccepted;

  const EulaScreen({super.key, this.onAccepted});

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen> {
  Future<void> _onAccept() async {
    await SecureStorageService().setEulaAccepted(true);
    if (!mounted) return;
    if (widget.onAccepted != null) {
      widget.onAccepted!();
    }
  }

  void _onDecline() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLarge = MediaQuery.of(context).size.height > 700;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              SizedBox(
                width: 72,
                height: 72,
                child: Image.asset('img/logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              Text(
                'Finance me Local',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Terms of Use',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(flex: 1),
              Expanded(
                flex: isLarge ? 5 : 4,
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(120),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withAlpha(120),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to Finance me Local. Before you begin, '
                          'please read and accept our Terms of Use:',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          theme,
                          '100% Local & Private',
                          'This app operates entirely offline. Your data is '
                              'encrypted and stored exclusively on your device. '
                              'We do not collect, track, or have access to any of '
                              'your information.',
                        ),
                        _buildSection(
                          theme,
                          'A Personal Tool, Not an Advisor',
                          'This application is strictly a personal financial '
                              'diary and calculator. It does not provide financial '
                              'advice. You are your own financial manager.',
                        ),
                        _buildSection(
                          theme,
                          'Zero Liability',
                          'The developer is strictly not liable for any data '
                              'loss, forgotten backup passwords, device compromise, '
                              'or any financial decisions made using this app.',
                        ),
                        _buildSection(
                          theme,
                          'Your Responsibility',
                          'You are solely responsible for keeping your '
                              'biometric locks secure and safely storing your '
                              'encrypted backup files (.vault) and their passwords.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onAccept,
                  child: const Text('I Agree'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String body) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
