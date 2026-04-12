# Health Monitor 開發任務清單

## ✅ 已完成項目
- [x] **自動步數偵測功能**
  - [x] 新增 `pedometer` 依賴與權限配置。
  - [x] 擴充 `HealthDatabase` 新增 `daily_steps` 表。
  - [x] 實作 `StepProvider` 與自動跨日結算邏輯。
  - [x] 首頁 UI 整合顯示即時步數。

- [x] **專業檢驗報告 Dashboard (參考 c.PNG)**
  - [x] 建立 `LabResult` 全域資料模型。
  - [x] 開發 `LabMetricCard` 趨勢圖組件 (使用 `fl_chart`)。
  - [x] 製作 `LabReportScreen` 網格佈局與篩選功能。
  - [x] 適配深色模式與現代化視覺風格。

## 🚀 待辦項目
- [ ] 檢驗報告數據與資料庫串接 (目前為 Dummy Data)。
- [ ] 歷史趨勢圖表頁面優化。
- [ ] 匯出檢驗報告 PDF/CSV 功能。
