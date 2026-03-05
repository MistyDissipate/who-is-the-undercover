import 'package:flutter/material.dart';
import 'package:uncover_agent/widgets/setup/setting_card.dart';

class DifficultyFilterSettingCard extends StatelessWidget {
  final bool enabled;
  final List<String> difficulties;
  final String? selectedDifficulty;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onSelectDifficulty;

  const DifficultyFilterSettingCard({
    super.key,
    required this.enabled,
    required this.difficulties,
    required this.selectedDifficulty,
    required this.onToggle,
    required this.onSelectDifficulty,
  });

  @override
  Widget build(BuildContext context) {
    final canToggle = difficulties.isNotEmpty;

    return SettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '按难度筛选词库',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              canToggle ? '开启后仅使用所选难度' : '当前没有可用难度',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            value: enabled,
            onChanged: canToggle ? onToggle : null,
          ),
          if (enabled && canToggle) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: difficulties.map((difficulty) {
                final selected = selectedDifficulty == difficulty;
                return ChoiceChip(
                  label: Text(difficulty),
                  selected: selected,
                  onSelected: (isSelected) {
                    if (!isSelected) return;
                    onSelectDifficulty(difficulty);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}