# RealGuide-Migrate

Bộ công cụ chuyển RealGUIDE (Zimmer Biomet / ZimVie) sang máy khác: **backup thư viện implant/sleeve** trên máy cũ, **tạo junction** đưa dữ liệu ra ổ khác và **khôi phục thư viện** trên máy mới. Tất cả chạy bằng PowerShell có sẵn trên Windows, không cần cài thêm.

## Vì sao cần bộ này

- RealGUIDE ghi cứng dữ liệu vào `%APPDATA%\RealguideZimmerBiomet` (thư viện ~8.5 GB), `%APPDATA%\RealGUIDE50-DB` (bệnh nhân, có thể hàng chục GB), `%LOCALAPPDATA%\RealGUIDE` (QML cache) và `C:\NNT`. Không có tùy chọn đổi nơi lưu → dùng **junction** để trỏ sang ổ D/E.
- Server ZimVie EU hiện trả rỗng cho gói sleeve → máy mới cài sạch sẽ tải thiếu và báo *"Polygon count is zero"*. Mang thư viện lành + các file `.stl.dec` đã "chốt sổ" từ máy cũ sang là cách chắc chắn nhất.

## Cài đặt

**Yêu cầu**: Windows 10/11, PowerShell 5.1 (có sẵn), quyền Administrator (để tạo junction). Không cần cài thêm gì.

### Cách 1 — Tải ZIP (không cần Git)

1. Vào <https://github.com/tjmyou123/RealGuide-Migrate> → nút xanh **Code** → **Download ZIP**.
2. Chuột phải file ZIP → **Properties** → tick **Unblock** → OK (bỏ cờ "tải từ Internet", nếu không SmartScreen sẽ chặn `.cmd`).
3. Giải nén vào chỗ cố định, VD `D:\Tools\RealGuide-Migrate\` (tránh Desktop/Downloads vì thư mục này sẽ được copy kèm vào backup).
4. Double-click **`RealGuide-Migrate.cmd`** → chọn **Yes** ở hộp UAC → giao diện mở lên.

Nếu quên bước 2 và bị chặn: mở PowerShell tại thư mục vừa giải nén, chạy
```powershell
Get-ChildItem -Recurse | Unblock-File
```

### Cách 2 — Git

```powershell
git clone https://github.com/tjmyou123/RealGuide-Migrate.git D:\Tools\RealGuide-Migrate
D:\Tools\RealGuide-Migrate\RealGuide-Migrate.cmd
```
Cập nhật sau này: `git pull` trong thư mục đó.

### Trên máy mới không có Internet

Không cần tải gì: bản backup do tool tạo đã **kèm sẵn bộ công cụ** trong `…\RealGuideLibrary-<ngày>\RealGuide-Migrate\`. Cắm USB, chạy `RealGuide-Migrate.cmd` từ đó — tab 3 sẽ tự điền thư mục backup.

### Lỗi khi mở

| Hiện tượng | Xử lý |
|---|---|
| "Windows protected your PC" (SmartScreen) | **More info → Run anyway**, hoặc Unblock như trên |
| Cửa sổ nháy rồi tắt / báo *running scripts is disabled* | File `.cmd` đã dùng `-ExecutionPolicy Bypass`; nếu vẫn lỗi, chạy PowerShell **Admin**: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| Tiêu đề cửa sổ báo *KHÔNG có quyền Admin* | Đóng, chuột phải `RealGuide-Migrate.cmd` → **Run as administrator** |
| Chữ trên giao diện thành `?` | Kiểm tra `scripts\Strings.vi.txt` còn là UTF-8 (đừng mở bằng Notepad cũ rồi Save As ANSI) |

Bên trong tool còn có **Tab 5 Hướng dẫn** với quy trình chi tiết từng bước.

## Giao diện (khuyến nghị)

Double-click **`RealGuide-Migrate.cmd`** (tự xin Admin) → cửa sổ gồm:

- **Trạng thái**: tự tìm 4 vị trí dữ liệu, cho biết đang là junction (xanh) hay thư mục thậ t trên C: (cam), dung lượng, app cài ở đâu.
- **Tab 1 Backup (máy cũ)**: chọn đích, tùy chọn kèm DB bệnh nhân / cấu hình → *BẮt đầu backup*.
- **Tab 2 Thư viện có sẵn → USB**: tự quét mọi ổ đĩa tìm các bản backup đã có (cả dạng cũ phẳng `LibraryBackup-*`), chọn 1 dòng → *Dùng cho máy mới* (điền sẵn vào Tab 3) hoặc *Copy sang USB / ổ ngoài* (sao chép nguyên backup + bộ công cụ, không backup lại từ app).
- **Tab 3 Máy mới**: chọn nơi lưu dữ liệu + thư mục backup → *Thiết lậ p máy mới* (hoặc chỉ tạo junction / chỉ khôi phục).
- **Tab 4 Bảo trì**: tìm đường dẫn, kiểm tra, vá sleeve, gỡ junction trước khi Uninstall.
- **Tab 5 Hướng dẫn**: hướng dẫn đầy đủ ngay trong tool (quy trình 4 bước, giải thích junction / dạng backup, FAQ, lỗi thường gặp, dòng lệnh); tự mở rộng che vùng log để đọc, có nút mở cửa sổ lớn và sửa nội dung.
- **Log** đen ở dưới hiện tiến trình thời gian thực; thanh chạy khi đang bậ n; mọi tác vụ nguy hiểm đều hỏi xác nhậ n.

GUI chỉ là lớp vỏ gọi các script bên dưới (chạy tiến trình con, không treo cửa sổ), nên dùng dòng lệnh hay GUI đều cho kết quả như nhau.

Toàn bộ chữ trên giao diện (tiếng Việt có dấu) nằm trong `scripts\Strings.vi.txt` (UTF-8, dạng `Khóa=Giá trị`, `\n` = xuống dòng); nội dung tab Hướng dẫn trong `scripts\Guide.vi.txt` (dòng `## ` = tiêu đề lớn, `### ` = tiêu đề nhỏ). Muốn đổi câu chữ hoặc dịch sang ngôn ngữ khác chỉ cần sửa file này, không cần đụng code. Log của các script con vẫn là tiếng Việt không dấu để hiển thị đúng trên mọi console.

