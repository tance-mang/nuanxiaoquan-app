// ============================================================
// 文件：services/push_notification_service.dart
// 作用：本地推送通知（完全离线，不依赖第三方推送服务器）
//
// 已接入：flutter_local_notifications: ^19.5.0
//
// 支持的推送类型：
//   1. 经期前提醒        — 经期前 3 天
//   2. 经期开始关怀     — 经期到来当天
//   3. 学习打卡提醒     — 每天定时
//   4. 记账提醒         — 晚间未记账时
//   5. 预算超支即时提醒 — 支出超过 80% 时
//   6. 小暖早晨提示     — 北京时间 07:30
//   7. 小暖晚间收束     — 北京时间 21:30
//
// ⚠️ 平台前置（部署时需要确认）：
//   Android：AndroidManifest.xml 已自带通知权限；Android 13+ 需要 POST_NOTIFICATIONS 运行时申请
//   iOS：Info.plist 加入 NSUserNotificationsUsageDescription，并在 AppDelegate 注册
//
// 时区：默认走设备时区。如果需要严格北京时间锁定，可以在 main.dart 里：
//   import 'package:timezone/data/latest_all.dart' as tzdata;
//   import 'package:timezone/timezone.dart' as tz;
//   tzdata.initializeTimeZones();
//   tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
//   并改用 zonedSchedule。当前版本用 show() + 启动时计算延迟，已满足"App 在前台/后台时收得到"。
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'proactive_companion.dart';

class PushNotificationService {
  static final _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  // ── 通知 ID 分配（避免冲突）────────────────────────────────
  static const int _idPeriodReminder    = 1001;
  static const int _idStudyReminder     = 1002;
  static const int _idAccountReminder   = 1003;
  static const int _idBudgetAlert       = 1004;
  static const int _idPeriodCare        = 1005;
  static const int _idMorningCompanion  = 1006;
  static const int _idEveningCompanion  = 1007;

  // ── 通道（Android）─────────────────────────────────────────
  static const _channelGeneral = AndroidNotificationChannel(
    'warmcircle_general',
    '暖小圈日常提醒',
    description: '记账、学习、生理期等日常提醒',
    importance: Importance.defaultImportance,
  );
  static const _channelCompanion = AndroidNotificationChannel(
    'warmcircle_companion',
    '小暖陪伴',
    description: '小暖每天的早晚问候',
    importance: Importance.low, // 低优先级，不打扰
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Timer? _morningTimer;
  Timer? _eveningTimer;

  // ─── 初始化 ──────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );
      await _plugin.initialize(initSettings);

      // 创建 Android 通道
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(_channelGeneral);
        await androidImpl.createNotificationChannel(_channelCompanion);
        // Android 13+ 运行时通知权限
        await androidImpl.requestNotificationsPermission();
      }

