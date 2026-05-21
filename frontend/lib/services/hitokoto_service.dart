// ============================================================
// 文件：services/hitokoto_service.dart
// 作用：一言公开API客户端，带 24 小时本地缓存
//
// 来源：https://hitokoto.cn/  免费、无鉴权、无登录、稳定运行多年
// 调用频率：一天 1 次（缓存到次日凌晨），降低对方服务器压力
// 商用提示：使用时请保留"来源：一言"标识，遵守 hitokoto 的开源协议
//
// 关于参数：
//   c=b → 动漫；c=d → 游戏；c=k → 哲学；c=i → 诗词
//   这里同时拿"励志 + 学习"风格句子：c=b&c=d
// ============================================================

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HitokotoService {
  static const String _endpoint =
      'https://v1.hitokoto.cn/?encode=text&c=b&c=d';

  // 缓存 key
  static const String _kQuote = 'hitokoto_cached_quote';
  static const String _kFetchedAt = 'hitokoto_fetched_at_ms';

  // 独立 Dio 实例：不走应用 BaseUrl，专跑一言
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 6),
    responseType: ResponseType.plain,
  ));

  /// 获取今日一言（24 小时本地缓存）
  /// 返回结构：{ content: 句子, source: '一言' }
  /// 网络失败且没有缓存时返回 null（外层应当 fallback 到本地预置）
  static Future<Map<String, String>?> getDailyQuote() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kQuote);
    final fetchedAt = prefs.getInt(_kFetchedAt) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const twentyFourHours = 24 * 60 * 60 * 1000;

    // 缓存命中且未过期
    if (cached != null && now - fetchedAt < twentyFourHours) {
      return {'content': cached, 'source': '一言'};
    }

    // 缓存过期或不存在，请求一次
    try {
      final resp = await _dio.get<String>(_endpoint);
      final body = (resp.data ?? '').trim();
      if (resp.statusCode == 200 && body.isNotEmpty) {
        await prefs.setString(_kQuote, body);
        await prefs.setInt(_kFetchedAt, now);
        return {'content': body, 'source': '一言'};
      }
    } catch (_) {
      // 网络问题 → 用旧缓存兜底（即便过期，也比无内容好）
      if (cached != null) {
        return {'content': cached, 'source': '一言'};
      }
    }
    return null;
  }

  /// 手动清缓存（调试/换源时用）
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQuote);
    await prefs.remove(_kFetchedAt);
  }
}
