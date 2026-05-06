package com.warmcircle.controller;

import com.warmcircle.service.DoubaoService;
import com.warmcircle.service.SecurityBridgeService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.Data;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 小暖 AI 聊天接口
 *
 * POST /ai/chat
 *   → 安全检测（Python WAF）
 *   → 豆包 AI 意图识别 + 回复
 *   → 返回结构化 JSON（前端据此决定弹出哪个功能确认框）
 *
 * intent 说明：
 *   study_plan    → 前端弹出「学习计划确认卡」
 *   accounting    → 前端弹出「记账确认框」
 *   period        → 前端弹出「生理期建议卡」
 *   chat_redirect → 前端显示引导回功能的文字
 *   general       → 普通对话气泡
 */
@RestController
@RequestMapping("/ai")
public class AIChatController {

    @Autowired private DoubaoService doubaoService;
    @Autowired private SecurityBridgeService securityBridge;

    @PostMapping("/chat")
    public ResponseEntity<?> chat(@RequestBody ChatRequest req, HttpServletRequest http) {
        Long userId = (Long) http.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(401).body(Map.of("msg", "请先登录"));
        }

        String message = req.getMessage();
        if (message == null || message.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("msg", "消息不能为空"));
        }
        if (message.length() > 500) {
            return ResponseEntity.badRequest().body(Map.of("msg", "消息太长了，请简短描述～"));
        }

        // 1. WAF + 敏感词检测（调用 Python 安全服务）
        boolean safe = securityBridge.checkContent(message);
        if (!safe) {
            return ResponseEntity.ok(Map.of(
                "intent", "blocked",
                "reply", "你的消息包含了一些我没办法处理的内容，换个方式说说吧～",
                "action", Map.of()
            ));
        }

        // 2. 调用豆包，返回结构化意图
        Map<String, Object> result = doubaoService.chat(message, req.getHistory());
        return ResponseEntity.ok(result);
    }

    @Data
    public static class ChatRequest {
        private String message;
        // 历史消息（最近几轮，用于上下文连贯）
        private List<Map<String, String>> history;
    }
}
