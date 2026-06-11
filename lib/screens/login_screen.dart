import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Narzędzia do czytania tekstu z pól
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true; // Przełącznik: Logowanie czy Rejestracja
  bool _isLoading = false; // Przełącznik kółka ładowania

  // Funkcja autoryzacji
  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        // Próba logowania
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // Próba rejestracji
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Jeśli coś pójdzie nie tak (np. złe hasło), pokazujemy błąd na dole ekranu
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Wystąpił błąd autoryzacji')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo / Tytuł
              const Text(
                'Activ.io',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 48),

              // Pole E-mail
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              // Pole Hasło
              TextField(
                controller: _passwordController,
                obscureText: true, // Ukrywa wpisywane znaki
                decoration: const InputDecoration(
                  labelText: 'Hasło',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),

              // Główny przycisk
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isLoading ? null : _authenticate,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isLogin ? 'Zaloguj się' : 'Zarejestruj się',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),

              // Przycisk zmiany trybu (Logowanie <-> Rejestracja)
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin; // Odwraca wartość
                  });
                },
                child: Text(
                  _isLogin
                      ? 'Nie masz konta? Zarejestruj się'
                      : 'Masz już konto? Zaloguj się',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
