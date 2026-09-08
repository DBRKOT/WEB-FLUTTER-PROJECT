import 'package:flutter/material.dart';

class UnsavedChangesScope extends StatelessWidget {
  const UnsavedChangesScope({
    super.key,
    required this.isDirty,
    required this.child,
    this.message =
        'Есть несохранённые изменения. Уйти со страницы без сохранения?',
  });

  final bool isDirty;
  final Widget child;
  final String message;

  Future<bool> _confirm(BuildContext context) async {
    if (!isDirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Уйти'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirm(context);
        if (leave && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    );
  }
}
