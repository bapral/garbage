import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';
import 'package:ntpc_garbage_map/services/taipei_garbage_service.dart';
import 'package:ntpc_garbage_map/services/ntpc_garbage_service.dart';

void main() {
  group('Taipei City Integration & Provider Tests', () {
    test('Default city should be ntpc', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final city = container.read(citySelectionProvider);
      final config = container.read(currentCityConfigProvider);

      expect(city, equals('ntpc'));
      expect(config.cityName, equals('ntpc'));
      expect(config.appTitle, contains('新北市'));
    });

    test('Switching to taipei should update CityConfig', () {
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
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(citySelectionProvider.notifier).setCity('taipei');
      final service = container.read(garbageServiceProvider);

      expect(service, isA<TaipeiGarbageService>());
    });

    test('garbageServiceProvider should return NtpcGarbageService when city is ntpc', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(citySelectionProvider.notifier).setCity('ntpc');
      final service = container.read(garbageServiceProvider);

      expect(service, isA<NtpcGarbageService>());
    });
  });

  group('TaipeiGarbageService Logic Tests', () {
    test('Taipei API URL should be correct', () {
      expect(TaipeiGarbageService.apiUrl, contains('data.taipei'));
      expect(TaipeiGarbageService.apiUrl, contains('a6e90031-7ec4-4089-afb5-361a4efe7202'));
    });
  });
}
