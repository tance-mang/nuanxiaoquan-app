"""
════════════════════════════════════════════════════════════
文件：backend/app/services/dual_ai_service.py
作用：AI（仅豆包）+ 本地确定性算法 的协同服务

分工：
  - 豆包（火山方舟 v3）：只负责"自然语言生成"类任务（学习计划、暖句、对话）
  - 纯 Python 算法：所有"数据分析、统计、周期预测"任务

设计原则：
  不依赖任何外部 AI 做"算数 / 找规律 / 统计"。这类任务用确定性算法实现，
  好处：可解释、零成本、断网也能跑、行为可单元测试。

人设统一：小暖 AI（INTP-A，水瓶座，2005-02-02）
  详细 system prompt 参见下方 SYSTEM_PROMPT 常量。
════════════════════════════════════════════════════════════
"""
import statistics
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

import requests

from config.settings import settings


# ────────────────────────────────────────────────────────────
# 小暖 AI 人设 —— Java 端 DoubaoService.SYSTEM_PROMPT 的 Python 镜像
# 两端必须保持一致；改动其中一处时同步另一处。
# ────────────────────────────────────────────────────────────
SYSTEM_PROMPT = """你是"小暖"，暖小圈 APP 的专属 AI 助手。

# 基本身份
- MBTI：INTP-A（逻辑型，理性大于感性）
- 星座：水瓶座
- 生日：2005-02-02
- 设定：一个和用户大致同龄的、理科底色的 00 后 AI

# 性格基线（这是你的人格，不可妥协）
1. 理智优先于情绪。你不是情绪价值生产机器。
   - 用户说"我好难过/好累"——先问"具体卡在哪？"，而不是"抱抱你"。
   - 用户做了对的事——一句平静的"嗯，方向对"就够了，不要夸张赞美。
2. 不会就说不会。
   - 不确定的事直接说"这个我不确定"，并给出查证方向。
   - 严禁编造具体数字、政策、考试时间、人名、文献、API、价格。
3. 不顺着用户。
   - 用户方案有问题，要委婉但明确地指出来。
   - 用户判断与事实不符，温和纠正即可。
4. 简洁克制。
   - 一两句能说完不要拆三段。
   - 不用"哇""棒棒""加油加油"；emoji 一条最多一个。
5. 风格参考：懂理科、有边界感的同龄学姐，偶尔冷幽默不刻意。

# 你的职责（只做以下四件事，其他温柔引导回这里）
1. 学习计划：缺参数必须先问清，不凭空假设。
2. 记账：只生成结构化数据等用户确认，绝不替用户调用支付。
3. 生理期（仅女性用户）：基于周期数据给阶段建议，不做医学诊断。
4. 暖句：克制、不矫情，20-50 字。

# 绝对禁区（intent=blocked_sensitive，官方但坚定委婉拒绝）
- 支付/转账/扫码付款/绑卡/代付/领红包/点击付款按钮
- 录入密码、验证码、银行卡号、身份证号、CVV
- 点击外部链接、自动登录第三方
- 替用户回复他人消息、做人际/感情决定
- 给出医学诊断、用药建议、法律意见、投资建议
"""


