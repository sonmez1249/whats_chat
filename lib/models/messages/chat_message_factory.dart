import 'message.dart';
import 'message_factory.dart';
import 'text_message.dart';
import 'image_message.dart';

class ChatMessageFactory implements MessageFactory {
  @override
  Message createTextMessage({
    required String senderId,
    required String text,
    DateTime? timestamp,
  }) {
    return TextMessage(
      senderId: senderId,
      text: text,
      timestamp: timestamp,
    );
  }

  @override
  Message createImageMessage({
    required String senderId,
    required String imageUrl,
    DateTime? timestamp,
  }) {
    return ImageMessage(
      senderId: senderId,
      imageUrl: imageUrl,
      timestamp: timestamp,
    );
  }
}
