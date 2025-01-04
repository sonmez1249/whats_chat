import 'package:flutter/material.dart';

class ReactionPicker extends StatelessWidget {
  final Function(String emoji) onReactionSelected;

  const ReactionPicker({
    super.key,
    required this.onReactionSelected,
  });

  static const _emojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _emojis.map((emoji) {
          return GestureDetector(
            onTap: () => onReactionSelected(emoji),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
          );
        }).toList(),
      ),
    );
  }
}
