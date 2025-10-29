# Hướng Dẫn Test Tính Năng Cuộc Gọi

## Cách Test Cuộc Gọi Giữa 2 Người Dùng

### Phương Pháp 1: Sử Dụng 2 Thiết Bị Khác Nhau
1. **Thiết bị 1 (Caller)**: Đăng nhập tài khoản A (ví dụ: quangminh@gmail.com)
2. **Thiết bị 2 (Receiver)**: Đăng nhập tài khoản B (ví dụ: ngocchien@gmail.com)
3. Từ thiết bị 1, gọi đến tài khoản B
4. Trên thiết bị 2 sẽ hiện màn hình incoming call
5. Chấp nhận cuộc gọi và kiểm tra:
   - Timer có chạy không
   - Âm thanh có hoạt động không
   - Các nút điều khiển có hoạt động không

### Phương Pháp 2: Sử Dụng 1 Thiết Bị (Emulator + Physical Device)
1. **Emulator**: Đăng nhập tài khoản A
2. **Điện thoại thật**: Đăng nhập tài khoản B
3. Thực hiện test tương tự như phương pháp 1

### Phương Pháp 3: Sử Dụng 1 Thiết Bị (Logout/Login)
1. Đăng nhập tài khoản A, gọi đến tài khoản B
2. Logout khỏi tài khoản A
3. Login vào tài khoản B
4. Kiểm tra có nhận được cuộc gọi không
5. Chấp nhận và test

## Các Điểm Cần Kiểm Tra

### 1. Caller (Người Gọi)
- [ ] Hiển thị "Đang kết nối..." khi mới gọi
- [ ] Chuyển thành "Trong cuộc gọi" khi receiver chấp nhận
- [ ] Timer bắt đầu chạy (00:01, 00:02, ...) với màu xanh lá
- [ ] Có thể mute/unmute
- [ ] Có thể bật/tắt loa ngoài
- [ ] Có thể kết thúc cuộc gọi

### 2. Receiver (Người Nhận)
- [ ] Nhận được thông báo cuộc gọi đến
- [ ] Có thể chấp nhận hoặc từ chối
- [ ] Sau khi chấp nhận, timer bắt đầu chạy
- [ ] Các tính năng điều khiển hoạt động

### 3. Âm Thanh
- [ ] Có thể nghe thấy tiếng của nhau
- [ ] Mute hoạt động đúng
- [ ] Loa ngoài hoạt động đúng

## Log Messages Cần Chú Ý

Khi test, hãy chú ý các log sau trong console:

### Caller Logs:
```
📞 CallPage: Starting new call
✅ CallPage: Call started successfully with ID: [call_id]
📞 CallPage: Listening for answer from receiver
📞 CallPage: Call accepted by receiver, updating UI
⏰ CallPage: Call timer started
```

### Receiver Logs:
```
📞 CallPage: Getting call data from Firebase
📞 CallPage: Successfully joined call as receiver
⏰ CallPage: Call timer started
```

## Troubleshooting

### Timer Không Chạy:
- Kiểm tra log có thấy "⏰ CallPage: Call timer started" không
- Đảm bảo cuộc gọi đã được chấp nhận (status = 'accepted')

### Không Nghe Thấy Âm Thanh:
- Kiểm tra quyền microphone
- Thử bật/tắt mute
- Thử chuyển đổi loa ngoài/loa trong

### Cuộc Gọi Không Kết Nối:
- Kiểm tra kết nối internet
- Kiểm tra Firebase configuration
- Xem log có lỗi WebRTC không

## Test Commands

Để xem log chi tiết, chạy:
```bash
flutter run --verbose
```

Hoặc filter log:
```bash
flutter logs | grep "CallPage\|CallService"
```