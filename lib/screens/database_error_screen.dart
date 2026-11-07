import 'package:flutter/material.dart';

/// 数据库打不开时的说明。不提供清除或重建数据的操作。
class DatabaseErrorScreen extends StatelessWidget {
  const DatabaseErrorScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('健身打卡')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.phone_android,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('打不开手机里的健康记录', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                '记录还在这台手机上，没有被删除，也没有被清空。可以再试一次。',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('retryOpenDatabase'),
                onPressed: onRetry,
                child: const Text('重新尝试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
