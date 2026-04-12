# 🫀 Health Monitor — Flutter 健康監測 App

透過**藍芽 BLE** 連接商業健康裝置，以及利用**相機 rPPG 影像辨識**技術即時測量生命徵象，並將所有數據儲存於本地 SQLite 資料庫。

---

## 📱 功能總覽

| 功能 | 說明 |
|------|------|
| 🔵 藍芽連接 | 支援標準 BLE GATT Profile 裝置 |
| 📷 影像心率 | rPPG 演算法，手指覆蓋相機即可測量 |
| 💾 本地資料庫 | SQLite 儲存，支援歷史查詢與統計 |
| 📊 趨勢圖表 | 血壓/心率/血氧/體重折線圖 |
| ✍️ 手動輸入 | 支援手動補登任何健康數值 |

---

## 📡 支援藍芽裝置（標準 BLE GATT）

| 裝置類型 | Service UUID | Characteristic |
|---------|-------------|----------------|
| 血壓計 | `0x1810` | `0x2A35` Blood Pressure Measurement |
| 心率帶 | `0x180D` | `0x2A37` Heart Rate Measurement |
| 體重計 | `0x181D` | `0x2A9D` Weight Measurement |
| 血氧儀 | `0x1822` | `0x2A5F` PLX Continuous Measurement |

支援品牌舉例：Omron 歐姆龍血壓計、Withings 體重計、Garmin/Polar 心率帶、Nonin 血氧儀

---

## 📷 影像辨識原理（rPPG）

```
手指覆蓋後置鏡頭 + 開啟閃光燈（torch mode）
    ↓
連續擷取 30fps 影像幀
    ↓
提取中央 ROI 區域 YUV → RGB 平均值
    ↓
紅色通道信號：去趨勢 → 帶通濾波（0.7~3.5 Hz）
    ↓
DFT 頻域分析 → 主頻率 × 60 = 心率 (bpm)
    ↓
R = (AC_red/DC_red) / (AC_green/DC_green) → SpO2 ≈ 110 - 25×R
```

> ⚠️ 此為估算技術，精度不及醫療級裝置，僅供參考用途

---

## 🗄️ 資料庫結構（SQLite）

```sql
-- 健康測量記錄
CREATE TABLE health_records (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp   INTEGER NOT NULL,     -- Unix ms
  systolic    INTEGER,              -- 收縮壓 mmHg
  diastolic   INTEGER,              -- 舒張壓 mmHg
  heart_rate  INTEGER,              -- 心率 bpm
  weight      REAL,                 -- 體重 kg
  spo2        REAL,                 -- 血氧 %
  source      TEXT,                 -- bluetooth | camera | manual
  device_name TEXT,
  notes       TEXT
);

-- 已配對裝置
CREATE TABLE paired_devices (
  device_id   TEXT UNIQUE,
  device_name TEXT,
  device_type TEXT,
  last_connected INTEGER
);
```

---

## 🚀 快速開始

### 環境需求
- Flutter SDK 3.0+
- Dart 3.0+
- Android SDK 21+ (Android 5.0)
- iOS 13+

### 安裝步驟

```bash
# 1. 複製專案
git clone <repo_url>
cd health_monitor

# 2. 安裝依賴
flutter pub get

# 3. 建立 assets 目錄
mkdir -p assets/animations assets/images

# 4. 執行
flutter run
```

### 加入 provider 依賴

在 `pubspec.yaml` 的 dependencies 加入：
```yaml
provider: ^6.1.2
```

---

## 📁 專案結構

```
lib/
├── main.dart                         # App 入口 & 主題設定
├── models/
│   └── health_record.dart            # 資料模型 + 健康狀態評估
├── database/
│   └── health_database.dart          # SQLite CRUD 操作
├── services/
│   ├── bluetooth_service.dart        # BLE 掃描/連接/GATT 解析
│   └── camera_health_service.dart    # rPPG 演算法 + 相機控制
├── screens/
│   ├── home_screen.dart              # 首頁儀表板
│   ├── bluetooth_scan_screen.dart    # 藍芽掃描 & 連接
│   ├── camera_measurement_screen.dart # 影像測量
│   ├── history_screen.dart           # 歷史記錄 + 圖表
│   └── manual_entry_screen.dart      # 手動輸入
└── widgets/
    ├── metric_card.dart              # 健康指標卡片
    └── health_ring_chart.dart        # 統計圓餅圖
```

---

## 🔧 擴充建議

- **雲端同步**：整合 Firebase Firestore 或 Supabase
- **Apple Health / Google Fit**：使用 `health` 套件同步數據
- **AI 分析**：將數據發送給 Claude API 進行健康趨勢分析
- **通知提醒**：`flutter_local_notifications` 定時提醒量測
- **匯出報告**：整合 PDF 產生功能生成醫療報告
