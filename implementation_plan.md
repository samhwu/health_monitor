# 項目實施計劃：解決 Android 編譯 Java 版本問題

## 核心問題
Android Gradle 插件 (AGP) 8.11.1 版本強制要求運行環境為 Java 17，當前系統環境為 Microsoft Build of OpenJDK 11。

## 解決方案
通過配置專案級別的 Gradle 屬性，引導 Gradle 使用 Android Studio 內建的 JDK 11 (jbr)。

### 實施步驟
1. **修改 `android/gradle.properties`**
   - 確保 `org.gradle.java.home` 被設置為正確的 17 版本路徑。
   - 使用 `\` 轉義空格，確保路徑解析正確。
   
2. **重置 Gradle Daemon**
   - 停止舊版本的 Daemon 並重啟以使環境變量生效。

3. **環境變量檢查 (可選但推薦)**
   - 在終端設置全域 `JAVA_HOME`。

## 已執行更改
在 `android/gradle.properties` 中成功添加配置：
`org.gradle.java.home=/Applications/Android\ Studio.app/Contents/jbr/Contents/Home`
