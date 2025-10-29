class ChatMessage {
  final String from;
  final String text;
  final int timestamp;
  final String? chatId;
  final Map<String, bool>? readBy; // Map userId -> isRead

  ChatMessage({
    required this.from,
    required this.text,
    required this.timestamp,
    this.chatId,
    this.readBy,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    Map<String, bool>? readByMap;
    if (json['readBy'] != null) {
      readByMap = Map<String, bool>.from(json['readBy']);
    }
    
    return ChatMessage(
      from: json['from'] ?? '',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] ?? 0,
      chatId: json['chatId'],
      readBy: readByMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'text': text,
      'timestamp': timestamp,
      'chatId': chatId,
      'readBy': readBy,
    };
  }

  ChatMessage copyWith({
    String? from,
    String? text,
    int? timestamp,
    String? chatId,
    Map<String, bool>? readBy,
  }) {
    return ChatMessage(
      from: from ?? this.from,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      chatId: chatId ?? this.chatId,
      readBy: readBy ?? this.readBy,
    );
  }

  // Kiểm tra tin nhắn đã được đọc bởi user chưa
  bool isReadBy(String userId) {
    return readBy?[userId] ?? false;
  }
}
