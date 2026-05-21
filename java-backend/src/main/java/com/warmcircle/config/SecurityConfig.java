package com.warmcircle.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;

/**
 * Spring Security 配置
 * - JWT 无状态认证
 * - 跨域配置
 * - 接口权限控制
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Autowired
    private JwtUtil jwtUtil;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            // 关闭 CSRF（APP 用 JWT，不需要 CSRF）
            .csrf(csrf -> csrf.disable())

            // 跨域配置
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))

            // 无状态会话（JWT 不用 Session）
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

            // 接口权限规则
            .authorizeHttpRequests(auth -> auth
                // 不需要登录的接口
                .requestMatchers("/auth/register", "/auth/login", "/auth/send-code").permitAll()
                // 公开接口（查看资源；"今日推荐暖句"已下沉到客户端走一言公开 API，不再由后端提供）
                .requestMatchers("/resource/list", "/resource/detail/**").permitAll()
                // 答疑公开浏览（但回答需要管理员）
                .requestMatchers("/qa/list", "/qa/detail/**").permitAll()
                // 其他全部需要登录
                .anyRequest().authenticated()
            )

            // 在标准 UsernamePassword 过滤器前，加入 JWT 验证过滤器
            .addFilterBefore(jwtFilter(), UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /** JWT 验证过滤器：每次请求都检查 Token */
    @Bean
    public OncePerRequestFilter jwtFilter() {
        return new OncePerRequestFilter() {
            @Override
            protected void doFilterInternal(HttpServletRequest request,
                                            HttpServletResponse response,
                                            FilterChain chain) throws ServletException, IOException {

                String header = request.getHeader("Authorization");
                if (header != null && header.startsWith("Bearer ")) {
                    String token = header.substring(7);
                    if (jwtUtil.validate(token)) {
                        // Token 有效，把用户 ID 塞进请求属性，后续 Controller 直接取用
                        request.setAttribute("userId", jwtUtil.getUserId(token));
                        request.setAttribute("isAdmin", jwtUtil.isAdmin(token));
                    }
                }

                chain.doFilter(request, response);
            }
        };
    }

    /** 跨域配置：允许 Flutter APP 访问 */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(List.of("*"));
        config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    /** 密码加密（BCrypt，比 MD5 安全 100 倍） */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
