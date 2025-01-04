abstract class Message {
  String get text;
  String get senderId;
  DateTime get timestamp;
  List<Reaction> get reactions;
}

class BaseMessage implements Message {
  final String _text;
  final String _senderId;
  final DateTime _timestamp;
  final List<Reaction> _reactions;

  BaseMessage({
    required String text,
    required String senderId,
    required DateTime timestamp,
    List<Reaction>? reactions,
  })  : _text = text,
        _senderId = senderId,
        _timestamp = timestamp,
        _reactions = reactions ?? [];

  @override
  String get text => _text;

  @override
  String get senderId => _senderId;

  @override
  DateTime get timestamp => _timestamp;

  @override
  List<Reaction> get reactions => _reactions;
}

class Reaction {
  final String emoji;
  final String userId;
  final DateTime timestamp;

  Reaction({
    required this.emoji,
    required this.userId,
    required this.timestamp,
  });
}

class MessageDecorator implements Message {
  final Message _message;

  MessageDecorator(this._message);

  @override
  String get text => _message.text;

  @override
  String get senderId => _message.senderId;

  @override
  DateTime get timestamp => _message.timestamp;

  @override
  List<Reaction> get reactions => _message.reactions;
}

class ReactionDecorator extends MessageDecorator {
  ReactionDecorator(Message message) : super(message);

  void addReaction(String emoji, String userId) {
    reactions.add(
      Reaction(
        emoji: emoji,
        userId: userId,
        timestamp: DateTime.now(),
      ),
    );
  }

  void removeReaction(String userId, String emoji) {
    reactions.removeWhere(
      (reaction) => reaction.userId == userId && reaction.emoji == emoji,
    );
  }

  List<Reaction> getReactionsByEmoji(String emoji) {
    return reactions.where((reaction) => reaction.emoji == emoji).toList();
  }

  int getReactionCount(String emoji) {
    return getReactionsByEmoji(emoji).length;
  }
}
