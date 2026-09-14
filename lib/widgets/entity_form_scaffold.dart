import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/validators.dart';
import 'unsaved_changes_scope.dart';

class FormFieldSpec {
  const FormFieldSpec({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final Validator? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final int maxLines;
}

class EntityFormScaffold extends StatelessWidget {
  const EntityFormScaffold({
    super.key,
    required this.title,
    required this.fallbackPath,
    required this.formKey,
    required this.isDirty,
    required this.loading,
    required this.saving,
    required this.onSubmit,
    required this.submitLabel,
    this.loadError,
    this.onRetry,
    this.fields = const [],
    this.extraChildren = const [],
  });

  final String title;
  final String fallbackPath;
  final GlobalKey<FormState> formKey;
  final bool isDirty;
  final bool loading;
  final bool saving;
  final String? loadError;
  final VoidCallback? onRetry;
  final VoidCallback onSubmit;
  final String submitLabel;
  final List<FormFieldSpec> fields;
  final List<Widget> extraChildren;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesScope(
      isDirty: isDirty && !saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            tooltip: 'Назад',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (!isDirty || saving) {
                _goBack(context);
                return;
              }
              final leave = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Несохранённые изменения'),
                  content: const Text(
                    'Есть несохранённые изменения. Уйти без сохранения?',
                  ),
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
              if (leave == true && context.mounted) _goBack(context);
            },
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loadError!),
                    const SizedBox(height: 12),
                    if (onRetry != null)
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('Повторить'),
                      ),
                  ],
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        for (var i = 0; i < fields.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          TextFormField(
                            controller: fields[i].controller,
                            keyboardType: fields[i].keyboardType,
                            inputFormatters: fields[i].inputFormatters,
                            maxLines: fields[i].maxLines,
                            decoration: InputDecoration(
                              labelText: fields[i].label,
                              border: const OutlineInputBorder(),
                            ),
                            validator: fields[i].validator,
                            onChanged: fields[i].onChanged,
                          ),
                        ],
                        ...extraChildren,
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: saving ? null : onSubmit,
                          child: Text(saving ? 'Сохранение…' : submitLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
