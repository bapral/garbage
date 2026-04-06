import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';

void main() {
  group('Provider Unit Tests', () {
    test('predictedTrucksProvider should return mock trucks', () async {
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
