import 'package:flutter/material.dart';
import '../utils/display_labels.dart';

/// Changes the editable controller only after the user chooses the preview.
class CapitalizationSuggestion extends StatelessWidget {
  const CapitalizationSuggestion({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final TextEditingController controller;
  final bool enabled;
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      final suggestion = capitalizationSuggestion(value.text);
      if (!enabled || suggestion == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suggested capitalization: $suggestion'),
          const Text(
            'Review names and acronyms before applying. You can edit the result.',
          ),
          TextButton(
            onPressed: () => controller.value = TextEditingValue(
              text: suggestion,
              selection: TextSelection.collapsed(offset: suggestion.length),
            ),
            child: const Text('Use Suggestion'),
          ),
        ],
      );
    },
  );
}
