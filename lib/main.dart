import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Dodany import
import 'firebase_options.dart';
import 'main_navigation.dart';
import 'screens/login_screen.dart'; // Dodany import ekranu logowania

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ActivIoApp());
}

class ActivIoApp extends StatelessWidget {
  const ActivIoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Activ.io',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      // Tutaj wchodzi nasz bramkarz:
      home: StreamBuilder<User?>(
        // Nasłuchujemy, czy na koncie zaszła zmiana (ktoś się zalogował/wylogował)
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Jeśli Firebase mówi, że użytkownik JEST w systemie -> wpuszczamy do aplikacji
          if (snapshot.hasData) {
            return const MainNavigation();
          }
          // Jeśli użytkownika NIE MA -> wyrzucamy na ekran logowania
          return const LoginScreen();
        },
      ),
    );
  }
}
