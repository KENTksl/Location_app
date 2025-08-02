# Sửa lỗi chức năng ghi lộ trình

## Vấn đề đã phát hiện:

1. **Xung đột StreamSubscription**: Biến `_locationSubscription` được sử dụng cho cả việc theo dõi vị trí bạn bè và ghi lộ trình
2. **Thiếu debug logging**: Không có thông tin chi tiết về quá trình ghi lộ trình
3. **Thiếu thông tin debug trên UI**: Không hiển thị trạng thái ghi lộ trình

## Các thay đổi đã thực hiện:

### 1. Tách riêng StreamSubscription cho ghi lộ trình:

- **Đổi tên biến**: `_locationSubscription` → `_routeLocationSubscription`
- **Cập nhật tất cả references**: Thay đổi tất cả các chỗ sử dụng biến này
- **Tránh xung đột**: Giờ có 2 stream riêng biệt cho bạn bè và ghi lộ trình

### 2. Thêm debug logging chi tiết:

- **Trong `_startRouteRecording()`**: Log khi bắt đầu ghi lộ trình
- **Trong `_onLocationUpdate()`**: Log mỗi khi có cập nhật vị trí
- **Kiểm tra permission**: Log khi permission bị từ chối
- **Kiểm tra vị trí hiện tại**: Log khi không lấy được vị trí

### 3. Thêm thông tin debug trên UI:

- **Recording status**: Hiển thị trạng thái đang ghi lộ trình
- **Route points count**: Hiển thị số điểm đã ghi
- **Debug card**: Thêm thông tin chi tiết ở góc màn hình

## Cách hoạt động mới:

1. **Khi nhấn nút ghi lộ trình**:
   - Kiểm tra permission
   - Lấy vị trí hiện tại
   - Bắt đầu stream theo dõi vị trí
   - Hiển thị thông báo thành công

2. **Khi di chuyển**:
   - Stream cập nhật vị trí real-time
   - Kiểm tra xem có nên thêm điểm mới không
   - Lưu điểm vào route hiện tại
   - Cập nhật UI

3. **Khi dừng ghi lộ trình**:
   - Kiểm tra route có hợp lệ không
   - Lưu route vào local storage và Firebase
   - Hiển thị thông báo thành công

## Debug thông tin:

- **Console logs**: Kiểm tra console để xem quá trình ghi lộ trình
- **Debug card**: Xem thông tin real-time trên màn hình
- **Recording status**: Kiểm tra trạng thái đang ghi

## Test:

1. Nhấn nút ghi lộ trình (nút play)
2. Di chuyển xung quanh
3. Kiểm tra debug card để xem số điểm tăng
4. Nhấn nút dừng (nút stop)
5. Kiểm tra xem lộ trình có được lưu không

## Lưu ý:

- Cần cấp quyền vị trí để ghi lộ trình
- Cần bật GPS để có độ chính xác cao
- Route phải có ít nhất 2 điểm và khoảng cách > 1m
- Thời gian ghi phải > 3 giây 