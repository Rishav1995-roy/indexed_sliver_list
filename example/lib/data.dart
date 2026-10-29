import 'package:flutter/material.dart';

/// Synthetic content: no real people, photos or text.
class Post {
  const Post(this.index);
  final int index;

  /// 1 to 5 lines of text so that cards get clearly different heights.
  int get lines => 1 + (index * 7 + index ~/ 3) % 5;
  bool get hasImage => index % 3 == 0;
  double get imageHeight => 90.0 + (index * 13) % 80;
  String get title => 'Card #$index';
  String get body => List<String>.generate(
        lines,
        (i) => 'Line ${i + 1}: variable height content for item $index.',
      ).join('\n');
  Color get color =>
      HSLColor.fromAHSL(1, (index * 47) % 360.0, 0.55, 0.55).toColor();
}

const List<String> chatSnippets = <String>[
  'Hey! Are we still on for tomorrow?',
  'Yes. I will bring the notes.',
  'Great, see you at ten.',
  'Can you also send the slides? They are long, so I would like to read them on the train before the meeting starts and prepare a few questions.',
  'Sure.',
  'Thanks a lot!',
  'No problem at all, happy to help. Let me know if anything is unclear and we can go through it together on a call.',
  'Perfect.',
];

class ChatMessage {
  const ChatMessage(this.id, this.mine);
  final int id;
  final bool mine;
  String get text => chatSnippets[id % chatSnippets.length];
}
