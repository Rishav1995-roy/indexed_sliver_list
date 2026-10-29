import 'package:flutter/material.dart';
import 'package:indexed_sliver_list/indexed_sliver_list.dart';

import 'data.dart';

/// A reversed chat list. Index 0 is the newest message and sits at the
/// bottom. New messages keep the reader's place when she scrolled up.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.controller});
  final IndexedScrollController? controller;

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  late final IndexedScrollController controller =
      widget.controller ?? IndexedScrollController();
  // Newest first. Ids grow, so a message keeps its id when others are added.
  List<ChatMessage> messages = List<ChatMessage>.generate(
      2000, (i) => ChatMessage(1999 - i, (1999 - i) % 3 == 0));
  int _nextId = 2000;

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  void receive() {
    setState(() =>
        messages = <ChatMessage>[ChatMessage(_nextId++, false), ...messages]);
    controller.notifyItemsInserted(0);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Expanded(
          child: IndexedListView(
            controller: controller,
            reverse: true,
            itemCount: messages.length,
            estimatedItemExtent: 64,
            padding: const EdgeInsets.symmetric(vertical: 8),
            findChildIndexCallback: (Key key) {
              final int id = (key as ValueKey<int>).value;
              final int i = messages.indexWhere((m) => m.id == id);
              return i < 0 ? null : i;
            },
            itemBuilder: (BuildContext context, int i) {
              final ChatMessage m = messages[i];
              return Align(
                key: ValueKey<int>(m.id),
                alignment:
                    m.mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: m.mine
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('#${m.id}  ${m.text}'),
                ),
              );
            },
          ),
        ),
        Material(
          elevation: 6,
          color: scheme.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  FilledButton.tonal(
                    key: const ValueKey<String>('chat-first'),
                    onPressed: () => controller.animateToIndex(
                        messages.length - 1,
                        alignment: 0.5,
                        duration: const Duration(milliseconds: 900)),
                    child: const Text('First message'),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey<String>('chat-middle'),
                    onPressed: () => controller.animateToIndex(1000,
                        alignment: 0.5,
                        duration: const Duration(milliseconds: 700)),
                    child: const Text('Message 1000'),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey<String>('chat-new'),
                    onPressed: receive,
                    child: const Text('Receive'),
                  ),
                  FilledButton(
                    key: const ValueKey<String>('chat-latest'),
                    onPressed: () =>
                        controller.animateToIndex(0, alignment: 0.0),
                    child: const Text('Latest'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
