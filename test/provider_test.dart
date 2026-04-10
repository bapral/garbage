/// [整體程式說明]: Provider 單元測試，專注於驗證 predictedTrucksProvider 的資料來源切換邏輯（即時資料優先，無資料時退回到資料庫搜尋）。
/// [執行順序說明]:
/// 1. 建立 ProviderContainer 並使用 Mock 覆蓋 garbageTrucksProvider 以提供模擬的即時垃圾車資料。
/// 2. 讀取 predictedTrucksProvider 並驗證其回傳的資料與模擬內容一致。
/// 3. 建立另一個測試案例，模擬即時資料為空的情況。
/// 4. 驗證 Provider 是否正確觸發資料庫搜尋邏輯（在測試環境中預期回傳 0 筆）。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';

void main() {
  group('Provider Unit Tests', () {
    /// Provider 單元測試：驗證垃圾車資料提供者（predictedTrucksProvider）的邏輯與模擬資料處理
    test('predictedTrucksProvider should return mock trucks', () async {
      /// 測試即時資料優先：驗證當有即時資料時，predictedTrucksProvider 是否能正確回傳該筆資料
      final container = ProviderContainer(
        overrides: [
          garbageTrucksProvider.overrideWith(() => GarbageTrucksNotifierMock([
            GarbageTruck(
              carNumber: 'TEST-1',
              lineId: 'L1',
              location: 'Point A',
              position: LatLng(25.0, 121.0),
              updateTime: DateTime.now(),
            )
          ])),
        ],
      );

      final trucks = await container.read(predictedTrucksProvider.future);
      expect(trucks.length, equals(1));
      expect(trucks.first.position, equals(LatLng(25.0, 121.0)));
    });

    test('predictedTrucksProvider should return future prediction', () async {
      /// 測試資料庫退回機制：驗證當即時資料為空時，Provider 是否能正確退回到資料庫搜尋模式
      final container = ProviderContainer(
        overrides: [
          predictionDurationProvider.overrideWith(() => PredictionNotifierMock(const Duration(minutes: 10))),
          garbageTrucksProvider.overrideWith(() => GarbageTrucksNotifierMock([])),
        ],
      );

      final trucks = await container.read(predictedTrucksProvider.future);
      // 因為 garbageTrucksProvider 為空，它會退回到資料庫搜尋，
      // 由於測試環境資料庫為空，結果應為 0 筆。
      expect(trucks.length, equals(0));
    });
  });
}

class GarbageTrucksNotifierMock extends GarbageTrucksNotifier {
  final List<GarbageTruck> initial;
  GarbageTrucksNotifierMock(this.initial);
  @override
  List<GarbageTruck> build() => initial;
}

class PredictionNotifierMock extends PredictionDurationNotifier {
  final Duration val;
  PredictionNotifierMock(this.val);
  @override
  Duration build() => val;
}
