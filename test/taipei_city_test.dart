/// - **測試目的**: 台北市整合與 Provider 測試：驗證城市切換邏輯及對應服務的提供，確保台北市配置正確載入。
/// - **測試覆蓋**: 
///   - 預設城市（新北市）驗證。
///   - 城市切換（至台北市）後 CityConfig（標題、顏色、中心點）更新驗證。
///   - garbageServiceProvider 依據城市回傳正確服務類別（Taipei/Ntpc）。
///   - 台北市 API URL 常數正確性檢查。
/// - **測試執行順序**: 建立 ProviderContainer -> 驗證初始城市 -> 執行城市切換並讀取配置 -> 讀取服務提供者並驗證實例類別。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';
import 'package:ntpc_garbage_map/services/taipei_garbage_service.dart';
import 'package:ntpc_garbage_map/services/ntpc_garbage_service.dart';

void main() {
  group('Taipei City Integration & Provider Tests', () {
    /// 台北市整合與 Provider 測試：驗證城市切換邏輯及對應服務的提供
    test('Default city should be ntpc', () {
      /// 測試預設城市：驗證 App 啟動時預設城市是否為新北市
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final city = container.read(citySelectionProvider);
      final config = container.read(currentCityConfigProvider);

      expect(city, equals('ntpc'));
      expect(config.cityName, equals('ntpc'));
      expect(config.appTitle, contains('新北市'));
    });

    test('Switching to taipei should update CityConfig', () {
      /// 測試城市切換：驗證切換到台北市後，城市設定（標題、顏色、中心點）是否正確更新
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 切換城市
      container.read(citySelectionProvider.notifier).setCity('taipei');

      final city = container.read(citySelectionProvider);
      final config = container.read(currentCityConfigProvider);

      expect(city, equals('taipei'));
      expect(config.cityName, equals('taipei'));
      expect(config.appTitle, contains('台北市'));
      expect(config.themeColor, equals(Colors.blue));
      // 檢查初始中心點是否在台北市附近
      expect(config.initialCenter.latitude, closeTo(25.03, 0.05));
      expect(config.initialCenter.longitude, closeTo(121.56, 0.05));
    });

    test('garbageServiceProvider should return TaipeiGarbageService when city is taipei', () {
      /// 測試服務提供者：驗證當城市選為台北市時，Provider 是否回傳 TaipeiGarbageService 實例
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(citySelectionProvider.notifier).setCity('taipei');
      final service = container.read(garbageServiceProvider);

      expect(service, isA<TaipeiGarbageService>());
    });

    test('garbageServiceProvider should return NtpcGarbageService when city is ntpc', () {
      /// 測試服務提供者：驗證當城市選為新北市時，Provider 是否回傳 NtpcGarbageService 實例
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(citySelectionProvider.notifier).setCity('ntpc');
      final service = container.read(garbageServiceProvider);

      expect(service, isA<NtpcGarbageService>());
    });
  });

  group('TaipeiGarbageService Logic Tests', () {
    /// TaipeiGarbageService 邏輯測試：驗證服務相關的常數設定
    test('Taipei API URL should be correct', () {
      /// 測試 API URL：驗證台北市垃圾車 API 的 URL 是否包含正確的 domain 與 Dataset ID
      expect(TaipeiGarbageService.apiUrl, contains('data.taipei'));
      expect(TaipeiGarbageService.apiUrl, contains('a6e90031-7ec4-4089-afb5-361a4efe7202'));
    });
  });
}
