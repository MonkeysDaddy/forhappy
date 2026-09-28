package com.forhappy.auth;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.forhappy.mapper.AccountCleanupMapper;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

/** 注销冷静期清理任务：到期用户逐一硬删 + 照片文件清理（含路径逃逸防护） */
@ExtendWith(MockitoExtension.class)
class AccountCleanupTaskTest {

    @Mock private AccountCleanupMapper cleanupMapper;
    @Mock private AccountCleanupService cleanupService;

    @InjectMocks private AccountCleanupTask task;

    @TempDir
    Path tempRoot;

    @Test
    void processesEveryExpiredUser() {
        when(cleanupMapper.expiredCoolingUsers()).thenReturn(List.of(101L, 102L));
        when(cleanupMapper.photoUrlsOf(101L)).thenReturn(List.of());
        when(cleanupMapper.photoUrlsOf(102L)).thenReturn(List.of());

        task.run();

        verify(cleanupService).hardDelete(101L);
        verify(cleanupService).hardDelete(102L);
    }

    @Test
    void noopWhenNobodyExpired() {
        when(cleanupMapper.expiredCoolingUsers()).thenReturn(List.of());

        task.run();

        verify(cleanupService, never()).hardDelete(anyLong());
    }

    @Test
    void deletesLocalPhotoFilesOnly() throws Exception {
        Path uploads = Files.createDirectories(tempRoot.resolve("uploads"));
        ReflectionTestUtils.setField(task, "uploadDir", uploads.toString());
        Path photo = Files.writeString(
                Files.createDirectories(uploads.resolve("202609")).resolve("uuid.jpg"), "fake");
        // 上传目录之外的文件：URL 路径逃逸（../）指向它，防护失效时会被误删
        Path outside = Files.writeString(tempRoot.resolve("outside.txt"), "keep me");
        assertTrue(Files.exists(photo));
        assertTrue(Files.exists(outside));

        when(cleanupMapper.expiredCoolingUsers()).thenReturn(List.of(101L));
        when(cleanupMapper.photoUrlsOf(101L)).thenReturn(List.of(
                "/files/202609/uuid.jpg",          // 正常本站路径
                "/files/../outside.txt",            // 路径逃逸：必须跳过（uploads/../outside.txt）
                "https://cdn.example.com/x.png"     // 外链：必须跳过
        ));

        task.run();

        assertFalse(Files.exists(photo), "本站照片文件应被删除");
        assertTrue(Files.exists(outside), "上传目录之外的文件不得被删除");
        verify(cleanupService).hardDelete(101L);
    }

    @Test
    void fileDeleteFailureDoesNotBlockDbCleanup() {
        ReflectionTestUtils.setField(task, "uploadDir",
                tempRoot.resolve("not-exists").toString());
        when(cleanupMapper.expiredCoolingUsers()).thenReturn(List.of(101L));
        when(cleanupMapper.photoUrlsOf(101L)).thenReturn(List.of("/files/202609/uuid.jpg"));

        task.run();

        verify(cleanupService).hardDelete(101L);
    }
}
