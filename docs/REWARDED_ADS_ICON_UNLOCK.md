# 🎬 Hướng Dẫn Tính Năng: Xem Quảng Cáo Mở Khóa Icon Ứng Dụng (v5.5.0)

> Tài liệu kỹ thuật chi tiết cho tính năng **Rewarded Ads Icon Unlock** — cho phép người dùng xem hết 1 video quảng cáo AdMob để mở khóa bất kỳ icon ứng dụng nào trong **3 ngày**, thay vì phải đăng ký gói trả phí.

---

## 📋 Mục Lục

1. [Tổng Quan Tính Năng](#tổng-quan-tính-năng)
2. [Luồng Hoạt Động](#luồng-hoạt-động)
3. [Cấu Trúc Code](#cấu-trúc-code)
4. [Điều Kiện Nhận Thưởng (AdMob)](#điều-kiện-nhận-thưởng-admob)
5. [Lưu Trữ & Hết Hạn](#lưu-trữ--hết-hạn)
6. [Badge Đếm Ngược](#badge-đếm-ngược)
7. [Thông Báo & Toast](#thông-báo--toast)
8. [Reset Icon Khi Hết Hạn](#reset-icon-khi-hết-hạn)
9. [Cấu Hình AdMob Console](#cấu-hình-admob-console)
10. [Cấu Hình qua Supabase Admin](#cấu-hình-qua-supabase-admin)
11. [Test & Debug](#test--debug)

---

## 🎯 Tổng Quan Tính Năng

| Thuộc tính | Chi tiết |
|---|---|
| **Mục đích** | Mở khóa icon ứng dụng mà không cần đăng ký gói trả phí |
| **Điều kiện** | Người dùng phải **xem hết toàn bộ** video quảng cáo Rewarded AdMob |
| **Thời hạn** | **3 ngày** tính từ lúc nhận thưởng thành công |
| **Lưu trữ** | `SharedPreferences` trên thiết bị (offline-first) |
| **Platform** | Android & iOS (không áp dụng cho TV, Windows, Web) |
| **Ưu tiên** | Gói đăng ký trả phí > Mở khóa qua quảng cáo |

---

## 🔄 Luồng Hoạt Động

```
Người dùng bấm vào icon bị khóa
        │
        ▼
[Dialog xác nhận] "Bạn có muốn xem quảng cáo để mở khóa icon %name% trong 3 ngày?"
  ┌─────┴─────┐
 [Hủy]     [Đồng ý]
  │            │
  ▼            ▼
 Đóng      Tải quảng cáo Rewarded Ad (AdMob)
           ┌─────────────────────────────────┐
           │ Nếu KHÔNG load được ad:         │
           │  → Toast: "Không thể tải QC"    │
           └─────────────────────────────────┘
                       │
               Quảng cáo phát
                       │
        ┌──────────────┴──────────────┐
   [Đóng trước khi hết]         [Xem hết video]
        │                             │
        ▼                             ▼
  rewarded = false            rewarded = true (AdMob callback)
        │                             │
   Không nhận thưởng           Lưu SharedPreferences:
                               txa_ad_unlocked_expiry_<iconKey>
                               = DateTime.now() + 3 ngày
                                       │
                               [Dialog thành công]
                               "Bạn nhận được icon %name%
                                hạn dùng 3 ngày"
                                       │
                               Badge đếm ngược xuất hiện trên icon
```

---

## 🗂️ Cấu Trúc Code

### File liên quan

| File | Vai trò |
|---|---|
| `lib/pages/txa_custom_icon_screen.dart` | UI màn hình chọn icon, dialog ads, badge đếm ngược |
| `lib/services/txa_dynamic_icon_service.dart` | Logic lưu trữ/kiểm tra ad unlock, expiry |
| `lib/services/txa_ads_service.dart` | Tải và phát Rewarded Ad AdMob |
| `lib/services/txa_auth_service.dart` | `runIconCheck()` kiểm tra hết hạn khi đăng xuất/đăng nhập |
| `lib/services/txa_language.dart` | Chuỗi ngôn ngữ VI/EN cho tính năng |
| `lib/utils/txa_navigator.dart` | `GlobalKey<NavigatorState>` dùng chung (tránh circular import) |
| `lib/main.dart` | Gọi `checkAndRevertExpiredOrUnlicensedIcon()` sau splash |

### Các hàm chính

#### `TxaDynamicIconService`
```dart
// Lưu thông tin mở khóa 3 ngày vào SharedPreferences
static Future<void> saveAdUnlock(String iconKey)

// Kiểm tra icon có đang được mở khóa qua quảng cáo không
static Future<bool> isAdUnlocked(String iconKey)

// Lấy thời gian còn lại dạng Duration
static Future<Duration?> getAdUnlockRemaining(String iconKey)

// Kiểm tra và reset icon về mặc định nếu hết hạn
static Future<bool> checkAndRevertExpiredOrUnlicensedIcon(Map? user)
```

#### `TxaAdsService`
```dart
// Phát Rewarded Ad, callback(true) chỉ khi user xem HẾT
Future<void> showRewardedAd({required Function(bool rewardGranted) onComplete})
```

#### `TxaCustomIconScreen`
```dart
// Mở dialog xác nhận xem quảng cáo
void _showWatchAdDialog(String iconKey, String iconName)

// Phát quảng cáo và xử lý kết quả
Future<void> _playAdToUnlock(String iconKey, String iconName)

// Format thời gian badge đếm ngược
String _formatAdUnlockRemaining(Duration duration)
```

---

## ✅ Điều Kiện Nhận Thưởng (AdMob)

> **Quan trọng:** Người dùng **BẮT BUỘC** phải xem hết toàn bộ video mới được nhận thưởng.

Cơ chế xác thực dựa trên callback chính thức của AdMob SDK:

```dart
ad.show(onUserEarnedReward: (AdWithoutView adView, RewardItem reward) {
  // Callback này CHỈ được gọi khi Google AdMob xác nhận
  // người dùng đã xem đủ thời lượng quy định (thường 15-30s)
  granted = true;  // Đánh dấu đủ điều kiện nhận thưởng
});
```

- Nếu người dùng **tắt quảng cáo trước khi hết** → `onUserEarnedReward` **không được gọi** → `granted = false` → **không nhận được icon**
- Nếu quảng cáo **tải thất bại** → `onComplete(false)` → toast thông báo lỗi
- Nếu quảng cáo **phát thành công và xem hết** → `onComplete(true)` → lưu unlock 3 ngày

---

## 💾 Lưu Trữ & Hết Hạn

### SharedPreferences Key Format

```
txa_ad_unlocked_expiry_<iconKey>
```

Ví dụ:
```
txa_ad_unlocked_expiry_icon_cyber.png  → "2026-08-06T10:35:22.000"
txa_ad_unlocked_expiry_icon_gold.png   → "2026-08-04T08:12:45.000"
```

### Giá trị lưu

- **Format:** ISO 8601 string (`DateTime.toIso8601String()`)
- **Thời hạn:** `DateTime.now() + Duration(days: 3)`
- **Phạm vi:** Lưu trên thiết bị, không đồng bộ server

### Kiểm tra hết hạn

```dart
// Hết hạn → trả về Duration.zero hoặc null
static Future<Duration?> getAdUnlockRemaining(String iconKey) async {
  final expiry = await getAdUnlockExpiry(iconKey);
  if (expiry != null) {
    final diff = expiry.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
  return null;  // Chưa từng mở khóa
}
```

### Ưu tiên permission

```
Admin/SuperAdmin   ← Luôn có quyền
Gói đăng ký trả phí (IAP, VIP)  ← Có quyền trong thời hạn gói
Mở khóa qua quảng cáo  ← Có quyền trong 3 ngày
Icon Default  ← Luôn có quyền (miễn phí)
```

---

## ⏱️ Badge Đếm Ngược

Badge hiển thị trực tiếp **dưới ảnh icon** với đồng hồ đếm ngược realtime (cập nhật mỗi giây).

### Format hiển thị

| Thời gian còn lại | Format Badge |
|---|---|
| ≥ 1 ngày | `Còn 2 ngày 14:32:05` |
| < 1 ngày | `14:32:05` |
| Hết hạn | Badge biến mất, icon về trạng thái khóa |

### Code Timer

```dart
// Khởi tạo timer cập nhật mỗi giây
void _startCountdownTimer() {
  _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    _updateAdUnlockRemainingTimes();
  });
}

// Cập nhật Map thời gian còn lại cho mỗi icon
Future<void> _updateAdUnlockRemainingTimes() async {
  for (final item in TxaDynamicIconService.availableIcons) {
    final key = item['key']!;
    if (key == 'icon_default.png') continue;
    final remaining = await TxaDynamicIconService.getAdUnlockRemaining(key);
    // Nếu thay đổi → setState() rebuild badge
  }
}
```

---

## 🔔 Thông Báo & Toast

### Các thông báo có trong tính năng

| Tình huống | Loại | Nội dung (VI) |
|---|---|---|
| Xem hết quảng cáo thành công | Dialog + Toast | "Bạn đã nhận được phần thưởng là icon **%name%** với hạn sử dụng 3 ngày." |
| Quảng cáo tải thất bại | Toast (lỗi) | "Không thể tải video quảng cáo từ hệ thống." |
| Icon hết hạn khi vào app | Toast (lỗi) | "Hạn sử dụng icon đã hết. Icon đã được đặt lại về mặc định của ứng dụng!" |

### Language Keys

```dart
'watch_ad_unlock_title'     // Tiêu đề dialog xác nhận
'watch_ad_unlock_confirm'   // Nội dung dialog xác nhận (%name% = tên icon)
'ad_reward_success_title'   // Tiêu đề dialog thành công
'ad_reward_success_desc'    // Nội dung dialog thành công (%name% = tên icon)
'ad_load_failed'            // Toast lỗi tải quảng cáo
'icon_expired_reverted'     // Toast thông báo hết hạn
'icon_countdown_prefix'     // Prefix badge ("Còn " / "Remaining: ")
```

---

## 🔄 Reset Icon Khi Hết Hạn

### Khi nào kiểm tra?

1. **Sau Splash Screen** — ngay khi app khởi động xong
2. **Khi đăng xuất** — `TxaAuthService.logout()` gọi `runIconCheck()`
3. **Khi đăng nhập** — `TxaAuthService.initialize()` gọi `runIconCheck()`

### Logic Reset

```dart
static Future<bool> checkAndRevertExpiredOrUnlicensedIcon(Map? user) async {
  final activeIcon = await getActiveIconKey();
  if (activeIcon == 'icon_default.png') return false;  // Đang dùng icon mặc định

  // Nếu có gói đăng ký → không reset
  final hasSub = hasSubscriptionPermission(user);
  if (hasSub) return false;

  // Kiểm tra mở khóa qua quảng cáo còn hạn không
  final adsUnlocked = await isAdUnlocked(activeIcon);
  if (adsUnlocked) return false;

  // Hết hạn → reset về mặc định + báo cáo log
  await setAppIcon('icon_default.png');
  return true;  // Đã reset
}
```

---

## ⚙️ Cấu Hình AdMob Console

### Tạo Rewarded Ad Unit

1. Vào [AdMob Console](https://apps.admob.com)
2. Chọn app → **Ad Units** → **Create ad unit**
3. Chọn loại: **Rewarded** (KHÔNG phải Interstitial)
4. Đặt tên: `DongMePhim - Icon Unlock Reward`
5. Copy **Ad Unit ID** dạng: `ca-app-pub-XXXXXXXX/YYYYYYYY`

### Cập nhật Ad Unit ID vào Supabase

Vào `settings.app` trong Supabase, thêm field:

```json
{
  "ads": {
    "admob_enable": true,
    "admob_rewarded_ad_id": "ca-app-pub-XXXXXXXX/YYYYYYYY",
    "admob_app_start_ad_id": "ca-app-pub-XXXXXXXX/ZZZZZZZZ",
    "admob_preroll_ad_id": "ca-app-pub-XXXXXXXX/WWWWWWWW"
  }
}
```

### Test Ad Unit IDs (không cần cấu hình)

Nếu `admob_rewarded_ad_id` để trống, app tự dùng Test ID:

| Platform | Test Rewarded Ad ID |
|---|---|
| Android | `ca-app-pub-3940256099942544/5224354917` |
| iOS | `ca-app-pub-3940256099942544/1712485313` |

---

## 🔧 Cấu Hình qua Supabase Admin

### Bật/Tắt toàn bộ AdMob

```sql
UPDATE settings
SET value = jsonb_set(value, '{ads,admob_enable}', 'true')
WHERE key = 'app';
```

### Cập nhật Rewarded Ad ID

```sql
UPDATE settings
SET value = jsonb_set(value, '{ads,admob_rewarded_ad_id}', '"ca-app-pub-XXXXXXXX/YYYYYYYY"')
WHERE key = 'app';
```

---

## 🧪 Test & Debug

### Test trên thiết bị thật

1. **Đảm bảo** `admob_enable: true` trong Supabase settings
2. Nếu để trống `admob_rewarded_ad_id` → app dùng **Test Ad** (xanh lá)
3. Bấm vào icon bị khóa → dialog xác nhận xuất hiện
4. Bấm **Đồng ý** → quảng cáo phát
5. Xem hết video → dialog thành công + badge đếm ngược xuất hiện

### Kiểm tra SharedPreferences

```dart
// Debug: in ra tất cả ad unlock expiry
final prefs = await SharedPreferences.getInstance();
final keys = prefs.getKeys().where((k) => k.startsWith('txa_ad_unlocked_expiry_'));
for (final key in keys) {
  print('$key = ${prefs.getString(key)}');
}
```

### Test hết hạn nhanh

Thay đổi tạm thời trong `saveAdUnlock`:

```dart
// Thay Duration(days: 3) thành Duration(seconds: 30) để test nhanh
final expiry = DateTime.now().add(const Duration(seconds: 30));
```

### Log

Các log liên quan được ghi với `type: 'app'`:
```
[APP] User earned reward: 1 coins
[APP] Active app icon (icon_cyber.png) is no longer licensed or has expired. Reverting to default.
```

---

## 📝 Changelog

| Version | Ngày | Thay đổi |
|---|---|---|
| **v5.5.0** | 2026-08-03 | Ra mắt tính năng Rewarded Ads Icon Unlock 3 ngày, Badge đếm ngược, Reset icon hết hạn, fix circular import |
| v5.4.4 | 2026-07-27 | Tích hợp AdMob (App Start + Pre-roll), Dynamic Icon iOS/Windows |
| v5.3.8 | 2026-07-25 | Màn hình chọn icon, kiểm tra quyền mở khóa |
