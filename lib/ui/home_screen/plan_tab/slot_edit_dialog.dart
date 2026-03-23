import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gowhymo/db/plan.dart';
import 'package:gowhymo/ui/home_screen/home_screen_providers.dart';

class SlotEditDialog extends ConsumerWidget {
  final Plan? plan;
  final String title;
  final TextEditingController contentController = TextEditingController();
  SlotEditDialog(this.plan, this.title, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // log("slotEditDialog build");
    if (plan != null) {
      contentController.text = plan!.content;
    }
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: TextField(
          controller: contentController,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          enableInteractiveSelection: true,
          enableSuggestions: true,
          decoration: const InputDecoration(
            labelText: '计划内容',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            if (plan != null) {
              final updatedPlan = plan!.copyWith(
                content: contentController.text,
                updatedAt: DateTime.now(),
              );
              ref.read(planListProvider.notifier).updatePlan(updatedPlan);
            } else {
              final newPlan = Plan(
                planId: DateTime.now().millisecondsSinceEpoch,
                kidId: 101, // 默认kidId
                date: ref.watch(calendarWeekStateProvider).selectedDate,
                content: contentController.text,
                slotName: title,
                location: null,
                createdBy: "1", // 默认用户ID
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              ref.read(planListProvider.notifier).addPlan(newPlan);
            }
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
