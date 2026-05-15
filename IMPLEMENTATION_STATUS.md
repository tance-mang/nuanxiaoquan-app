# 暖小圈 — 系统设计 & 实施状态

> 本文档 = 原方案（产品定位 + 系统逻辑）+ 已实施代码映射 + AS 运行指南。
> 最后更新：本轮 B 类完成后。

---

## 1. 产品定位

暖小圈是一个**基于用户状态感知，自动调节学习强度的行为闭环系统**。
目标：让用户**无需思考**就能开始学习并持续学习。
核心价值：**降低开始学习的心理成本 + 提升持续性**。

> 不是学习计划工具，也不是社区/打卡软件。核心是**学习行为调节系统**。

---

## 2. 系统底层逻辑

### 公式

```
学习推荐强度 score = 状态系数 × 能量系数 × 行为系数
```

**已落地代码**：[`lib/services/strength_engine.dart`](warmcircle_final/frontend/lib/services/strength_engine.dart)

### 输入变量

| 变量 | 来源 | 持久化 key |
|---|---|---|
| 今日状态（精力 + condition） | 用户主动填写（首页今日状态卡） | `daily_state_<YYYY-MM-DD>` |
| 能量状态 | 由 condition 推断（痛经不适/有点累 → low） | 同上 |
| 今日是否开始 | StudyRoomController 累计秒数 ≥ 60 | `focus_seconds_<YYYY-MM-DD>` |
| 中断次数 | pauseTimer 时 +1 | `interrupts_<YYYY-MM-DD>` |
| 微调（用户主动） | hero CTA 上的"今天更轻/就这样/稍微加" | `manual_adjust_<YYYY-MM-DD>` |
| 特殊覆盖 | "今天不学习/自由模式"菜单 | `override_<YYYY-MM-DD>` |

### 系数规则（与方案一致）

- **状态系数**：good 1.0 / normal 0.8 / bad 0.5
- **能量系数**：normal 1.0 / low-energy 0.6
- **行为系数**：开始 yes 1.0 / no 0.7；中断 0次 1.0 / 1次 0.9 / 2+次 0.7

### 输出模式

| Mode | Score 区间 | 推荐时长 | 描述 |
|---|---|---|---|
| `light` 轻启动 | < 0.6 | 25 分钟 | 复习或简单任务 |
| `standard` 标准 | 0.6 – 0.85 | 45 分钟 | 分段学习 |
| `sprint` 冲刺 | > 0.85 | 60 分钟 | 深度专注 |
| `restDay` 今天不学习 | override | 0 分钟 | 给身体一点空间 |
| `free` 自由模式 | override | 用户自定 | 引擎不干涉 |

---

## 3. 用户决策设计（已实现）

### 一次性偏好：引导风格

存储：`AppController.guidancePreference: RxString`
入口：hero CTA 右上 `…` → 更多 → 引导风格

| 值 | 行为 |
|---|---|
| `autonomous` 自主型 | CTA 隐藏 rationale，按钮文案"开始" |
| `light` 轻引导（默认） | 完整 rationale + 微调；按钮"开始学习" |
| `strong` 强引导 | 按钮"立即开始"，引擎时长自动写入 lobby |

### 偶尔微调（hero CTA 下方三 chip）

- **今天更轻** → `manual_adjust -5` 分钟
- **就这样** → 清零微调
- **稍微加一点** → `manual_adjust +5` 分钟

### 特殊覆盖（hero CTA 右上 ⋯ 菜单）

- **今天不学习** → `override = no_study`，模式变 `restDay`
- **自由模式** → `override = free`，模式变 `free`
- **重置今日状态** → 清掉 daily_state / manual_adjust / override

> 已实现"默认自动，用户少量微调"原则。

---

## 4. 首页 UI（与方案一致）

[`lib/screens/home_screen.dart`](warmcircle_final/frontend/lib/screens/home_screen.dart) 顺序：

1. **Hero CTA**（[`widgets/start_study_cta.dart`](warmcircle_final/frontend/lib/widgets/start_study_cta.dart)）
   - 状态 chip（今天·状态不错/一般/偏低）+ low-energy 副标签
   - 推荐 mode 大字标题 + 模式描述 + rationale
   - 大按钮"开始学习"
   - 微调 chips（今天更轻 / 就这样 / 稍微加一点）
   - 右上⋯更多菜单
2. 今日待完成 2/2 个计划 summary
3. **TodayFocusCard** 今日累计专注 X 分钟（来自 `focus_seconds_<date>` 持久化）
4. **StateTrendBar** 最近 7 天精力趋势条
5. 今日状态卡（精力滑块 + condition chips）
6. C 类自适应推荐行（状态好绿 / 状态差暖橘）
7. 学习计划列表（第一张 = 今日必保保险箱，绿色 🛡 徽章）

---

## 5. 自习室（执行页）

[`lib/screens/study_room_screen.dart`](warmcircle_final/frontend/lib/screens/study_room_screen.dart)

