import 'message.dart';

class TextMessage extends Message {
  final String text;

  TextMessage({
    required String senderId,
    required this.text,
    DateTime? timestamp,
    List<Map<String, dynamic>>? reactions,
    List<String>? deletedFor,
  }) : super(
          senderId: senderId,
          timestamp: timestamp ?? DateTime.now(),
          reactions: reactions,
          deletedFor: deletedFor,
        );

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'text',
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'reactions': reactions ?? [],
      'deletedFor': deletedFor ?? [],
    };
  }
}
