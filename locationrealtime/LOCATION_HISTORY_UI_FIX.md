# Sửa lỗi hiển thị UI trong Location History Page

## Vấn đề đã phát hiện:

1. **Lỗi overflow pixel**: Text bị tràn ra ngoài (RIGHT OVERFLOWED BY 31-39 PIXELS)
2. **Tên lộ trình sai**: Hiển thị "Lộ trình đang ghi" thay vì tên thực tế
3. **Layout không responsive**: ListTile không thích ứng với màn hình nhỏ
4. **Thiếu overflow handling**: Không xử lý text dài

## Các thay đổi đã thực hiện:

### 1. Sửa layout để tránh overflow:

- **Thay thế ListTile**: Sử dụng Row và Column thay vì ListTile để kiểm soát layout tốt hơn
- **Thêm Expanded**: Sử dụng Expanded để text có thể co giãn
- **Thêm maxLines và overflow**: Giới hạn số dòng và xử lý text dài
- **Tối ưu spacing**: Điều chỉnh khoảng cách giữa các phần tử

### 2. Sửa tên lộ trình:

- **Kiểm tra tên route**: Nếu tên là "Lộ trình đang ghi" hoặc "Temp" thì tạo tên mới
- **Sử dụng generateRouteName**: Tự động tạo tên dựa trên thời gian
- **Format tên**: "Buổi sáng/chiều/tối DD/MM"

### 3. Cải thiện UI:

- **Responsive layout**: Layout thích ứng với màn hình khác nhau
- **Better spacing**: Khoảng cách hợp lý giữa các phần tử
- **Compact actions**: Nút action nhỏ gọn hơn
- **Text overflow handling**: Xử lý text dài bằng ellipsis

## Cấu trúc layout mới:

```
Row(
  children: [
    Icon Container (50x50),
    SizedBox(width: 15),
    Expanded(
      child: Column(
        children: [
          Title (với overflow handling),
          Time row (với Expanded),
          Distance & Speed row
        ]
      )
    ),
    SizedBox(width: 10),
    Actions Column
  ]
)
```

## Các tính năng đã cải thiện:

1. **Không còn overflow**: Text được xử lý đúng cách
2. **Tên route đúng**: Hiển thị tên thực tế thay vì "Lộ trình đang ghi"
3. **Layout responsive**: Thích ứng với màn hình khác nhau
4. **Better UX**: Giao diện đẹp và dễ sử dụng hơn

## Test:

1. Mở Location History Page
2. Kiểm tra xem có còn lỗi overflow không
3. Kiểm tra tên route có đúng không
4. Test trên màn hình khác nhau

## Lưu ý:

- Tên route sẽ được tự động tạo dựa trên thời gian bắt đầu
- Text dài sẽ được cắt và hiển thị dấu "..." 
- Layout sẽ thích ứng với kích thước màn hình 