      _initialized = true;
      debugPrint('[推送] 本地通知服务初始化完成');
    } catch (e) {
      debugPrint('[推送] 初始化失败：$e');
    }
  }

  // ─── 通用 details ──────────────────────────────────────────

  static const NotificationDetails _generalDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'warmcircle_general',
      '暖小圈日常提醒',
      channelDescription: '记账、学习、生理期等日常提醒',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const NotificationDetails _companionDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'warmcircle_companion',
      '小暖陪伴',
      channelDescription: '小暖每天的早晚问候',
      importance: Importance.low,
      priority: Priority.low,
    ),
    iOS: DarwinNotificationDetails(
      presentSound: false,
      presentBadge: false,
    ),
  );

  // ─── 1. 经期前提醒 ────────────────────────────────────────

  Future<void> schedulePeriodReminder(DateTime predictedDate,
      {int daysBefore = 3}) async {
    await init();
    final reminderDate = predictedDate.subtract(Duration(days: daysBefore));
    final delay = reminderDate.difference(DateTime.now());
    if (delay.isNegative) return;

    // 简单方案：用 Timer 延迟触发（App 必须存活）。
    // 真正"App 关了也能推"需要 zonedSchedule + timezone 包；下方留有 TODO。
    Timer(delay, () {
      _plugin.show(
        _idPeriodReminder,
        '经期提醒',
        '预计还有 $daysBefore 天来经期，提前准备一下。',
        _generalDetails,
      );
    });
    debugPrint('[推送] 已安排经期提醒：$reminderDate');
  }

  // ─── 2. 经期开始关怀 ──────────────────────────────────────

  Future<void> sendPeriodCareMessage() async {
    await init();
    const messages = [
      '经期了，今天降一档，慢慢来。',
      '保暖。学习强度可以降一档，没关系。',
      '这几天先把"完成"做到，"完美"留到下一阶段。',
    ];
    final msg = messages[DateTime.now().day % messages.length];
    await _plugin.show(_idPeriodCare, '暖小圈关怀', msg, _generalDetails);
  }

  // ─── 3. 预算超支即时提醒 ───────────────────────────────────

  Future<void> sendBudgetAlert(double ratio) async {
    await init();
    final percent = (ratio * 100).toStringAsFixed(0);
    await _plugin.show(
      _idBudgetAlert,
      '预算提醒',
      '本月已消费 $percent%，最近几笔不重要的可以缓一缓。',
      _generalDetails,
    );
  }

  // ─── 4. 学习打卡 / 5. 晚间记账（占位，等用户在设置里挑时间）

  Future<void> scheduleStudyReminder(int hour, int minute) async {
    // TODO（如需"App 关闭后也能定时推"）：
    //   1) 在 pubspec 加 timezone 依赖；
    //   2) main.dart 调用 tz.setLocalLocation(tz.getLocation('Asia/Shanghai'))；
    //   3) 改下面这段用 zonedSchedule + DateTimeComponents.time。
    debugPrint('[推送] 学习提醒已记录：$hour:$minute（需 timezone 包配合）');
  }

  Future<void> scheduleAccountingReminder(int hour, int minute) async {
    debugPrint('[推送] 记账提醒已记录：$hour:$minute（需 timezone 包配合）');
  }

  // ─── 6+7. 小暖早晚陪伴推送 ─────────────────────────────────

  /// 同时排早晚两个推送；调用时机：App 启动时（main.dart）
  /// 当前实现：用 Timer 延迟触发（App 在前台/后台都行；被杀掉则不触发）
  Future<void> scheduleCompanionDailyPushes() async {
    await init();
    _morningTimer?.cancel();
    _eveningTimer?.cancel();

    // 北京时间下一次 07:30
    final nextMorning = _nextBeijingTimeOfDay(hour: 7, minute: 30);
    final morningDelay = nextMorning.difference(DateTime.now());
    if (!morningDelay.isNegative) {
      _morningTimer = Timer(morningDelay, () async {
        final text = await ProactiveCompanion.morningPush();
        await _plugin.show(
          _idMorningCompanion,
          '小暖',
          text,
          _companionDetails,
        );
        // 推完后排明天
        unawaited(scheduleCompanionDailyPushes());
      });
      debugPrint('[推送] 早安推送已排到 $nextMorning');
    }

    // 北京时间下一次 21:30
    final nextEvening = _nextBeijingTimeOfDay(hour: 21, minute: 30);
    final eveningDelay = nextEvening.difference(DateTime.now());
    if (!eveningDelay.isNegative) {
      _eveningTimer = Timer(eveningDelay, () async {
        final text = await ProactiveCompanion.eveningPush();
        await _plugin.show(
          _idEveningCompanion,
          '小暖',
          text,
          _companionDetails,
        );
        unawaited(scheduleCompanionDailyPushes());
      });
      debugPrint('[推送] 晚间推送已排到 $nextEvening');
    }
  }

  /// 计算"下一个北京时间的 hh:mm"对应的本地 DateTime。
  /// 不依赖 timezone 包：用 UTC+8 推算目标 UTC 时刻，再转 local。
  DateTime _nextBeijingTimeOfDay({required int hour, required int minute}) {
    final nowUtc = DateTime.now().toUtc();
    final nowBj = nowUtc.add(const Duration(hours: 8));
    var targetBj = DateTime.utc(nowBj.year, nowBj.month, nowBj.day, hour, minute);
    // 如果今天的目标点已过，就排到明天
    if (!targetBj.isAfter(nowBj)) {
      targetBj = targetBj.add(const Duration(days: 1));
    }
    final targetUtc = targetBj.subtract(const Duration(hours: 8));
    return targetUtc.toLocal();
  }

  // ─── 取消 ────────────────────────────────────────────────

  Future<void> cancelPeriodReminder() => _plugin.cancel(_idPeriodReminder);
  Future<void> cancelStudyReminder() => _plugin.cancel(_idStudyReminder);
  Future<void> cancelCompanionPushes() async {
    _morningTimer?.cancel();
    _eveningTimer?.cancel();
    await _plugin.cancel(_idMorningCompanion);
    await _plugin.cancel(_idEveningCompanion);
  }

  Future<void> cancelAll() async {
    _morningTimer?.cancel();
    _eveningTimer?.cancel();
    await _plugin.cancelAll();
  }
}
