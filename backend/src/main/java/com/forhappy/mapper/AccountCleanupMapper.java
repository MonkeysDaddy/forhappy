package com.forhappy.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/**
 * 注销冷静期硬删（设计 6.4：注销后删除个人信息）。
 * 保留 fh_report / fh_violation / fh_event / fh_member_order（举报取证、违规审计、
 * 埋点统计、订单对账均为平台侧数据，不含可识别的个人资料）。
 */
@Mapper
public interface AccountCleanupMapper {

    /**
     * 冷静期（status=5）满 7 天的用户。updated_at 随任意 UPDATE 前移且注销当下即写入，
     * 因此该条件只会推迟删除、绝不会提前；仅存的偏移来源是冷静期内管理员的改动。
     */
    @Select("SELECT id FROM fh_user WHERE status = 5 AND updated_at < NOW() - INTERVAL 7 DAY")
    List<Long> expiredCoolingUsers();

    @Select("SELECT url FROM fh_photo WHERE user_id = #{uid}")
    List<String> photoUrlsOf(@Param("uid") long uid);

    // ---------- 内容删除（先清依赖行再删主行，避免孤儿数据） ----------

    /** 该用户的动态及其下的点赞/评论，连同他人在这些动态下的互动一并删除 */
    @Delete("DELETE FROM fh_moment_like WHERE user_id = #{uid} OR moment_id IN "
            + "(SELECT id FROM fh_moment WHERE user_id = #{uid})")
    int deleteMomentLikes(@Param("uid") long uid);

    @Delete("DELETE FROM fh_moment_comment WHERE user_id = #{uid} OR moment_id IN "
            + "(SELECT id FROM fh_moment WHERE user_id = #{uid})")
    int deleteMomentComments(@Param("uid") long uid);

    @Delete("DELETE FROM fh_moment WHERE user_id = #{uid}")
    int deleteMoments(@Param("uid") long uid);

    @Delete("DELETE FROM fh_photo WHERE user_id = #{uid}")
    int deletePhotos(@Param("uid") long uid);

    @Delete("DELETE FROM fh_like WHERE from_user = #{uid} OR to_user = #{uid}")
    int deleteLikes(@Param("uid") long uid);

    @Delete("DELETE FROM fh_notification WHERE user_id = #{uid}")
    int deleteNotifications(@Param("uid") long uid);

    @Delete("DELETE FROM fh_block WHERE blocker = #{uid} OR blocked = #{uid}")
    int deleteBlocks(@Param("uid") long uid);

    /** 配对/会话仅解除（status=2，同 unmatch 语义）：消息为双方共有，保留对方一侧记录 */
    @Update("UPDATE fh_match SET status = 2 "
            + "WHERE (user_lo = #{uid} OR user_hi = #{uid}) AND status = 1")
    int deactivateMatches(@Param("uid") long uid);

    @Update("UPDATE fh_conversation SET status = 2 "
            + "WHERE (user_a = #{uid} OR user_b = #{uid}) AND status = 1")
    int deactivateConversations(@Param("uid") long uid);
}
