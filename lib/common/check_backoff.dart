/// 自动重连检测的自适应间隔（阶梯思路来自官方客户端：
/// 在线越久查得越懒，掉线立即回到最快档）。
class CheckBackoff {
  CheckBackoff({this.ladder = defaultLadder});

  /// 档位必须升序；首档是掉线检测的最快响应间隔。
  static const List<Duration> defaultLadder = [
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  final List<Duration> ladder;

  int _index = 0;

  /// 当前应使用的检测间隔。
  Duration get current => ladder[_index];

  /// 连续在线时升档（到顶后保持）。
  void advance() {
    if (_index < ladder.length - 1) {
      _index++;
    }
  }

  /// 掉线 / 状态未知 / 刚完成登录时回到最快档。
  void reset() {
    _index = 0;
  }
}
