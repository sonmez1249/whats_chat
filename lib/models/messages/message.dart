abstract class Message {
  String senderId;
  DateTime timestamp;
  List<Map<String, dynamic>>? reactions;
  List<String>? deletedFor;

  Message({
    required this.senderId,
    required this.timestamp,
    this.reactions,
    this.deletedFor,
  });

  Map<String, dynamic> toMap();
}
