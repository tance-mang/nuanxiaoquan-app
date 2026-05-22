<div align="center">

# 暖小圈 · WarmCircle

**"学习 · 生理期 · 记账"三合一离线优先工具**

![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.x-6DB33F?logo=springboot&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)
![Doubao](https://img.shields.io/badge/AI-Doubao%201.5--pro--256k-FF6A00)
![License](https://img.shields.io/badge/license-Source--Available%20·%20Non--Commercial-red)
![Version](https://img.shields.io/badge/version-1.1-informational)
![备案](https://img.shields.io/badge/备案-桂ICP备2026007360号--2A-lightgrey)

</div>

---

> 把要学习需求的用户最高频的三件小事——**花了多少 / 身体在哪个阶段 / 今天该学什么**——放进同一个 App，并在三者之间建立关联：经前期的高消费提醒、经期的学习降档、月度三维复盘。
>
> 全栈离线优先：所有统计、预测、状态判定均由本地确定性算法完成，AI 只承担文案生成。**断网不降级。**

## 目录

- [核心特性](#核心特性)
- [系统架构](#系统架构)
- [安全设计](#安全设计-网络空间安全维度)
- [技术栈](#技术栈)
- [离线能力矩阵](#离线能力矩阵)
- [部署](#部署)
- [项目结构](#项目结构)
- [许可证（重要）](#许可证)
- [致谢](#致谢)

---

## 核心特性

| 模块 | 关键点 |
| --- | --- |
| 智能学习计划 | 豆包大模型生成 + 本地三阶段时间块算法兜底；按生理期阶段自适应强度 |
| 记账助手 | 通知栏自动监听（Android）+ 关键词分类规则表 + 月度多维报表 |
| 生理期管理 | 均值+标准差周期预测，置信度自评；阶段状态机：经期 / 卵泡 / 排卵 / 黄体 / 经前 |
| 三维联动分析 | 经前 + 高消费 → 冲动消费预警；经期 + 低完成率 → 焦虑抑制提示 |
| 主动陪伴 AI | 本地规则引擎"小暖"：北京时间 0:00 分日 / 熟悉度演化 / Tab 上下文观察 |
| 启发式安全微服务 | WAF + 链接三层过滤 + 接口层频次限制；与业务服务解耦部署 |
| 数据本地加密 | AES-256-GCM 持久化敏感数据；网络层 JWT + BCrypt |
| 离线本地推送 | flutter_local_notifications：经期 / 学习 / 记账 / 早晚陪伴推送 |

---

## 系统架构

```
                ┌──────────────────────────────────────────────┐
                │                Flutter 跨端客户端             │
                │  (Android · iOS · Web · 离线优先 · GetX)      │
                └──────┬─────────────────────────┬─────────────┘
                       │ HTTPS / JWT             │ HTTPS
                       ▼                         ▼
        ┌──────────────────────────┐  ┌──────────────────────────┐
        │  Java Spring Boot 3.x    │  │  Python FastAPI          │
        │  业务主后端 :8080       │◀▶│  安全微服务 :8000        │
        │                          │  │                          │
        │  · 用户 / 鉴权            │  │  · WAF 检测引擎          │
        │  · 记账 / 生理期 / 计划   │  │  · 链接三层过滤          │
        │  · 答疑 / 反馈 / 等级     │  │  · 内容入库前置审查      │
        │  · 豆包代理调用           │  │                          │
        └──────┬─────────┬─────────┘  └──────────────────────────┘
               │         │
               ▼         ▼
        ┌──────────┐ ┌──────────┐         ┌─────────────────────┐
        │  MySQL 8 │ │  Redis 7 │         │ 火山方舟 Doubao API │
        │  主存储  │ │ 限流/缓存 │        │ doubao-1.5-pro-256k │
        └──────────┘ └──────────┘         └─────────────────────┘
```

**关键设计原则**

1. **故障域隔离** — Java 主服务与 Python 安全服务独立进程独立镜像，安全模块崩溃不影响业务，业务模块崩溃也不影响安全检测能力。
2. **离线优先** — 客户端所有"分析 / 预测 / 状态判定"零网络依赖；服务端只在必要时同步。
3. **AI 边界明确** — AI 仅做"自然语言生成"（学习计划、暖句、对话）；统计、预测、判定全部由确定性算法完成，可解释、可单测、断网可用。
4. **配置外置** — 所有密钥走 `.env` 注入，源码零硬编码，便于多环境部署。

---

## 安全设计（网络空间安全维度）

> 此项目把"安全"作为一类独立子系统而非业务附加项。下方列出主要威胁模型与对应防护。

### 1. 应用层 WAF（Web Application Firewall）

Python FastAPI 微服务承载所有内容入库前置审查，覆盖 [OWASP Top 10](https://owasp.org/Top10/) 主要类别：

| 攻击类型 | 检测方式 |
| --- | --- |
| SQL 注入（SQLi） | 关键字+语法结构双检测；联合 Java 端 JPA 参数化做纵深防御 |
| 跨站脚本（XSS） | HTML 标签 / 事件属性 / `javascript:` 协议正则 |
| 命令注入（OS Cmdi） | 管道符 / 反引号 / `$()` 等 shell 元字符过滤 |
| 服务端请求伪造（SSRF） | 私网段 / 本机地址 / 元数据服务地址黑名单 |
| 路径穿越（Path Traversal） | `../` 系列归一化检测 |
| 服务端模板注入（SSTI） | Jinja / Velocity / Freemarker 表达式语法 |
| XML 外部实体（XXE） | `<!DOCTYPE` / `SYSTEM` 关键字 |

**测试入口**

```bash
cd backend
python app/security/waf.py    # 10+ 攻击用例自检，全部通过则 ✅
```

### 2. 链接安全三层过滤

用户发布答疑 / 反馈 / 资源链接时：

```
                  ┌─────────────────────────────────┐
   输入文本  ──▶  │ Layer 1: 关键字 + 敏感词向量匹配  │
                  └────────────┬────────────────────┘
                               ▼
                  ┌─────────────────────────────────┐
                  │ Layer 2: 黑名单域名 / DGA 启发    │
                  └────────────┬────────────────────┘
                               ▼
                  ┌─────────────────────────────────┐
                  │ Layer 3: 白名单放行              │
                  └─────────────────────────────────┘
                               ▼
                            入库 ✓
```

### 3. 鉴权与会话

| 项 | 实现 |
| --- | --- |
| 身份认证 | Spring Security + JWT（HS256，密钥外置） |
| 密码存储 | BCrypt（cost=10），加盐 |
| 会话语义 | 无状态，每次请求验证 token |
| 越权防护 | 资源所有权校验在 Service 层闭包 |
| 接口频控 | Redis 令牌桶：登录 5/min、注册 3/h、AI 调用 30/d |

### 4. 客户端数据保护

| 项 | 实现 |
| --- | --- |
| 本地敏感数据 | `encrypt` 包 AES-256-GCM；密钥由 Android Keystore / iOS Keychain 派生 |
| 网络层 | 强制 HTTPS；Dio 拦截器拒绝明文 |
| 第三方监听 | 通知栏自动记账：仅本地解析，**不上传通知原文** |
| 隐私边界 | 不接入第三方登录；不读取通讯录；不收集位置 |

### 5. AI 安全护栏（Prompt 层防护）

小暖（Doubao 1.5-pro-256k）的 system prompt 内置以下硬性禁区：

- 支付/转账/扫码 → 直接返回 `intent=blocked_sensitive`
- 密码 / 验证码 / 银行卡号 / 身份证 → 同上
- 外部链接点击 / 自动登录 → 同上
- 医学诊断 / 用药 / 法律 / 投资建议 → 同上

返回严格 JSON 格式，前端结构化解析，杜绝 prompt 注入劫持业务流程。

---

## 技术栈

<details open>
<summary><b>客户端</b></summary>

| 层 | 技术 | 说明 |
| --- | --- | --- |
| 框架 | Flutter 3.x / Dart 3.0+ | 单代码库覆盖 Android / iOS / Web |
| 状态管理 | GetX 4.x | 反应式状态 + 依赖注入 + 路由三合一 |
| 网络 | Dio 5.x + connectivity_plus | 拦截器自动附加 JWT；联网状态实时感知 |
| 持久化 | sqflite + shared_preferences | 关系数据走 SQLite；KV 走 SharedPreferences |
| 加密 | encrypt 5.x | AES-256-GCM 本地敏感数据加密 |
| 可视化 | fl_chart 1.x | 月度收支 / 学习时长 / 周期曲线，纯本地渲染 |
| 推送 | flutter_local_notifications 19.x | 离线本地通知，含早晚陪伴推送 |
| 屏幕适配 | flutter_screenutil | 多分辨率统一基准 |

</details>

<details open>
<summary><b>服务端（Java 主）</b></summary>

| 层 | 技术 |
| --- | --- |
| 框架 | Spring Boot 3.x · Spring Security 6.x · Spring Data JPA |
| JVM | Eclipse Temurin 17 |
| 鉴权 | JWT (jjwt 0.12) + BCrypt |
| 缓存 / 限流 | Redis 7 + Redisson |
| ORM | Hibernate 6（JPA 实现） + 参数化查询 |
| AI 集成 | 火山方舟（Volcengine Ark）REST 直连，OpenAI-compatible |
| 构建 | Maven 3.9，多阶段 Docker 镜像 |

</details>

<details open>
<summary><b>服务端（Python 安全微服务）</b></summary>

| 层 | 技术 |
| --- | --- |
| 框架 | FastAPI · Uvicorn · Pydantic v2 |
| 安全 | 自研 WAF 引擎 + 三层链接过滤 |
| 数据 | SQLAlchemy 2.0 + PyMySQL + Redis |
| 镜像 | python:3.11-slim，启动时间 < 2s |

</details>

<details open>
<summary><b>基础设施</b></summary>

| 项 | 选择 |
| --- | --- |
| 数据库 | MySQL 8.0 · utf8mb4 |
| 缓存 | Redis 7 alpine |
| 反向代理 | Nginx alpine · 静态资源 + 反代 |
| 编排 | Docker Compose v2 |
| 时区 | 全栈 Asia/Shanghai |

</details>

---

## 离线能力矩阵

| 功能 | 离线方案 |
| --- | --- |
| 生理期预测 | 均值 + 标准差 + 置信度自评（医学常规范围 21–35 天裁剪） |
| 阶段判定 | 5 状态有限状态机：经期 / 卵泡 / 排卵 / 黄体 / 经前 |
| 记账分类 | 关键词规则表 + 用户历史选择记忆 |
| 消费分析 | 全本地聚合 + fl_chart 渲染 |
| 学习计划生成 | 时间块算法：理解 / 练习 / 复习 三阶段拆分 |
| 主动陪伴 | 本地规则引擎 + 熟悉度演化（4 阶段） |
| 推送通知 | flutter_local_notifications，含早晚陪伴 |
| 历史数据 | sqflite 本地缓存，全功能可查 |

豆包仅在用户**主动点击"AI 生成"按钮**时触发，按需调用，token 成本可控。

---

## 部署

完整服务器部署见 [DEPLOY.md](DEPLOY.md)。

```bash
# 1. 配置（首次）
cp .env.example .env
vim .env   # 填 MYSQL_ROOT_PASSWORD / ARK_API_KEY

# 2. 编译前端静态资源
cd frontend && flutter build web --release && cd ..

# 3. 一键起所有服务
docker compose up -d --build
```

端口对外：

| 端口 | 服务 | 暴露建议 |
| --- | --- | --- |
| 80 | Nginx Web | 公网 |
| 8080 | Java 主后端 | 公网 |
| 8000 | Python 安全微服务 | 仅内网 |
| 3306 / 6379 | MySQL / Redis | 仅内网 |

---

## 项目结构

```
warmcircle_final/
├── frontend/                       # Flutter 客户端
│   └── lib/
│       ├── screens/                # 主页 / 自习室 / 知识小馆 / 我的 / 暖圈关怀 / ...
│       ├── widgets/                # 组件库（含小暖悬浮球）
│       ├── services/               # API / 行为追踪 / 主动陪伴 / 推送 / 一言客户端
│       ├── controllers/            # GetX 全局控制器
│       └── themes/                 # 5 套主题
│
├── java-backend/                   # 业务主服务
│   └── src/main/java/com/warmcircle/
│       ├── controller/             # AuthController · QAController · ...
│       ├── service/                # 业务逻辑 + DoubaoService + LevelService
│       ├── config/                 # SecurityConfig · JwtUtil
│       └── repository/             # JPA Repository
│
├── backend/                        # Python 安全微服务
│   └── app/
│       ├── security/               # WAF · link_checker
│       ├── services/               # AI / dual_ai / recommend
│       ├── api/                    # FastAPI 路由（如启用业务镜像）
│       └── models/                 # SQLAlchemy 模型
│
├── deploy/                         # 部署资源（init.sql · nginx.conf）
├── docker-compose.yml              # 一键编排
├── DEPLOY.md                       # 服务器部署详解
├── COPYRIGHT_FILING.md             # 软著申请清单
└── README.md
```

---

## 许可证

> **本项目源码公开可见，但严格禁止任何形式的商业使用。**

许可类型：**Source-Available · Non-Commercial**（自定义许可，等价于 [PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0/) 精神）。

**允许**

- 个人学习、研究、阅读源码
- 在教学、论文、技术分享中引用代码片段（需注明出处）
- Fork 用于非营利的衍生学习项目

**禁止**

- 直接或间接的商业使用（包括但不限于：售卖、SaaS 化、广告分成、应用商店上架变现）
- 去除原作者署名 / 备案号 / 项目标识后二次分发
- 将本项目核心算法（生理期预测、三维联动分析、安全微服务）嵌入商业产品

如需商业授权，请通过acd2123759705@outlook.com 联系作者另行协商。

完整条款见 [LICENSE](LICENSE)。

---

## 致谢

- [一言（hitokoto.cn）](https://hitokoto.cn) — 提供每日推荐暖句的公开 API，遵循其开源协议
- [火山引擎方舟（豆包大模型）](https://www.volcengine.com/product/doubao) — Doubao 1.5-pro-256k 模型支持
- [Flutter](https://flutter.dev) / [Spring Boot](https://spring.io) / [FastAPI](https://fastapi.tiangolo.com) 等开源社区

---

<div align="center">

**域名 / 备案**：`nuanxiaoquan.cn` · 桂ICP备2026007360号-2A

**Made with restraint, not noise.**

</div>