- **1:2 布局**：计时器占 1/3（圆盘 78-110px），房间列表占 2/3
- **AppBar 习 logo**（与 暖/知/我 统一风格）
- **暖圈钟**：25/30/45/60 chip + 圆盘 + 重置/开始专注
- **持续扩散涟漪**：3 圈错相，按进度从 3.5s 加速到 0.9s
- **顶部 JudgeHintBar**：综合判定提示（仅闲置时显示）
- **房间内页**（[`room_detail_screen.dart`](warmcircle_final/frontend/lib/screens/room_detail_screen.dart)）：
  - 进度填充式夕阳（仅计时启动后渲染）
  - 成员 Lissajous 大幅飘动（±18×14 px）
  - 紧凑布局，5 成员一屏可见

---

## 6. 学习结束反馈

[`_EndOfStudyDialog`](warmcircle_final/frontend/lib/screens/study_room_screen.dart)（自习室文件末）

- 触发：计时器到 0
- "今天完成 X 分钟，很棒"
- 3 个选项：**轻松 / 一般 / 有点难** → `StrengthEngine.recordFeedback`
- 写入 `feedback_<date>` + 行为日志

---

## 7. 行为感知 & 主动干预

[`lib/services/behavior_tracker.dart`](warmcircle_final/frontend/lib/services/behavior_tracker.dart)

- **Listener** onPointerDown 标记活跃（不监听 move，避免事件风暴）
- **页面语义**：仅在自习 surface (lobby tab / 房间内页) + 计时跑 + idle ≥ 阈值时触发
- **可配置阈值**：默认 3 分钟，用户在「微休息偏好」可调 1-10 分钟，可总开关关掉
- **微休息弹窗**（`_MicroRestDialog`）：从兴趣池随机挑活动 + 继续专注
- **生命周期感知**（WidgetsBindingObserver）：切到后台 ≥ 30s + 计时跑 → 暖橘 snackbar "欢迎回来 🌿"

---

## 8. 性别门控（全部审计）

所有「暖圈关怀 / 经期 / 痛经」相关都需 `userGender == 'female'`：
- 今日状态卡的「痛经不适」chip
- xiaonuan 问候 + tagline + period 卡
- qa_screen 分类
- warmcare_screen 兜底（非女性进入显示锁定页 + 返回）
- 设置公告中"功能列表"

---

## 9. AI 小暖

[`lib/screens/xiaonuan_screen.dart`](warmcircle_final/frontend/lib/screens/xiaonuan_screen.dart)

- **动画头像**：纯呼吸（无围绕点点），多实例用 `DateTime.now()` 全局同步；闲置 2.4s，AI 回答中 0.8s 加速
- **可点击的 greeting 气泡**：3 行（2-3 行女性才有）primary-tinted 卡片，每行 emoji + 标题 + hint + 箭头，点击即提问
- **历史会话**：右抽屉，最多 20 条，title 来自首条用户消息（24 字截断），相对时间显示，删除二次确认
- **+ 新对话**：AppBar 右上 add_comment_outlined 按钮
- **greeting 在 AI 回复后自动消失**（intent ≠ greeting 即清除）
- **悬浮球**（[`widgets/ai_float_button.dart`](warmcircle_final/frontend/lib/widgets/ai_float_button.dart)）：3D 渲染（高光 + rim light + 多层投影），Lissajous 漂动，动量光晕（与计时器涟漪明显区分）

---

## 10. 附属功能（不参与学习决策）

- **知识小馆**：存储语录 / 资料，扩展性预留
- **暖账 / 暖记**：消费 / 笔记记录
- **暖圈关怀**：女性周期记录（仅 female 可见）
- **应用评估页**：上一版本误加，已**删除**

---

## 11. 系统闭环（已闭合）

```
用户状态 (daily_state)
     ↓
StrengthEngine.compute() → score → mode + 推荐时长
     ↓
Hero CTA 显示 → 用户微调或直接开始
     ↓
StudyRoomController 计时（每 10s 持久化 focus_seconds）
     ↓
暂停 → recordInterrupt() 写 interrupts_<date>
     ↓
计时结束 → _EndOfStudyDialog → recordFeedback()
     ↓
下次 compute() 时引擎读到 interrupts + feedback → 自动调整
```

**结构化行为日志**：所有事件统一打到 `behavior_log` JSON 数组（最多 200 条），事件类型：
`state_logged / interrupt / feedback / manual_adjust / override / reset_state`

读取：`StrengthEngine.readLog(limit: N)`

---

## 12. 在 Android Studio 中运行

### 前置条件

| 工具 | 版本/位置 |
|---|---|
| Flutter SDK | 3.29.x，本机 `D:\flutter_windows_3.29.2-stable\flutter`（已在 local.properties） |
| Android SDK | 已装到 `C:\Users\yiyih\AppData\Local\Android\sdk`（已在 local.properties） |
| Android Studio | Hedgehog 或更新版 |
| Flutter / Dart 插件 | 已安装（AS 顶部菜单 Plugins） |

### 工程参数（已配置）

```
applicationId: com.example.warmcircle
namespace:     com.example.warmcircle
compileSdk:    36   (Android 14+)
minSdk:        23   (Android 6.0+, 覆盖 ≥ 99% 设备)
ndkVersion:    27.0.12077973
Java/Kotlin:   11
ABIs:          armeabi-v7a + arm64-v8a
```

