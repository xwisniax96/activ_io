import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  String _displayName = "";

  @override
  void initState() {
    super.initState();
    final rawName = _user?.email?.split('@')[0] ?? "Nieznajomy";
    final uniqueId = _user?.uid.substring(0, 4) ?? "0000";

    _displayName = _user?.displayName ?? "$rawName#$uniqueId";
    _nameController.text = _user?.displayName ?? "";
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateNick() async {
    final inputName = _nameController.text.trim();
    if (inputName.isEmpty) return;

    // admin
    final String adminEmail = "xwisniax96@gmail.com";
    final bool isAdmin = _user?.email == adminEmail;

    String secureDisplayName;

    if (isAdmin) {
      secureDisplayName =
          inputName; 
    } else {
      final lowerName = inputName.toLowerCase();
      final forbiddenWords = [
        'admin',
        'moderator',
        'system',
        'activ',
        'root',
        'support',
      ];

      for (String word in forbiddenWords) {
        if (lowerName.contains(word)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Ta nazwa jest zastrzeżona przez system! Wybierz inną.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      final uniqueId = _user?.uid.substring(0, 4) ?? "0000";
      final cleanBaseName = inputName.split('#')[0].trim();
      secureDisplayName = "$cleanBaseName#$uniqueId";
    }

    try {
      final String oldDisplayName = _displayName;
      await _user?.updateDisplayName(secureDisplayName);

      final DatabaseReference adsRef = FirebaseDatabase.instance.ref("ads");
      final snapshot = await adsRef.get();

      if (snapshot.value != null) {
        final updates = <String, dynamic>{};
        final data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          final ad = value as Map<dynamic, dynamic>;
          if (ad['ownerUid'] == _user?.uid || ad['user'] == oldDisplayName) {
            updates["$key/user"] = secureDisplayName;
            updates["$key/ownerUid"] = _user?.uid;
          }
        });

        if (updates.isNotEmpty) {
          await adsRef.update(updates);
        }
      }

      setState(() {
        _displayName = secureDisplayName;
        _nameController.text = isAdmin
            ? secureDisplayName
            : secureDisplayName.split('#')[0];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAdmin
                  ? 'Witaj Szefie! Nick zaktualizowany 👑'
                  : 'Pomyślnie zaktualizowano nick! 🎉',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas zmiany nazwy: $e')),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    try {
      await _user?.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Twoje konto zostało trwale usunięte. Żegnaj! 👋'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Operacja wymaga ponownego zalogowania ze względów bezpieczeństwa!',
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd usuwania konta: ${e.message}')),
        );
      }
    }
  }

  // Okno dialogowe potwierdzające usunięcie konta
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '⚠️ Usuwanie konta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Czy na pewno chcesz bezpowrotnie usunąć swoje konto? Wszystkie Twoje dane zostaną wymazane z systemu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ANULUJ', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount();
            },
            child: const Text(
              'USUŃ KONTO',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Okienka dla FAQ i Regulaminu
  void _showLegalModal(String title, String content) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const Divider(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Mój Profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Avatar i Maile
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.orange.shade100,
              child: const Icon(Icons.person, size: 50, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            Text(
              _displayName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              _user?.email ?? "Brak adresu e-mail",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 30),

            // KAFELEK 1: Zmiana Nicku
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Zmień swój nick publiczny',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              hintText: "np. Biegacz99",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          onPressed: _updateNick,
                          icon: const Icon(Icons.check),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // KAFELEK 2: Dokumenty prawne i FAQ
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.help_outline,
                      color: Colors.orange,
                    ),
                    title: const Text('FAQ / Pomoc'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLegalModal(
                      'Najczęściej zadawane pytania (FAQ)',
                      '1. Jak dodać pinezkę?\nKliknij w dowolne miejsce na mapie, uzupełnij szczegóły i zatwierdź.\n\n2. Kiedy moje ogłoszenie zniknie?\nZniknie automatycznie dokładnie w wyznaczonym przez Ciebie terminie końcowym (max 30 dni).\n\n3. Czy czaty są bezpieczne?\nTak, wiadomości są powiązane bezpośrednio z Twoim bezpiecznym identyfikatorem konta.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.description_outlined,
                      color: Colors.orange,
                    ),
                    title: const Text('Regulamin aplikacji'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLegalModal(
                      'Regulamin Activ.io',
                      'Zasady korzystania z aplikacji:\n1. Zabrania się dodawania ogłoszeń o charakterze obraźliwym, nielegalnym lub spamiarskim.\n2. Użytkownik ponosi pełną odpowiedzialność za treść publikowanych pinezek.\n3. Aplikacja szanuje prywatność i przetwarza dane zgodnie z polityką prywatności RODO.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Przyciski akcji (Wylogowanie i RODO)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async => await FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Wyloguj się',
                  style: TextStyle(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _showDeleteDialog,
                icon: const Icon(Icons.delete_forever),
                label: const Text(
                  'Usuń konto (RODO)',
                  style: TextStyle(fontSize: 14),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
