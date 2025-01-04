import 'message.dart';

class ImageMessage extends Message {
  final String imageUrl;

  ImageMessage({
    required String senderId,
    required this.imageUrl,
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
      'type': 'image',
      'senderId': senderId,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
      'reactions': reactions ?? [],
      'deletedFor': deletedFor ?? [],
    };
  }
}
