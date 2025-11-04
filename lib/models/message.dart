enum Sender { user, assistant }

class Message {
  final String text;
  final Sender sender;
  final DateTime time;

  Message({required this.text, required this.sender, DateTime? time})
      : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'text': text,
    'sender': sender == Sender.user ? 'user' : 'assistant',
    'time': time.toIso8601String(),
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    text: json['text'] ?? '',
    sender: json['sender'] == 'user' ? Sender.user : Sender.assistant,
    time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
  );
}
