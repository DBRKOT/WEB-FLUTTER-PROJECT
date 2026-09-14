import 'package:flutter/material.dart';

class IdChipFormField extends FormField<List<int>> {
  IdChipFormField({
    super.key,
    required String label,
    required List<({int id, String name})> options,
    List<int>? initialValue,
    required String emptyError,
    super.onSaved,
    ValueChanged<List<int>>? onChanged,
  }) : super(
         initialValue: initialValue ?? const [],
         validator: (value) =>
             (value == null || value.isEmpty) ? emptyError : null,
         builder: (field) {
           return InputDecorator(
             decoration: InputDecoration(
               labelText: label,
               border: const OutlineInputBorder(),
               errorText: field.errorText,
             ),
             child: Wrap(
               spacing: 8,
               runSpacing: 8,
               children: [
                 for (final option in options)
                   FilterChip(
                     label: Text(option.name),
                     selected: field.value!.contains(option.id),
                     onSelected: (_) {
                       final next = [...field.value!];
                       if (next.contains(option.id)) {
                         next.remove(option.id);
                       } else {
                         next.add(option.id);
                       }
                       field.didChange(next);
                       onChanged?.call(next);
                     },
                   ),
               ],
             ),
           );
         },
       );
}
