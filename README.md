# ntpc_garbage_map - 台灣垃圾車地圖專案

## 目的 (Purpose)
本專案的主要目的是開發一個整合台灣五大直轄市（台北、新北、台中、台南、高雄）垃圾車即時位置與清運站點資訊的行動應用程式。透過整合政府開放資料 API，讓使用者能夠輕鬆在地圖上查看垃圾車的即時動態與清運班表。

## 作用 (Role)
本專案作為前端展示與資料處理中心，負責：
1. **資料介接**：從政府開放資料平台獲取即時與靜態的垃圾車資訊。
2. **資料處理**：統一化不同城市、不同格式（JSON/CSV）的資料來源。
3. **地圖展示**：在 Google Maps 上即時呈現垃圾車位置及清運點位。
4. **離線支援**：透過 SQLite 本地資料庫儲存班表資訊，確保在網路不穩時仍能提供基本服務。

---

## 開始使用 (Getting Started)

本專案是一個 Flutter 應用程式的起點。

如果您是第一次接觸 Flutter 專案，以下資源可以協助您開始：

- [學習 Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [撰寫您的第一個 Flutter App](https://docs.flutter.dev/get-started/codelab)
- [Flutter 學習資源](https://docs.flutter.dev/reference/learning-resources)

如需 Flutter 開發的協助，請參閱[線上文件](https://docs.flutter.dev/)，其中提供了教學、範例、行動開發指南以及完整的 API 參考。
