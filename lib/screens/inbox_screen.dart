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
  late String _safeCurrentUserName;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final rawName = user?.email?.split('@')[0] ?? "Nieznajomy";
    final uniqueId = user?.uid.substring(0, 4) ?? "0000";
    String realName = "$rawName#$uniqueId";

    _safeCurrentUserName = realName
        .replaceAll('#', '-HASH-')
        .replaceAll('.', '-DOT-');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: databaseReference.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          );
        }

        List<String> myChats = [];

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          data.forEach((key, value) {
            String chatId = key.toString();
            if (chatId.contains(_safeCurrentUserName)) {
              String peerNameSafe = chatId
                  .replaceAll(_safeCurrentUserName, "")
                  .replaceAll("__", "");

              String peerName = peerNameSafe
                  .replaceAll('-HASH-', '#')
                  .replaceAll('-DOT-', '.');

              if (peerName.isNotEmpty) {
                myChats.add(peerName);
              }
            }
          });
        }

        if (myChats.isEmpty) {
          return const Center(
            child: Text(
              "Nie masz jeszcze żadnych wiadomości.\nKliknij w pinezkę na mapie, żeby zacząć rozmowę!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: myChats.length,
          itemBuilder: (context, index) {
            final peer = myChats[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: const Icon(Icons.person, color: Colors.orange),
              ),
              title: Text(
                peer,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: const Text("Kliknij, aby otworzyć konwersację"),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(peerName: peer),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
