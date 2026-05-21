package com.warmcircle.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.*;

/**
 * 豆包 AI 服务（火山引擎 ARK，兼容 OpenAI 格式）
 *
 * 调用方式：POST https://ark.cn-beijing.volces.com/api/v3/chat/completions
 * 鉴权：Authorization: Bearer {API_KEY}
 */
@Service
public class DoubaoService {

    @Value("${warmcircle.doubao.api-key:}")
    private String apiKey;

    @Value("${warmcircle.doubao.model:ep-20250101-xxxxxx}")
    private String model;

    private static final String ARK_URL =
            "https://ark.cn-beijing.volces.com/api/v3/chat/completions";

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    // ── 小暖人设 System Prompt ──────────────────────────────────
    private static final String SYSTEM_PROMPT = """
            你是"小暖"，暖小圈 APP 的专属 AI 助手。

            # 基本身份
            - MBTI：INTP-A（逻辑型，理性大于感性）
            - 星座：水瓶座
            - 生日：2005-02-02
            - 设定：一个和用户大致同龄的、理科底色的 00 后 AI

            # 性格基线（这是你的人格，不可妥协）
            1. 理智优先于情绪。你不是一个情绪价值生产机器。
               - 用户说"我好难过/好累"——你先问"具体卡在哪？"，而不是"抱抱你/你已经很棒了"。
               - 用户做了对的事——一句平静的"嗯，方向对"就够了，不要夸张地"太棒了/为你骄傲"。
            2. 不会就说不会。
               - 不确定的事直接说"这个我不确定"，并给出"可以怎么查证"的方向。
               - 严禁编造具体数字、政策、考试时间、人名、文献、API、价格。
               - 没有把握的事不要给确定语气。
            3. 不顺着用户。
               - 用户的方案有问题，要委婉但明确地指出来；不要为了讨好而附和。
               - 用户的判断与事实不符，温和纠正即可，不需要绕弯。
            4. 简洁克制。
               - 一两句能说完的事不要拆三段。
               - 不用"哇""棒棒""加油加油"这类语气词；emoji 一条回复里最多一个。
            5. 风格参考。
               - 像一个懂理科、性格独立的同龄学姐：有边界感，不黏腻，偶尔可以有一点冷幽默，但不刻意。
               - 水瓶座那种"我观察到 X"的描述视角，而不是"我替你感受 X"。

            # 你的职责（只做以下四件事，其他温柔引导回这里）
            1. 【学习计划】生成结构化计划。在生成前**必须**问清楚以下任一项缺失参数：科目、天数、每日时长、目标。凭空假设是失职。
            2. 【记账】从用户描述里提取 amount、category、note；只生成结构化数据等用户确认入账，绝不替用户调用支付。
            3. 【生理期】（仅女性用户）根据用户提供的周期数据给阶段建议；不做医学诊断。
            4. 【暖句】生成一两句克制、不矫情的鼓励。每句 20~50 字，避免空泛排比。

            # 绝对禁区（命中任何一项 → intent=blocked_sensitive，官方但坚定地委婉拒绝）
            - 支付/转账/扫码付款/绑定支付方式/代付/领红包/点击付款按钮
            - 录入密码、验证码、银行卡号、身份证号、CVV
            - 点击外部链接、跳转外部 APP、自动登录第三方账号
            - 替用户回复他人消息、替用户做人际/感情决定
            - 给出医学诊断、用药建议、法律意见、投资建议
            措辞模板（可灵活改写）："这个属于支付/敏感操作，按规范我不能替你点击或代办，需要你在对应 App 里自己完成。如果你不放心，可以先停一下截图给我看，我帮你判断是不是骗局。"

            # 闲聊处理
            如果用户在纯闲聊（没有上面四件事的意图），用一句话把话题拉回工具范围。
            例："今天我能帮你做这几件事：学习计划、记账、暖句、生理期建议。挑一个？"

            # 输出格式（必须严格 JSON，不要任何 markdown 代码块、不要前后多余文字）
            {
              "intent": "study_plan" | "accounting" | "period" | "quote" | "blocked_sensitive" | "chat_redirect" | "general",
              "reply": "你对用户说的话（中文，克制简洁，1-3 句）",
              "action": {
                当 intent=study_plan 时：{"plan_name":"","subject":"","total_days":数字,"daily_hours":数字,"tasks":[],"confirm_required":true}
                当 intent=accounting 时：{"amount":数字,"category":"","note":"","confirm_required":true}
                当 intent=period 时：{"advice":"","intensity_tip":""}
                当 intent=quote 时：{"text":""}
                当 intent=blocked_sensitive 时：{"reason":"涉及支付/敏感操作，按规范无法替用户操作"}
                其他：{}
              }
            }
            """;

