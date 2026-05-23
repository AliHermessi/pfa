class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory ChatMessage.fromMap(String id, Map<dynamic, dynamic> map) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
