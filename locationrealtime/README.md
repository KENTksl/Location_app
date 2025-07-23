# Location Real-time App

Ứng dụng chia sẻ vị trí real-time với tính năng chat và kết bạn.

## Tính năng chính

### 🔐 Authentication
- Đăng nhập/Đăng ký với Firebase Auth
- Quên mật khẩu
- Auto-login khi đã đăng nhập

### 🗺️ Location Sharing
- Chia sẻ vị trí real-time
- Cập nhật vị trí tự động mỗi phút
- Hiển thị vị trí bạn bè trên bản đồ
- Google Maps integration

### 👥 Friend System
- Tìm kiếm bạn bè bằng email
- Gửi lời mời kết bạn
- Chấp nhận/từ chối lời mời
- Danh sách bạn bè

### 💬 Chat
- Chat real-time với bạn bè
- Danh sách tin nhắn
- Hiển thị tin nhắn cuối cùng
- Push notifications cho tin nhắn mới

### 🔔 Notifications
- Push notifications cho lời mời kết bạn
- Push notifications cho tin nhắn mới
- Firebase Cloud Messaging

## Cài đặt

### 1. Prerequisites
- Flutter SDK (3.8.1+)
- Android Studio / VS Code
- Firebase project

### 2. Setup Firebase
1. Tạo project trên [Firebase Console](https://console.firebase.google.com/)
2. Thêm Android app với package name: `com.example.locationrealtime`
3. Tải file `google-services.json` và đặt vào `android/app/`
4. Bật Authentication với Email/Password
5. Bật Realtime Database
6. Bật Cloud Messaging

### 3. Setup Google Maps
1. Tạo project trên [Google Cloud Console](https://console.cloud.google.com/)
2. Bật Maps SDK for Android
3. Tạo API key
4. Thêm API key vào `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>
```

### 4. Cài đặt dependencies
```bash
flutter pub get
```

### 5. Chạy ứng dụng
```bash
flutter run
```

## Cấu trúc Database

### Users
```
users/
  {userId}/
    email: string
    createdAt: timestamp
    fcmToken: string
    friends/
      {friendId}: boolean
```

### Locations
```
locations/
  {userId}/
    lat: number
    lng: number
    timestamp: string
```

### Friend Requests
```
friend_requests/
  {userId}/
    {requesterId}: boolean
```

### Chats
```
chats/
  {chatId}/
    messages: array
      - from: string
      - text: string
      - timestamp: number
```

### Notifications
```
notifications/
  {userId}/
    {notificationId}/
      type: string
      senderId: string
      senderEmail: string
      message: string
      timestamp: string
      read: boolean
```

## Permissions

### Android
Thêm vào `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

## Troubleshooting

### Lỗi Google Maps
- Kiểm tra API key đã được cấu hình đúng
- Đảm bảo Maps SDK for Android đã được bật
- Kiểm tra package name trong Firebase project

### Lỗi Location
- Kiểm tra GPS đã được bật
- Cấp quyền location cho app
- Kiểm tra internet connection

### Lỗi Firebase
- Kiểm tra `google-services.json` đã được đặt đúng vị trí
- Đảm bảo Firebase project đã được cấu hình đúng
- Kiểm tra Realtime Database rules

## Tính năng nâng cao có thể thêm

- [ ] Voice messages
- [ ] Image sharing
- [ ] Group chat
- [ ] Location history
- [ ] Geofencing
- [ ] Emergency SOS
- [ ] Route sharing
- [ ] Offline mode
- [ ] Dark theme
- [ ] Multi-language support
