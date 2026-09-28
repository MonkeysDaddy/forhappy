package com.forhappy.auth;

import com.forhappy.mapper.AccountCleanupMapper;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 注销冷静期清理（设计 6.4：7 天冷静期后硬删）：
 * 每天 04:30 扫描 status=5 且满 7 天的用户，删除其内容数据并匿名化主表。
 * 单机调度即可（多实例部署时需分布式锁或改由调度平台触发，与限流器换 Redis 同期处理）。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AccountCleanupTask {

    private final AccountCleanupMapper cleanupMapper;
    private final AccountCleanupService cleanupService;

    /** 字段默认值兜底：脱离 Spring 容器构造（如单测）时 @Value 不会生效 */
    @Value("${forhappy.upload.dir:./data/uploads}")
    private String uploadDir = "./data/uploads";

    @Scheduled(cron = "${forhappy.cleanup.cron:0 30 4 * * *}")
    public void run() {
        List<Long> expired = cleanupMapper.expiredCoolingUsers();
        if (expired.isEmpty()) {
            return;
        }
        log.info("注销冷静期清理：{} 个用户到期，开始硬删", expired.size());
        for (Long uid : expired) {
            try {
                deletePhotoFiles(uid);
                cleanupService.hardDelete(uid);
            } catch (Exception e) {
                log.error("用户 #{} 注销硬删失败，将于下次调度重试", uid, e);
            }
        }
    }

    /** 照片是最敏感的个人信息：数据库记录删除前先尽力清理磁盘文件（失败不阻断，行删除后文件即不可达） */
    private void deletePhotoFiles(long uid) {
        Path base = Paths.get(uploadDir).toAbsolutePath().normalize();
        for (String url : cleanupMapper.photoUrlsOf(uid)) {
            try {
                if (url == null || !url.contains("/files/")) {
                    continue;
                }
                Path file = base.resolve(url.substring(url.indexOf("/files/") + "/files/".length()))
                        .normalize();
                if (!file.startsWith(base)) { // 只删上传目录内的文件，防路径逃逸
                    continue;
                }
                Files.deleteIfExists(file);
            } catch (Exception e) {
                log.warn("照片文件删除失败（继续清理数据库记录）url={}", url, e);
            }
        }
    }
}
