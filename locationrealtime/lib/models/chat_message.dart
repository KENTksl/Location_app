class ChatMessage {
  final String from;
  final String text;
  final int timestamp;
  final String? chatId;

  ChatMessage({
    required this.from,
    required this.text,
    required this.timestamp,
    this.chatId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      from: json['from'] ?? '',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] ?? 0,
      chatId: json['chatId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'text': text,
      'timestamp': timestamp,
      'chatId': chatId,
    };
  }

  ChatMessage copyWith({
    String? from,
    String? text,
    int? timestamp,
    String? chatId,
  }) {
    return ChatMessage(
      from: from ?? this.from,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      chatId: chatId ?? this.chatId,
    );
  }
}
