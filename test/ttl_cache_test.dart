import 'package:fivetogo_scheduler/core/api/ttl_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses a successful value until ttl expires', () async {
    var loads = 0;
    final cache = TtlCache<int>(ttl: const Duration(seconds: 30));

    Future<int> load() async {
      loads += 1;
      return 7;
    }

    expect(await cache.getOrLoad(load), 7);
    expect(await cache.getOrLoad(load), 7);
    expect(loads, 1);

    cache.invalidate();
    expect(await cache.getOrLoad(load), 7);
    expect(loads, 2);
  });

  test('does not cache a failed load', () async {
    var loads = 0;
    final cache = TtlCache<int>(ttl: const Duration(seconds: 30));

    Future<int> load() async {
      loads += 1;
      if (loads == 1) throw StateError('boom');
      return 3;
    }

    await expectLater(cache.getOrLoad(load), throwsStateError);
    expect(await cache.getOrLoad(load), 3);
    expect(loads, 2);
  });
}