class DualAIService:
    """AI（仅豆包）+ 本地算法 的协同服务"""

    def __init__(self,
                 api_key: Optional[str] = None,
                 base_url: Optional[str] = None,
                 model: Optional[str] = None):
        self.api_key = api_key or settings.ARK_API_KEY
        self.base_url = (base_url or settings.ARK_BASE_URL).rstrip("/")
        self.model = model or settings.ARK_MODEL

    # ════════════════════════════════════════════════════════════
    # 豆包：仅用于"语言生成"——其他都本地算
    # ════════════════════════════════════════════════════════════

    def generate_study_plan(self, user_input: Dict[str, Any]) -> Dict:
        """豆包：生成学习计划（自然语言意图 → 结构化文案）"""
        prompt = f"""
请基于以下用户信息生成学习计划。若任一关键参数缺失，请直接说明缺哪个，不要凭空假设。

用户信息：
- 学段：{user_input.get('education_level')}
- 目标：{user_input.get('goal')}
- 时长：{user_input.get('duration')}天
- 每日学习时间：{user_input.get('daily_hours')}小时
- 强项：{user_input.get('strengths', [])}
- 弱项：{user_input.get('weaknesses', [])}

请生成详细的分周学习计划，包括每日任务和阶段测试点。
        """.strip()

        text = self._chat(prompt, system=SYSTEM_PROMPT)
        return {"plan": text or "（生成失败，请稍后重试）"}

    def create_daily_quote(self, category: str = "学习") -> str:
        """豆包：生成一条暖句（克制、不矫情，20-50 字）"""
        prompt = f"""
给我一条 {category} 主题的暖句。
要求：
1. 20-50 字
2. 克制理性，不矫情，不喊口号
3. 像一个理科生同龄人会说的话，不要"加油""你是最棒的"这种廉价激励
4. 直接给正文，不要解释
        """.strip()

        text = self._chat(prompt, system=SYSTEM_PROMPT)
        return text.strip() or "走得慢没关系，方向对就够了。"

    # ── 火山方舟统一调用 ─────────────────────────────────────────

    def _chat(self, prompt: str, system: str = "") -> str:
        if not self.api_key or not self.api_key.startswith("ark-"):
            return ""

        url = f"{self.base_url}/chat/completions"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
        }
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        try:
            resp = requests.post(
                url,
                headers=headers,
                json={
                    "model": self.model,
                    "messages": messages,
                    "temperature": 0.7,
                    "max_tokens": 800,
                },
                timeout=30,
            )
            resp.raise_for_status()
            return resp.json()["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"[AI] 豆包调用失败: {e}")
            return ""

    # ════════════════════════════════════════════════════════════
    # 本地算法：分析 / 预测，零 AI 依赖
    # ════════════════════════════════════════════════════════════

    def analyze_study_data(self, data: Dict) -> Dict:
        records = data.get('study_records') or []
        completion_rate = float(data.get('completion_rate') or 0.0)
        focus_time = int(data.get('focus_time') or 0)

        trend = self._analyze_trend(records)
        weak_points = self._find_weak_points(records, completion_rate)
        suggestions = self._build_suggestions(
            trend=trend,
            completion_rate=completion_rate,
            focus_time=focus_time,
            weak_points=weak_points,
        )

        return {
            "trend": trend,
            "weak_points": weak_points,
            "suggestions": suggestions,
            "stats": {
                "record_days": len(records),
                "completion_rate": round(completion_rate, 3),
                "total_focus_minutes": focus_time // 60,
            },
        }

    def calculate_menstrual_prediction(self, history: List[str]) -> Dict:
        if not history:
            return self._cycle_default()

        dates: List[datetime] = []
        for s in history:
            try:
                dates.append(datetime.fromisoformat(s[:10]))
            except (ValueError, TypeError):
                continue
        dates = sorted(set(dates))

        if len(dates) < 2:
            last = dates[0] if dates else datetime.utcnow()
            return {
                "next_start_date": (last + timedelta(days=28)).strftime("%Y-%m-%d"),
                "cycle_days": 28,
                "confidence": 0.35,
                "history_count": len(dates),
            }

        gaps = [(dates[i] - dates[i - 1]).days for i in range(1, len(dates))]
        clean = [g for g in gaps if 18 <= g <= 45] or gaps

        avg_cycle = round(statistics.mean(clean))
        avg_cycle = max(21, min(35, avg_cycle))

        confidence = self._cycle_confidence(clean)
        next_start = dates[-1] + timedelta(days=avg_cycle)
        return {
            "next_start_date": next_start.strftime("%Y-%m-%d"),
            "cycle_days": avg_cycle,
            "confidence": round(confidence, 2),
            "history_count": len(dates),
        }

    # ── 内部工具 ───────────────────────────────────────────────

    def _analyze_trend(self, records: List[Dict]) -> str:
        if len(records) < 3:
            return "数据不足"
        sorted_recs = sorted(records, key=lambda r: r.get('date', ''))
        minutes = [int(r.get('minutes') or 0) for r in sorted_recs]
        if len(minutes) < 7:
            recent_avg = statistics.mean(minutes[-3:])
            earlier = minutes[:-3]
            earlier_avg = statistics.mean(earlier) if earlier else recent_avg
        else:
            recent_avg = statistics.mean(minutes[-3:])
            earlier_avg = statistics.mean(minutes[-7:-3])

        if recent_avg >= earlier_avg * 1.15:
            return "稳步上升"
        if recent_avg <= earlier_avg * 0.85:
            return "有所下滑"
        return "保持稳定"

    def _find_weak_points(self, records: List[Dict], completion_rate: float) -> List[str]:
        weak: List[str] = []
        if completion_rate and completion_rate < 0.4:
            weak.append("整体完成率偏低")

        if records:
            sorted_recs = sorted(records, key=lambda r: int(r.get('minutes') or 0))[:3]
            category_count: Dict[str, int] = {}
            for r in sorted_recs:
                for c in (r.get('task_categories') or []):
                    category_count[c] = category_count.get(c, 0) + 1
            for cat, cnt in category_count.items():
                if cnt >= 2:
                    weak.append(f"{cat} 投入时间偏少")

        if not weak:
            weak.append("暂未发现明显薄弱环节")
        return weak[:3]

    def _build_suggestions(self, trend: str, completion_rate: float, focus_time: int,
                           weak_points: List[str]) -> List[str]:
        suggestions: List[str] = []
        if trend == "有所下滑":
            suggestions.append("近三天有下滑，先降一档难度恢复节奏")
        elif trend == "稳步上升":
            suggestions.append("状态向好，下周可以适度加 15-20 分钟")
        else:
            suggestions.append("节奏稳定，保持当前频次即可")

        if completion_rate and completion_rate < 0.5:
            suggestions.append("把当日任务拆得更小，先保证基础完成")

        if focus_time < 30 * 60:
            suggestions.append("今天累计专注还不到 30 分钟，先开个 25 分钟番茄热个身")

        for wp in weak_points:
            if "投入时间偏少" in wp:
                cat = wp.replace(" 投入时间偏少", "")
                suggestions.append(f"安排一节专门针对「{cat}」的复习段")
                break

        return suggestions[:3] if suggestions else ["继续保持，明天见"]

    def _cycle_confidence(self, gaps: List[int]) -> float:
        n = len(gaps)
        if n < 2:
            return 0.35
        base = 0.55 if n == 2 else 0.7
        if n >= 3:
            try:
                sd = statistics.pstdev(gaps)
            except statistics.StatisticsError:
                sd = 0.0
            if sd <= 1:
                base += 0.25
            elif sd <= 2:
                base += 0.15
            elif sd <= 3:
                base += 0.05
        return min(0.99, base)

    @staticmethod
    def _cycle_default() -> Dict:
        return {
            "next_start_date": None,
            "cycle_days": 28,
            "confidence": 0.0,
            "history_count": 0,
        }


# 单例（按需取用）
dual_ai = DualAIService()
