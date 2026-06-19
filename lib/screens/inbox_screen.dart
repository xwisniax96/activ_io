import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final databaseReference = FirebaseDatabase.instance.ref("chats");
  late String _currentUserName;
  late String _safeCurrentUserName;
  String _searchQuery = "";

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

    _safeCurrentUserName = _currentUserName
        .replaceAll('#', '-HASH-')
        .replaceAll('.', '-DOT-');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Moje Wiadomości', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Szukaj konwersacji...',
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: databaseReference.onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }

                Map<String, bool> myChatsWithStatus = {};

                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                  data.forEach((key, value) {
                    String chatId = key.toString();
                    if (chatId.contains(_safeCurrentUserName)) {
                      String peerNameSafe = chatId.replaceAll(_safeCurrentUserName, "").replaceAll("__", "");
                      String peerName = peerNameSafe.replaceAll('-HASH-', '#').replaceAll('-DOT-', '.');

                      if (peerName.isNotEmpty) {
                        bool hasUnread = false;
                        
                        if (value is Map) {
                          value.forEach((msgKey, msgValue) {
                            if (msgValue is Map) {
                              List<dynamic> readBy = List.from(msgValue["readBy"] ?? []);
                              if (!readBy.contains(_currentUserName)) {
                                hasUnread = true; 
                              }
                            }
                          });
                        }
                        myChatsWithStatus[peerName] = hasUnread;
                      }
                    }
                  });
                }

                List<String> chatList = myChatsWithStatus.keys.toList();
                if (_searchQuery.isNotEmpty) {
                  chatList = chatList.where((name) => name.toLowerCase().contains(_searchQuery)).toList();
                }

                if (chatList.isEmpty) {
                  return Center(child: Text(_searchQuery.isNotEmpty ? "Nie znaleziono konwersacji." : "Nie masz jeszcze żadnych wiadomości.\nKliknij w pinezkę na mapie, żeby zacząć rozmowę!", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)));
                }

                return ListView.builder(
                  itemCount: chatList.length,
                  itemBuilder: (context, index) {
                    final peer = chatList[index];
                    final bool isUnread = myChatsWithStatus[peer] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(8),
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.orange.shade100,
                          child: const Icon(Icons.person, color: Colors.orange, size: 30),
                        ),
                        title: Row(
                          children: [
                            Text(peer, style: TextStyle(fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold, fontSize: 18)),
                            if (isUnread) ...[
                              const SizedBox(width: 8),
                              const CircleAvatar(radius: 5, backgroundColor: Colors.orange), 
                            ]
                          ],
                        ),
                        subtitle: Text(isUnread ? "Masz nową wiadomość!" : "Kliknij, aby otworzyć konwersację", style: TextStyle(color: isUnread ? Colors.orange.shade700 : Colors.grey, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(peerName: peer)));
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}