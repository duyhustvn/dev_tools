#!/bin/bash

# Lấy đường dẫn tuyệt đối của thư mục hiện tại chứa bản portable
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Cấp quyền chạy cho file thực thi chính
chmod +x "$DIR/dev_tools_pro_max"

# Copy icon vào thư mục icon cá nhân của người dùng để Linux tự nhận dạng
mkdir -p ~/.local/share/icons
if [ -f "$DIR/icon.png" ]; then
  cp "$DIR/icon.png" ~/.local/share/icons/dev_tools_pro_max.png
fi

# Tạo file desktop entry động trong thư mục ứng dụng của người dùng
DESKTOP_FILE=~/.local/share/applications/dev_tools_pro_max.desktop

cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=DevToolsPromax
Exec=$DIR/dev_tools_pro_max
Icon=dev_tools_pro_max
Comment=JsonUI
Categories=Development
Terminal=false
StartupNotify=true
StartupWMClass=com.example.dev_tools_pro_max
EOF

# Cấp quyền cho file desktop
chmod +x "$DESKTOP_FILE"

echo "=========================================================="
echo " Thiết lập bản portable hoàn tất!"
echo " Bây giờ bạn có thể tìm thấy 'DevToolsPromax' trong App Menu."
echo "=========================================================="
