package com.forhappy.auth;

import com.forhappy.mapper.AccountCleanupMapper;
import com.forhappy.mapper.AdminManageMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 单用户注销硬删（事务）：删除内容数据 → 匿名化主表。
 * 匿名化放在最后：事务失败整体回滚后用户仍是 status=5，次日调度可无损重试。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AccountCleanupService {

    private final AccountCleanupMapper cleanupMapper;
    private final AdminManageMapper adminManageMapper;

    @Transactional
    public void hardDelete(long uid) {
        cleanupMapper.deleteMomentLikes(uid);
        cleanupMapper.deleteMomentComments(uid);
        cleanupMapper.deleteMoments(uid);
        cleanupMapper.deletePhotos(uid);
        cleanupMapper.deleteLikes(uid);
        cleanupMapper.deleteNotifications(uid);
        cleanupMapper.deleteBlocks(uid);
        cleanupMapper.deactivateMatches(uid);
        cleanupMapper.deactivateConversations(uid);
        adminManageMapper.anonymizeDeletedUser(uid);
        log.info("用户 #{} 注销硬删完成（内容出库 + 主表匿名化）", uid);
    }
}
