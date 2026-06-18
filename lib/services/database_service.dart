import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  DatabaseService._privateConstructor();

  static final DatabaseService _instance = DatabaseService._privateConstructor();

  static DatabaseService get instance => _instance;

  final DatabaseReference adsRef = FirebaseDatabase.instance.ref("ads");

  Future<void> addAd(Map<String, dynamic> adData) async {
    await adsRef.push().set(adData);
  }
}