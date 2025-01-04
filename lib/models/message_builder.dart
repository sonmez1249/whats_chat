class Message {
  final String text;
  final String senderId;
  final DateTime timestamp;
  final bool isGroup;
  final List<Map<String, dynamic>>? reactions;
  final List<String>? deletedFor;
  final Map<String, dynamic>? metadata;

  Message({
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.isGroup = false,
    this.reactions,
    this.deletedFor,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp,
      'isGroup': isGroup,
      if (reactions != null) 'reactions': reactions,
      if (deletedFor != null) 'deletedFor': deletedFor,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

class MessageBuilder {
  String? _text;
  String? _senderId;
  DateTime? _timestamp;
  bool _isGroup = false;
  List<Map<String, dynamic>>? _reactions;
  List<String>? _deletedFor;
  Map<String, dynamic>? _metadata;

  MessageBuilder setText(String text) {
    _text = text;
    return this;
  }

  MessageBuilder setSender(String senderId) {
    _senderId = senderId;
    return this;
  }

  MessageBuilder setTimestamp(DateTime timestamp) {
    _timestamp = timestamp;
    return this;
  }

  MessageBuilder setIsGroup(bool isGroup) {
    _isGroup = isGroup;
    return this;
  }

  MessageBuilder addReaction(String emoji, String userId) {
    _reactions ??= [];
    _reactions!.add({
      'emoji': emoji,
      'userId': userId,
      'timestamp': DateTime.now(),
    });
    return this;
  }

  MessageBuilder addDeletedFor(String userId) {
    _deletedFor ??= [];
    _deletedFor!.add(userId);
    return this;
  }

  MessageBuilder setMetadata(Map<String, dynamic> metadata) {
    _metadata = metadata;
    return this;
  }

  Message build() {
    if (_text == null || _senderId == null) {
      throw Exception('Message text and sender ID are required');
    }

    return Message(
      text: _text!,
      senderId: _senderId!,
      timestamp: _timestamp ?? DateTime.now(),
      isGroup: _isGroup,
      reactions: _reactions,
      deletedFor: _deletedFor,
      metadata: _metadata,
    );
  }
}
