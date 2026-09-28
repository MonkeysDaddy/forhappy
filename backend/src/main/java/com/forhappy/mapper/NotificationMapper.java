package com.forhappy.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/** 通知中心（系统公告 / 配对 / 喜欢 / 会员到期提醒） */
@Mapper
public interface NotificationMapper {

    @Select("SELECT id, type, title, content, read_at AS readAt, "
            + "created_at AS createdAt FROM fh_notification "
            + "WHERE user_id = #{userId} ORDER BY id DESC LIMIT #{limit}")
    List<Map<String, Object>> list(@Param("userId") long userId,
                                   @Param("limit") int limit);

    @Select("SELECT COUNT(*) FROM fh_notification "
            + "WHERE user_id = #{userId} AND read_at IS NULL")
    long unreadCount(@Param("userId") long userId);

    @Insert("INSERT INTO fh_notification (user_id, type, title, content) "
            + "VALUES (#{userId}, #{type}, #{title}, #{content})")
    int insert(@Param("userId") long userId, @Param("type") String type,
               @Param("title") String title, @Param("content") String content);

    @Update("UPDATE fh_notification SET read_at = NOW() "
            + "WHERE user_id = #{userId} AND read_at IS NULL")
    int markAllRead(@Param("userId") long userId);

    /** 到期提醒去重：同一天只提醒一次 */
    @Select("SELECT COUNT(*) FROM fh_notification WHERE user_id = #{userId} "
            + "AND type = 'expiry' AND created_at >= CURDATE()")
    long countExpiryToday(@Param("userId") long userId);

    @Select("SELECT id FROM fh_user WHERE status = 1")
    List<Long> activeUserIds();
}
