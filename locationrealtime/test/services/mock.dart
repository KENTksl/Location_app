import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:locationrealtime/services/geolocator_wrapper.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseDatabase,
  UserCredential,
  User,
  DatabaseReference,
  DataSnapshot,
  GeolocatorWrapper,
  DatabaseEvent
])
void main() {}
