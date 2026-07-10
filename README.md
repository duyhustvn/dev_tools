# Dev Tools Pro Max

Ứng dụng Flutter hỗ trợ các công cụ phát triển hữu ích (Dev Tools).

---

## 🚀 Hướng dẫn chạy bản Portable (Windows & Linux)

### 💻 Dành cho Windows
Nếu bạn tải bản portable `dev_tools_windows_portable.zip` về:

1. **Giải nén file:** Nhấp chuột phải vào file `.zip` và chọn **Extract All...** (Giải nén tất cả) để giải nén thành một thư mục.
2. **Khởi chạy:** Mở thư mục vừa giải nén và nhấp đúp vào file `dev_tools_pro_max.exe` để chạy ứng dụng.

> [!IMPORTANT]
> Không di chuyển riêng file `dev_tools_pro_max.exe` ra khỏi thư mục của nó mà không mang các file/thư mục khác đi cùng (như thư mục `data/` hoặc các file `.dll`), vì đây là phiên bản portable cần các file đi kèm để hoạt động.

### 🐧 Dành cho Linux
Nếu bạn tải bản portable `dev_tools_linux_portable.tar.gz` về:

1. **Giải nén file:** Nhấp chuột phải chọn **Extract Here** (Giải nén ở đây), hoặc dùng lệnh sau trong Terminal:
   ```bash
   tar -xzvf dev_tools_linux_portable.tar.gz
   ```
2. **Cấp quyền thực thi cho ứng dụng:** Mở terminal tại thư mục giải nén và chạy lệnh:
   ```bash
   chmod +x dev_tools_pro_max
   ```
3. **Khởi chạy:** Chạy ứng dụng bằng lệnh:
   ```bash
   ./dev_tools_pro_max
   ```

> [!IMPORTANT]
> Tương tự Windows, không di chuyển riêng file chạy `dev_tools_pro_max` ra ngoài mà không mang theo thư mục `lib/` và `data/` đi cùng.

---

## 📦 Hướng dẫn tạo bản Release tự động trên GitHub

Dự án đã được cấu hình GitHub Actions tự động tạo **GitHub Release** công khai chứa các bản build portable (Windows & Linux) khi bạn đẩy (push) một tag phiên bản mới lên GitHub.

### Các bước tạo Release:

1. **Tạo một tag phiên bản mới** (tên tag bắt buộc phải bắt đầu bằng chữ `v`):
   ```bash
   git tag v1.0.0
   ```
2. **Push tag này lên GitHub**:
   ```bash
   git push origin v1.0.0
   ```

Hệ thống GitHub Actions sẽ tự động chạy build và tạo một trang Release công khai trên repository của bạn, đính kèm sẵn các file nén `dev_tools_windows_portable.zip` và `dev_tools_linux_portable.tar.gz` để bất kỳ ai cũng có thể tải về dễ dàng.
