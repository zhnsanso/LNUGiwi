import 'package:flutter_test/flutter_test.dart';

import 'package:giwifi_ua_switcher/common/check_backoff.dart';

void main() {
  test('连续在线逐档升频，到顶保持', () {
    final backoff = CheckBackoff();
    expect(backoff.current, const Duration(minutes: 1));
    backoff.advance();
    expect(backoff.current, const Duration(minutes: 2));
    backoff.advance();
    expect(backoff.current, const Duration(minutes: 5));
    backoff.advance();
    expect(backoff.current, const Duration(minutes: 10));
    backoff.advance();
    expect(backoff.current, const Duration(minutes: 10), reason: '到顶后保持');
  });

  test('reset 回到最快档', () {
    final backoff = CheckBackoff();
    backoff.advance();
    backoff.advance();
    backoff.reset();
    expect(backoff.current, const Duration(minutes: 1));
  });
}
