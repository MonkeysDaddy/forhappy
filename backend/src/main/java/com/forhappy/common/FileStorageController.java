package com.forhappy.common;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/**
 * 演示环境文件上传（OSS 直传的本地替代，设计 7.3 profile 模块）：
 * 存到本地 data/uploads/yyyyMM/，通过 /files/** 静态映射提供访问。
 * 生产环境替换为 OSS 预签名直传即可，客户端接口不变（返回完整 URL）。
 */
@RestController
@RequestMapping("/api/v1")
public class FileStorageController {

    private static final Set<String> ALLOWED_EXT = Set.of("jpg", "jpeg", "png", "webp", "gif");
    private static final long MAX_SIZE = 10 * 1024 * 1024;

    @Value("${forhappy.upload.dir:./data/uploads}")
    private String uploadDir;

    @PostMapping("/upload")
    public Result<Map<String, String>> upload(@RequestParam("file") MultipartFile file)
            throws IOException {
        if (file.isEmpty()) {
            throw new BizException(400, "文件不能为空");
        }
        if (file.getSize() > MAX_SIZE) {
            throw new BizException(400, "图片不能超过 10MB");
        }
        String ext = extOf(file.getOriginalFilename());
        if (!ALLOWED_EXT.contains(ext)) {
            throw new BizException(400, "仅支持 jpg/png/webp/gif 图片");
        }
        String month = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMM"));
        Path dir = Paths.get(uploadDir, month);
        Files.createDirectories(dir);
        String name = UUID.randomUUID().toString().replace("-", "") + "." + ext;
        Files.copy(file.getInputStream(), dir.resolve(name));
        String url = ServletUriComponentsBuilder.fromCurrentContextPath()
                .path("/files/").path(month).path("/").path(name)
                .build().toUriString();
        return Result.ok(Map.of("url", url));
    }

    private static String extOf(String filename) {
        if (filename == null) {
            return "";
        }
        int i = filename.lastIndexOf('.');
        return i < 0 ? "" : filename.substring(i + 1).toLowerCase();
    }
}
