package com.deblurgan.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Permissive CORS configuration so the Flutter app (running on an emulator,
 * a device on the LAN, or Flutter web during development) can call this API
 * without being blocked by the browser/webview's CORS checks.
 * <p>
 * NOTE: {@code allowedOrigins("*")} is intentionally wide open for this
 * final-year-project development/demo environment. In a production
 * deployment this should be tightened to an explicit allow-list of trusted
 * origins.
 */
@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOrigins("*")
                .allowedMethods("GET", "POST");
    }
}
