"""
豆包 AI 服务 —— 学习计划 / 文案生成
统一走火山引擎方舟 v3（兼容 OpenAI 格式）：
    POST https://ark.cn-beijing.volces.com/api/v3/chat/completions
    Authorization: Bearer {ARK_API_KEY}

仅用于自然语言生成类任务。统计 / 周期预测 / 数据分析都在本地算法里跑，不走 AI。
"""
import json
import requests
from typing import Any, Dict

from config.settings import settings


class AIService:
    def __init__(self):
        self.api_key = settings.ARK_API_KEY
        self.base_url = settings.ARK_BASE_URL.rstrip("/")
        self.model = settings.ARK_MODEL

    # ── 对外入口 ──────────────────────────────────────────────────

    def generate_study_plan(self, user_data: Dict[str, Any]) -> Dict[str, Any]:
        prompt = self._build_study_plan_prompt(user_data)
        response_text = self._call_doubao_api(prompt)
        return self._parse_study_plan(response_text)

    def adjust_plan_by_progress(self, plan: Dict, completion_rate: float) -> Dict:
        if completion_rate < 0.7:
            plan['adjustment_suggestion'] = "建议放慢节奏，重点巩固基础"
        elif completion_rate > 0.9:
            plan['adjustment_suggestion'] = "进度良好，可以适当增加难度"
        else:
            plan['adjustment_suggestion'] = "保持当前节奏"
        return plan

    # ── Prompt 构造 ───────────────────────────────────────────────

    def _build_study_plan_prompt(self, data: Dict) -> str:
        strengths = ', '.join(data.get('strengths', []))
        weaknesses = ', '.join(data.get('weaknesses', []))

        return f"""你是一位专业的学习规划师，请为以下用户生成详细的学习计划。

**用户画像**
- 学段：{data['education_level']}
- 学习目标：{data['goal']}
- 计划时长：{data['duration']}天
- 每日可用时间：{data['daily_hours']}小时
- 强项科目：{strengths}
- 弱项科目：{weaknesses}
- 当前基础：{data.get('current_level', '中等')}

**要求**
1. 按周划分阶段，每周明确学习重点
2. 每天具体到科目和时间分配
3. 包含复习巩固环节
4. 根据强弱项调整学习比重（弱项多分配30%时间）
5. 设置阶段性检测点

请严格以JSON格式返回，不要有任何额外文字，结构如下：
{{
  "overall_goal": "总体目标描述",
  "phases": [
    {{
      "week": 1,
      "theme": "基础巩固周",
      "focus": "本周学习重点",
      "daily_tasks": [
        {{
          "day": 1,
          "date_label": "第1天",
          "subjects": [
            {{"name": "数学", "hours": 2, "content": "微积分基础", "type": "学习"}},
            {{"name": "英语", "hours": 1.5, "content": "单词背诵100个", "type": "记忆"}},
            {{"name": "复习", "hours": 0.5, "content": "回顾昨日内容", "type": "复习"}}
          ]
        }}
      ]
    }}
  ],
  "checkpoints": [
    {{"week": 2, "type": "阶段测试", "content": "第一章综合测试"}},
    {{"week": 4, "type": "模拟考试", "content": "月度模拟测试"}}
  ],
  "tips": [
    "每天早上复习前一天内容",
    "遇到难题及时标记，周末集中攻克"
  ]
}}"""

    # ── 火山方舟调用 ──────────────────────────────────────────────

    def _call_doubao_api(self, prompt: str) -> str:
        if not self.api_key or not self.api_key.startswith("ark-"):
            print("[AI] ARK_API_KEY 未配置，返回默认计划")
            return ""

        url = f"{self.base_url}/chat/completions"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
        }
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": "你是一位专业的学习规划师，擅长为不同学段的学生制定高效学习计划。"},
                {"role": "user", "content": prompt},
            ],
            "temperature": 0.7,
            "max_tokens": 4000,
        }

        try:
            resp = requests.post(url, headers=headers, json=payload, timeout=30)
            resp.raise_for_status()
            data = resp.json()
            return data["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"[AI] 豆包API调用失败: {e}")
            return ""

    def _parse_study_plan(self, response: str) -> Dict[str, Any]:
        if not response:
            return self._get_default_plan()
        try:
            start = response.find('{')
            end = response.rfind('}') + 1
            return json.loads(response[start:end])
        except Exception as e:
            print(f"[AI] 解析学习计划失败: {e}")
            return self._get_default_plan()

    # ── 兜底计划 ──────────────────────────────────────────────────

    def _get_default_plan(self) -> Dict[str, Any]:
        return {
            "overall_goal": "系统性学习，稳步提升",
            "phases": [
                {
                    "week": 1,
                    "theme": "基础巩固周",
                    "focus": "夯实基础知识",
                    "daily_tasks": [
                        {
                            "day": i,
                            "date_label": f"第{i}天",
                            "subjects": [
                                {"name": "主科1", "hours": 2, "content": "基础知识学习", "type": "学习"},
                                {"name": "主科2", "hours": 1.5, "content": "练习巩固", "type": "练习"},
                            ],
                        }
                        for i in range(1, 8)
                    ],
                }
            ],
            "checkpoints": [
                {"week": 1, "type": "周测", "content": "本周知识点测试"}
            ],
            "tips": [
                "保持规律作息",
                "及时复习巩固",
            ],
        }


ai_service = AIService()
