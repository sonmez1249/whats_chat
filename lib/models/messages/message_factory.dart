import 'message.dart';

abstract class MessageFactory {
  Message createTextMessage({
    required String senderId,
    required String text,
    DateTime? timestamp,
  });

  Message createImageMessage({
    required String senderId,
    required String imageUrl,
    DateTime? timestamp,
  });
}