## Bố cục thư mục

```
RealGuide-Migrate\
├─ RealGuide-Migrate.cmd   ← FILE CHẠY CHÍNH (double-click, tự xin Admin, mở giao diện)
├─ README.md
└─ scripts\                ← toàn bộ script bên dưới, không cần đụng vào
   ├─ RealGuide-Migrate.GUI.ps1, Common.ps1, Strings.vi.txt, Guide.vi.txt
   ├─ Backup-Library / Setup-NewMachine / Verify-Setup / Repair-Sleeves / Find-RealGuide (.ps1 + .cmd)
   └─ Setup-Junctions.ps1, Restore-Library.ps1, Export-Backup.ps1
```

Các lệnh dòng lệnh dưới đây chạy từ trong `scripts\`.

## Quy trình 3 bước (dòng lệnh)

### 1. Máy cũ – backup

Double-click `scripts\Backup-Library.cmd`, nhập thư mục đích (USB/ổ ngoài), hoặc:

```powershell
.\Backup-Library.ps1 -Destination "F:\RealGuideBackup" -CloseApp
# Kèm DB bệnh nhân:            -IncludePatientDb
# Kèm cấu hình *.ini/*.set...: -IncludeConfig
```

Kết quả: `F:\RealGuideBackup\RealGuideLibrary-<ngày-giờ>\` gồm
`RealguideZimmerBiomet\` (stldb, stlcaddb, asset_cache, 3D_Templates, templates, *.imp/*.pin, tmp\decs\*.stl.dec), `manifest.json`, và **bản sao bộ công cụ này** để máy mới chạy ngay.

### 2. Máy mới – cài RealGUIDE

Chạy installer gốc (`Zimmer-EU-x64-…-Setup.exe`), đăng nhập tài khoản. Có thể mở app 1 lần rồi đóng, hoặc không cần.

### 3. Máy mới – junction + khôi phục

Cắm ổ backup, vào `…\RealGuideLibrary-<ngày>\RealGuide-Migrate\`, double-click `RealGuide-Migrate.cmd` (giao diện, tab 3 đã điền sẵn thư mục backup) hoặc `scripts\Setup-NewMachine.cmd` (tự xin Admin), nhập nơi lưu dữ liệu (VD `D:\RealGuideData`). Hoặc:

```powershell
.\Setup-NewMachine.ps1 -DataRoot "D:\RealGuideData" -BackupPath "F:\RealGuideBackup\RealGuideLibrary-20260928-0900"
# thêm -RestorePatientDb nếu backup có DB bệnh nhân
```

Script sẽ: đóng app → di chuyển dữ liệu C: hiện có sang `DataRoot` và tạo 4 junction → mirror thư viện từ backup → vá sleeve kẹt → in báo cáo kiểm tra.

## Các script (trong `scripts\`)

| File | Việc |
|---|---|
| `RealGuide-Migrate.cmd` (ở gốc) + `RealGuide-Migrate.GUI.ps1` | **Giao diện** gộp toàn bộ chức năng |
| `Find-RealGuide.ps1/.cmd` | **Tự tìm** RealGUIDE lưu file ở đâu (app, thư viện, DB, cache, junction; `-ScanDrives` quét thêm ổ đĩa) |
| `Backup-Library.ps1/.cmd` | Backup thư viện (+ tùy chọn DB bệnh nhân, cấu hình) |
| `Export-Backup.ps1` | Liệt kê backup có sẵn (`-List`) / sao chép 1 backup sang USB kèm bộ công cụ |
| `Setup-Junctions.ps1` | Tạo/gỡ (`-Undo`) 4 junction, di chuyển dữ liệu, test ghi xuyên |
| `Restore-Library.ps1` | Khôi phục thư viện từ backup (robocopy /MIR, xóa rác 0-byte) |
| `Setup-NewMachine.ps1/.cmd` | Gộp Setup-Junctions + Restore-Library + Verify |
| `Verify-Setup.ps1/.cmd` | Kiểm tra junction, thư viện, sleeve kẹt, registry |
| `Repair-Sleeves.ps1/.cmd` | Vá `.part → .stl.dec` khi báo "Polygon count is zero" |
| `Common.ps1` | Hàm chung (tự tìm đường dẫn, bảng ánh xạ junction, robocopy, xác thực STL, copy bộ công cụ…) |
| `Strings.vi.txt` | Chữ trên giao diện (tiếng Việt có dấu) |
| `Guide.vi.txt` | Nội dung tab Hướng dẫn |

## Tự phát hiện đường dẫn

Mọi script **không hardcode** đường dẫn mà gọi `Find-RealGuidePaths` (trong `Common.ps1`):

1. Registry `HKCU/HKLM\SOFTWARE\RealGUIDE5` → `InstallString` (exe), `UninstallFolder` (thư viện AppData).
2. Quét `%APPDATA%` tìm thư mục `Real*guide*` có dấu hiệu: thư viện (`sleeves.imp`/`stldb`/`asset_cache`), DB bệnh nhân (`xmlStudiesList.xml`/`Storage`).
3. `%LOCALAPPDATA%\RealGUIDE*` (QML cache), `C:\NNT`.
4. `-ScanDrives`: quét các ổ đĩa (sâu 2 cấp) tìm thêm bản sao/backup/dữ liệu đã chuyển tay.

Nếu chưa cài app (máy mới) → dùng tên mặc định (`RealguideZimmerBiomet`, `RealGUIDE50-DB`…) để vẫn tạo junction trước. Nhờ vậy bộ công cụ chạy được với build vendor khác (tên thư mục AppData khác) miễn có registry `RealGUIDE5`.

## Bảng junction

| Đường dẫn RealGUIDE ghi cứng | Trỏ tới |
|---|---|
| `%APPDATA%\RealguideZimmerBiomet` | `<DataRoot>\RealguideZimmerBiomet` |
| `%APPDATA%\RealGUIDE50-DB` | `<DataRoot>\RealGUIDE50-DB` |
| `%LOCALAPPDATA%\RealGUIDE` | `<DataRoot>\RealGUIDE-QmlCache` |
| `C:\NNT` | `<DataRoot>\NNT` |

## Dữ liệu không nằm trong repo

Repo này **chỉ chứa công cụ**. Thư viện RealGUIDE (~8.4 GB: `stldb` implant/sleeve 1.1 GB, `stlcaddb` CAD 3.7 GB, `asset_cache` gói tải về 3.6 GB) và dữ liệu bệnh nhân được lưu riêng trên USB / ổ ngoài bằng Tab 1 hoặc Tab 2 của GUI; `.gitignore` chặn mọi file dữ liệu (`*.stl`, `*.imp`, `RealguideZimmerBiomet/`, `RealGUIDE50-DB/`…).

## Cảnh báo quan trọng

- **Trước khi chạy `Uninstall.exe` của RealGUIDE** phải gỡ junction: `.\Setup-Junctions.ps1 -DataRoot "D:\RealGuideData" -Undo`. Trình gỡ NSIS dùng `RMDir /r` có thể xóa lan qua junction sang dữ liệu thật.
- `-IncludeConfig` / `-RestoreConfig` mang theo `options.ini`, `local_data.set`… của máy cũ; mặc định **không** bật để máy mới giữ cấu hình/đăng nhập riêng.
- Backup cũ dạng phẳng (`LibraryBackup-20260819`, không có thư mục con `RealguideZimmerBiomet`) vẫn khôi phục được bằng `Restore-Library.ps1`.
