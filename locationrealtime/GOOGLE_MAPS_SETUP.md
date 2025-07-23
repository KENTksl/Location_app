# Hướng dẫn cấu hình Google Maps API
#abcxyz


## Bước 1: Tạo Google Cloud Project

1. Truy cập [Google Cloud Console](https://console.cloud.google.com/)
2. Tạo project mới hoặc chọn project có sẵn
3. Đặt tên project (ví dụ: "location-tracking-app")

## Bước 2: Bật Google Maps API

1. Trong Google Cloud Console, chọn project của bạn
2. Vào "APIs & Services" > "Library"
3. Tìm và bật các API sau:
   - **Maps SDK for Android**
   - **Maps SDK for iOS** (nếu cần)
   - **Places API** (cho geocoding)
   - **Geocoding API**

## Bước 3: Tạo API Key

1. Vào "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "API Key"
3. Copy API key được tạo

## Bước 4: Cấu hình API Key

### Cách 1: Cập nhật AndroidManifest.xml
Thay thế trong file `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE" />
```

### Cách 2: Cập nhật MapsConfig
Thay thế trong file `lib/utils/maps_config.dart`:

```dart
static const String googleMapsApiKey = 'YOUR_ACTUAL_API_KEY_HERE';
```
## Bước 5: Giới hạn API Key (Khuyến nghị)

1. Trong Google Cloud Console, click vào API key
2. Vào tab "Application restrictions"
3. Chọn "Android apps"
4. Thêm package name: `com.example.locationrealtime`
5. Thêm SHA-1 certificate fingerprint

## Bước 6: Kiểm tra

1. Chạy `flutter clean`
2. Chạy `flutter pub get`
3. Chạy `flutter run`

## Lưu ý quan trọng:

- **API key miễn phí**: Google Maps có 200$ credit miễn phí mỗi tháng
- **Bảo mật**: Luôn giới hạn API key theo package name
- **Debug vs Release**: Cần thêm cả SHA-1 debug và release

## Troubleshooting:

### Lỗi "Maps API key not found":
- Kiểm tra API key trong AndroidManifest.xml
- Đảm bảo Maps SDK for Android đã được bật

### Lỗi "This app won't run unless you update Google Play services":
- Cập nhật Google Play Services trên thiết bị
- Hoặc sử dụng thiết bị khác

### Bản đồ không hiển thị:
- Kiểm tra kết nối internet
- Kiểm tra API key có đúng không
- Kiểm tra quyền truy cập vị trí

## API Key mẫu (chỉ để test):
```
AIzaSyB-EXAMPLE-KEY-PLEASE-REPLACE
```

**Lưu ý**: API key mẫu này sẽ không hoạt động. Bạn cần tạo API key thật theo hướng dẫn trên. 