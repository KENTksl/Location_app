import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:locationrealtime/services/geolocator_wrapper.dart';

@GenerateMocks([
  // Firebase services
  firebase_auth.FirebaseAuth,
  FirebaseDatabase,
  firebase_auth.UserCredential,
  firebase_auth.User,
  DatabaseReference,
  DataSnapshot,
  DatabaseEvent,
  FirebaseApp,
  // App services
  GeolocatorWrapper,
])
void main() {}