### 在 AS 里跑起来 4 步

1. **打开工程**：File → Open → 选择 `warmcircle_final/frontend/` 文件夹（不是 `nuanxiaoquanV1.1` 根目录）
2. **拉依赖**：终端运行 `flutter pub get` 或点 AS 顶栏的"Pub get"
3. **选设备**：右上 Device 下拉，选模拟器或真机（USB 调试）
4. **点 Run ▶**（绿色三角）或 `Shift+F10`

### 跨平台干净度（无 web-only 代码）

- ✅ 0 处 `dart:html` / `package:web` / `kIsWeb`
- ✅ 0 处仅 web 可用 API
- ✅ 275 条 lint 全是 info 级 `withOpacity` 弃用提示，**0 errors**
- ✅ shared_preferences / get / dio / fl_chart 等所有依赖均跨 Android/iOS/Web

### 打 APK（不用 AS 也行）

```bash
cd warmcircle_final/frontend
flutter build apk --release           # 一个 universal APK
flutter build apk --split-per-abi     # 按 CPU 拆，体积更小
```

产物路径：`build/app/outputs/flutter-apk/`

---

## 13. 已完成 vs 你方案 9 项

| # | 方案要求 | 实施状态 | 文件 |
|---|---|---|---|
| 1 | 用户状态输入系统 | ✅ | home_screen.dart `_buildDailyStateCard` |
| 2 | 能量状态标记 | ✅（由 condition 推断） | strength_engine.dart `lowEnergy` |
| 3 | 学习强度计算引擎 | ✅ | services/strength_engine.dart |
| 4 | 输出三种学习模式 | ✅ light/standard/sprint + restDay/free | strength_engine.dart `StrengthMode` |
| 5 | 首页极简 UI（状态+建议+开始） | ✅ | widgets/start_study_cta.dart |
| 6 | 自习室模式自动匹配 | ✅（CTA 写入 lobby 推荐时长） | start_study_cta.dart `_start()` |
| 7 | 结束页 + 反馈收集 | ✅ | `_EndOfStudyDialog` in study_room_screen.dart |
| 8 | 数据存储结构（行为记录） | ✅ | strength_engine.dart `logEvent / readLog` |
| 9 | （未单列，但隐含）UI 极简 | ✅ | hero CTA 占首位，plan 列表退居其次 |

---

## 14. 待办（B+ 类，下一阶段）

- 第一次进入 app 时一次性问"引导风格"（onboarding 流程）
- 行为日志数据可视化（"我的"页加一个"学习记录"入口）
- 状态推荐基于历史 7 天加权平均，而不仅看当天
- 多端配置：iOS 签名 + iOS Info.plist 权限声明
- 服务器部署：docker-compose 已配，部署到云服务器后 `frontend/build/web` 即静态 host

---

## 附：文件结构速查

```
warmcircle_final/frontend/lib/
├── controllers/
│   └── app_controller.dart           # 全局状态：用户、性别、AI 模式、引导风格、微休息
├── services/
│   ├── api_service.dart              # 后端 HTTP
│   ├── behavior_tracker.dart         # 行为感知 + 微休息弹窗 + 生命周期
│   ├── strength_engine.dart          # 强度公式 + 模式 + 行为日志（核心）
│   └── today_judge.dart              # C 类综合判定（hint 文案）
├── widgets/
│   ├── ai_float_button.dart          # 小暖悬浮球（3D + Lissajous）
│   ├── focus_progress_bar.dart       # 顶部全局光带
│   ├── judge_hint_bar.dart           # 综合判定提示行
│   ├── start_study_cta.dart          # ★ 首页 hero CTA（核心）
│   ├── state_trend_bar.dart          # 7 天精力趋势
│   ├── today_focus_card.dart         # 今日累计专注
│   └── judge_hint_bar.dart           # 计时器附近的判定提示
└── screens/
    ├── home_screen.dart              # 首页（hero CTA + 学习计划）
    ├── study_room_screen.dart        # 自习室 + lobby 控制器 + 结束反馈
    ├── room_detail_screen.dart       # 房间内页（夕阳 + 飘动成员）
    ├── knowledge_screen.dart         # 知识小馆
    ├── mine_screen.dart              # 我的（暖账/暖记/暖圈关怀入口）
    ├── settings_screen.dart          # 设置（性别/主题/AI/隐私/反馈）
    ├── interest_prefs_screen.dart    # 微休息偏好（含引导风格入口预留）
    ├── warmcare_screen.dart          # 暖圈关怀（女性用户专属）
    ├── xiaonuan_screen.dart          # AI 小暖对话（含历史 drawer）
    └── ... (其他)
```

---

**核心价值再次重申**：
让用户**无需思考**即可开始学习，**根据状态自动调整学习强度**，并提供**微量自主调节**，
同时收集行为反馈**持续优化闭环**。
这是暖小圈区别于普通学习 App 或聊天 AI 的**系统级价值**。
