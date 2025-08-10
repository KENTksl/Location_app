import 'package:mockito/annotations.dart';
import 'package:locationrealtime/services/auth_service.dart';
import 'package:locationrealtime/services/user_service.dart';
import 'package:locationrealtime/services/friend_service.dart';
import 'package:locationrealtime/services/chat_service.dart';
import 'package:locationrealtime/services/location_history_service.dart';
import 'package:locationrealtime/services/geolocator_wrapper.dart';

// Generate mocks for all services
@GenerateMocks([
  AuthService,
  UserService,
  FriendService,
  ChatService,
  LocationHistoryService,
  GeolocatorWrapper,
])
void main() {}
