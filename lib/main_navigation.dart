import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'screens/map_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  late String _currentUserName;
  late String _safeCurrentUserName;
  int _unreadMessagesCount = 0;

  // admin
  final String adminEmail = "xwisniax96@gmail.com";

  final List<Widget> _screens = [
    const MapScreen(),
    const InboxScreen(),
    const StatsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupSafeUserName();
    _listenForUnreadMessages();
  }

  void _setupSafeUserName() {
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

  void _listenForUnreadMessages() {
    FirebaseDatabase.instance.ref("chats").onValue.listen((event) {
      if (!mounted) return;

      int unreadTotal = 0;
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          String chatId = key.toString();
          if (chatId.contains(_safeCurrentUserName)) {
            if (value is Map) {
              value.forEach((msgKey, msgValue) {
                if (msgValue is Map) {
                  List<dynamic> readBy = List.from(msgValue["readBy"] ?? []);
                  if (!readBy.contains(_currentUserName)) {
                    unreadTotal++;
                  }
                }
              });
            }
          }
        });
      }

      setState(() {
        _unreadMessagesCount = unreadTotal;
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(_unreadMessagesCount.toString()),
              isLabelVisible: _unreadMessagesCount > 0,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              child: const Icon(Icons.forum),
            ),
            label: 'Czaty',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Feed',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
