package com.warmcircle.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

/**
 * 安全桥接服务
 *
 * Java 主后端 ↔ Python 安全微服务（端口 8000）
 *
 * 分工说明：
 *  - Java 负责业务逻辑（用户、记账、学习计划等）
 *  - Python 负责安全检测（链接过滤、WAF）
 *  - 每次用户发布内容前，Java 调用 Python 先检测
 *
 * 好处：
 *  - Python 的安全生态（OWASP 工具、第三方检测库）更丰富
 *  - Java 主后端崩了不影响安全服务，安全服务崩了不影响主业务
 *  - 两个服务独立部署，可以分别扩容
 */
@Service
public class SecurityBridgeService {

    @Value("${warmcircle.security-service-url}")
    private String securityServiceUrl;

    private final RestTemplate restTemplate = new RestTemplate();

    /**
     * 检测用户输入内容是否安全
     * 调用 Python 安全微服务的 /check 接口
     *
     * @param content 用户输入的文字（可能包含链接）
     * @return true=安全，false=危险
     */
    public boolean checkContent(String content) {
        try {
            var request = Map.of("content", content);
            var response = restTemplate.postForObject(
                securityServiceUrl + "/security/check",
                request,
                Map.class
            );
            if (response != null) {
                return Boolean.TRUE.equals(response.get("safe"));
            }
        } catch (Exception e) {
            // Python 安全服务不可用时，默认拒绝（安全优先）
            // 你可以改成 return true 让业务继续（可用性优先）
            System.err.println("[安全服务不可用] 内容检测失败，默认拒绝: " + e.getMessage());
            return false;
        }
        return false;
    }

    /**
     * 检测结果带原因
     */
    public Map<String, Object> checkContentWithReason(String content) {
        try {
            var request = Map.of("content", content);
            @SuppressWarnings("unchecked")
            Map<String, Object> response = restTemplate.postForObject(
                securityServiceUrl + "/security/check",
                request,
                Map.class
            );
            return response != null ? response : Map.of("safe", false, "reason", "安全服务无响应");
        } catch (Exception e) {
            return Map.of("safe", false, "reason", "安全服务不可用");
        }
    }
}