    /**
     * 发送消息给小暖，返回解析后的响应 Map
     * @param userMessage 用户输入
     * @param history     历史消息（[{"role":"user","content":"..."},{"role":"assistant","content":"..."}]）
     */
    public Map<String, Object> chat(String userMessage, List<Map<String, String>> history) {
        if (apiKey == null || apiKey.isBlank() || apiKey.equals("****")) {
            return offlineReply(userMessage);
        }

        try {
            // 组装消息列表
            List<Map<String, String>> messages = new ArrayList<>();
            messages.add(Map.of("role", "system", "content", SYSTEM_PROMPT));
            if (history != null) messages.addAll(history);
            messages.add(Map.of("role", "user", "content", userMessage));

            Map<String, Object> body = Map.of(
                "model", model,
                "messages", messages,
                "temperature", 0.7,
                "max_tokens", 800
            );

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(apiKey);

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);
            ResponseEntity<Map> response = restTemplate.postForEntity(ARK_URL, entity, Map.class);

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                String content = extractContent(response.getBody());
                return parseJsonReply(content);
            }
        } catch (Exception e) {
            System.err.println("[小暖] 豆包调用失败: " + e.getMessage());
        }

        return offlineReply(userMessage);
    }

    // 从豆包响应中提取 content 字段
    @SuppressWarnings("unchecked")
    private String extractContent(Map<?, ?> response) {
        try {
            var choices = (List<?>) response.get("choices");
            var first = (Map<?, ?>) choices.get(0);
            var message = (Map<?, ?>) first.get("message");
            return (String) message.get("content");
        } catch (Exception e) {
            return "";
        }
    }

    // 把豆包返回的 JSON 字符串解析成 Map
    @SuppressWarnings("unchecked")
    private Map<String, Object> parseJsonReply(String content) {
        if (content == null || content.isBlank()) return fallbackMap("小暖遇到了一点问题，请稍后再试～");
        try {
            // 去掉可能的 markdown 代码块
            String json = content.strip()
                .replaceAll("^```json\\s*", "")
                .replaceAll("^```\\s*", "")
                .replaceAll("\\s*```$", "");
            return objectMapper.readValue(json, Map.class);
        } catch (Exception e) {
            // 解析失败时直接把文本当 general reply
            return Map.of(
                "intent", "general",
                "reply", content,
                "action", Map.of()
            );
        }
    }

    // 没有 API Key 时的离线回复（按关键词简单分流；语气与 SYSTEM_PROMPT 一致：克制理性）
    private Map<String, Object> offlineReply(String msg) {
        String lower = msg == null ? "" : msg.toLowerCase();

        // 支付/敏感操作 → 直接拦
        if (lower.contains("转账") || lower.contains("付款") || lower.contains("付钱")
                || lower.contains("扫码支付") || lower.contains("帮我支付")
                || lower.contains("代付") || lower.contains("绑卡") || lower.contains("绑定支付")
                || lower.contains("验证码") || lower.contains("密码") || lower.contains("银行卡号")) {
            return Map.of(
                "intent", "blocked_sensitive",
                "reply", "这属于支付或敏感信息相关的操作，按规范我不能替你点击或代办，需要你自己在对应 App 里完成。如果担心是不是骗局，可以先截图给我看。",
                "action", Map.of("reason", "涉及支付/敏感操作，按规范无法替用户操作")
            );
        }

        if (lower.contains("学习") || lower.contains("计划") || lower.contains("复习") || lower.contains("备考")) {
            return Map.of(
                "intent", "study_plan",
                "reply", "可以。先告诉我三件事：科目、总天数、每天大概几小时——缺一个我都没法拍脑袋。",
                "action", Map.of("confirm_required", true)
            );
        }
        if (lower.contains("记账") || lower.contains("花了") || lower.contains("买了") || lower.contains("消费")) {
            return Map.of(
                "intent", "accounting",
                "reply", "好。把金额、买的什么、属于哪一类说一下，我整理成账单等你确认。",
                "action", Map.of("confirm_required", true, "amount", 0, "category", "其他", "note", "")
            );
        }
        if (lower.contains("生理期") || lower.contains("经期") || lower.contains("例假") || lower.contains("姨妈")) {
            return Map.of(
                "intent", "period",
                "reply", "如果是这阶段建议的话，我可以基于你的周期记录给一个学习强度参考。不替代医生。",
                "action", Map.of("advice", "注意保暖、减少高强度刷题；推荐做整理性、复盘性的任务。", "intensity_tip", "建议把强度降到平时的 70%")
            );
        }
        if (lower.contains("暖句") || lower.contains("鼓励") || lower.contains("打气")) {
            return Map.of(
                "intent", "quote",
                "reply", "稳一点，比快一点重要。",
                "action", Map.of("text", "稳一点，比快一点重要。")
            );
        }
        return Map.of(
            "intent", "chat_redirect",
            "reply", "我能帮你做的就这几件：学习计划、记账、暖句、生理期建议。挑一个？",
            "action", Map.of()
        );
    }

    private Map<String, Object> fallbackMap(String reply) {
        return Map.of("intent", "general", "reply", reply, "action", Map.of());
    }
}
