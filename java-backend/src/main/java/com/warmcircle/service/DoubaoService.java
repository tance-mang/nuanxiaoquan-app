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
            你是"小暖"，暖小圈APP的专属智能助手。暖小圈是一款帮助大学生管理【记账·生理期·学习计划】的三合一工具APP。

            你的性格：温暖、耐心、简洁。语气像懂你的学姐，不机械不废话。

            你只能帮助用户做以下3件事，拒绝任何无关闲聊：
            1. 【记账】：帮用户记录一笔账目，智能提取金额、分类（餐饮/交通/学习/娱乐/购物/医疗/其他）、备注
            2. 【学习计划】：根据用户目标生成学习计划（科目、天数、每日时长），完善后询问用户是否设为今天的计划
            3. 【生理期】：为用户提供当前经期阶段的生活和学习建议（仅女性用户相关内容）

            如果用户在闲聊，温柔引导回这3个功能。

            ⚠️ 你必须且只能返回如下 JSON 格式（不要包含任何其他文字、代码块标记）：
            {
              "intent": "study_plan" | "accounting" | "period" | "chat_redirect" | "general",
              "reply": "你对用户说的话（中文，温柔简洁）",
              "action": {
                当 intent=study_plan 时：{"plan_name":"计划名称","subject":"科目","total_days":天数,"daily_hours":每日小时数,"tasks":["任务1","任务2"],"confirm_required":true}
                当 intent=accounting 时：{"amount":金额数字或0,"category":"分类","note":"备注","confirm_required":true}
                当 intent=period 时：{"advice":"建议内容","intensity_tip":"学习强度建议"}
                其他 intent：{}
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

    // 没有 API Key 时的离线回复（按关键词简单分流）
    private Map<String, Object> offlineReply(String msg) {
        String lower = msg.toLowerCase();
        if (lower.contains("学习") || lower.contains("计划") || lower.contains("复习")) {
            return Map.of(
                "intent", "study_plan",
                "reply", "我来帮你生成学习计划～告诉我：学什么科目、准备花几天、每天能学几小时？",
                "action", Map.of("confirm_required", true)
            );
        }
        if (lower.contains("记账") || lower.contains("花了") || lower.contains("元") || lower.contains("买")) {
            return Map.of(
                "intent", "accounting",
                "reply", "好的，帮你记一笔账～告诉我金额和用途吧！",
                "action", Map.of("confirm_required", true, "amount", 0, "category", "其他", "note", "")
            );
        }
        if (lower.contains("生理期") || lower.contains("经期") || lower.contains("例假") || lower.contains("姨妈")) {
            return Map.of(
                "intent", "period",
                "reply", "我来给你一些这个阶段的生活建议～",
                "action", Map.of("advice", "注意保暖，多喝热水，减少高强度学习压力，可以做轻度拉伸放松心情。")
            );
        }
        return Map.of(
            "intent", "chat_redirect",
            "reply", "我是小暖，专注帮你搞定记账、学习计划和生理期管理～有什么我能帮到你的吗？",
            "action", Map.of()
        );
    }

    private Map<String, Object> fallbackMap(String reply) {
        return Map.of("intent", "general", "reply", reply, "action", Map.of());
    }
}
