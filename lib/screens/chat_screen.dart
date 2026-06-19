import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final String peerName;

  const ChatScreen({super.key, required this.peerName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late DatabaseReference _chatReference;
  late String _currentUserName;
  late Stream<DatabaseEvent> _chatStream;

  // su
  final String adminEmail = "xwisniax96@gmail.com";

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user?.email == adminEmail) {
      _currentUserName = user?.displayName ?? "support.ACTIV.io";
    } else {
      final rawName = user?.email?.split('@')[0] ?? "Nieznajomy";
      final uniqueId = user?.uid.substring(0, 4) ?? "0000";
      _currentUserName = user?.displayName ?? "$rawName#$uniqueId";
    }

    List<String> users = [_currentUserName, widget.peerName];
    users.sort();

    String safeUser1 = users[0]
        .replaceAll('#', '-HASH-')
        .replaceAll('.', '-DOT-');
    String safeUser2 = users[1]
        .replaceAll('#', '-HASH-')
        .replaceAll('.', '-DOT-');
    String chatId = "${safeUser1}__$safeUser2";

    _chatReference = FirebaseDatabase.instance.ref("chats").child(chatId);
    _chatStream = _chatReference.orderByChild("timestamp").onValue;
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    await _chatReference.push().set({
      "sender": _currentUserName,
      "text": _messageController.text.trim(),
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "readBy": [_currentUserName],
    });

    _messageController.clear();
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _showDeleteChatDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '🗑️ Usuń konwersację',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Czy na pewno chcesz bezpowrotnie usunąć CAŁĄ konwersację? Zniknie ona dla obu użytkowników.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ANULUJ', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              _chatReference.remove();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Konwersacja została usunięta.')),
              );
            },
            child: const Text('USUŃ CAŁOŚĆ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.peerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _showDeleteChatDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _chatStream,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  );
                }

                List<Map<dynamic, dynamic>> messages = [];
                Map<String, dynamic> updatesToMarkAsRead = {};

                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  final data = snapshot.data!.snapshot.value;
                  if (data is Map) {
                    data.forEach((key, value) {
                      if (value is Map<dynamic, dynamic>) {
                        messages.add(value);

                        List<dynamic> readByList = List.from(
                          value["readBy"] ?? [],
                        );
                        if (!readByList.contains(_currentUserName)) {
                          readByList.add(_currentUserName);
                          updatesToMarkAsRead["$key/readBy"] = readByList;
                        }
                      }
                    });

                    if (updatesToMarkAsRead.isNotEmpty) {
                      _chatReference.update(updatesToMarkAsRead);
                    }

                    messages.sort((a, b) {
                      final t1 = a["timestamp"] ?? 0;
                      final t2 = b["timestamp"] ?? 0;
                      return t1.compareTo(t2);
                    });
                  }
                }

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      "Brak wiadomości. Napisz pierwszy/a!",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isMe = msg["sender"] == _currentUserName;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.orange : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20).copyWith(
                            bottomRight: isMe
                                ? const Radius.circular(0)
                                : const Radius.circular(20),
                            bottomLeft: isMe
                                ? const Radius.circular(20)
                                : const Radius.circular(0),
                          ),
                        ),
                        child: Text(
                          msg["text"] ?? "",
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Napisz wiadomość...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.orange,
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
