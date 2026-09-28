package com.forhappy.common;

import java.nio.file.Paths;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** /files/** → 本地上传目录（演示环境的 OSS+CDN 替代） */
@Configuration
public class FileConfig implements WebMvcConfigurer {

    @Value("${forhappy.upload.dir:./data/uploads}")
    private String uploadDir;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/files/**")
                .addResourceLocations(
                        Paths.get(uploadDir).toAbsolutePath().normalize().toUri().toString());
    }
}
