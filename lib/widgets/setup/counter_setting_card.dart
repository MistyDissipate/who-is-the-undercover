import 'package:flutter/material.dart';
import 'package:uncover_agent/widgets/setup/setting_card.dart';

class CounterSettingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const CounterSettingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return SettingCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDecrease,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 44,
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrease,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}