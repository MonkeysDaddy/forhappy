package com.forhappy.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/** 管理后台专用查询（列别名直接映射 camelCase Map key） */
@Mapper
public interface AdminManageMapper {

    // ---------- 用户管理 ----------

    @Select("<script>"
            + "SELECT u.id, u.nickname, "
            + " CONCAT(LEFT(u.phone_enc, 3), '****', RIGHT(u.phone_enc, 4)) AS phone, u.gender, u.city,"
            + " u.avatar_url AS avatarUrl, u.mute_until AS muteUntil,"
            + " u.member_tier AS memberTier, u.member_expire_at AS memberExpireAt,"
            + " u.status, u.elo_score AS eloScore, u.verified, u.created_at AS createdAt,"
            + " TIMESTAMPDIFF(YEAR, u.birthday, CURDATE()) AS age"
            + " FROM fh_user u WHERE u.id != 0"
            + " <if test=\"q != null and q != ''\">"
            + " AND (u.nickname LIKE CONCAT('%', #{q}, '%') OR u.phone_enc LIKE CONCAT('%', #{q}, '%')"
            + " OR u.phone_hash = #{phoneHash})"
            + " </if>"
            + " <if test=\"status != null\"> AND u.status = #{status}</if>"
            + " <if test=\"tier != null\"> AND u.member_tier = #{tier}</if>"
            + " ORDER BY u.id DESC LIMIT #{limit} OFFSET #{offset}"
            + "</script>")
    List<Map<String, Object>> users(@Param("offset") int offset,
                                    @Param("limit") int limit,
                                    @Param("q") String q,
                                    @Param("phoneHash") String phoneHash,
                                    @Param("status") Integer status,
                                    @Param("tier") Integer tier);

    @Select("<script>"
            + "SELECT COUNT(*) FROM fh_user u WHERE u.id != 0"
            + " <if test=\"q != null and q != ''\">"
            + " AND (u.nickname LIKE CONCAT('%', #{q}, '%') OR u.phone_enc LIKE CONCAT('%', #{q}, '%'))"
            + " </if>"
            + " <if test=\"status != null\"> AND u.status = #{status}</if>"
            + " <if test=\"tier != null\"> AND u.member_tier = #{tier}</if>"
            + "</script>")
    long countUsers(@Param("q") String q, @Param("phoneHash") String phoneHash,
                    @Param("status") Integer status, @Param("tier") Integer tier);

    @Insert("INSERT INTO fh_user (phone_hash, phone_enc, nickname, gender, prefer_gender, city, status) "
            + "VALUES (#{phoneHash}, #{phone}, #{nickname}, #{gender}, 3, #{city}, 1)")
    int adminInsertUser(@Param("phoneHash") String phoneHash,
                        @Param("phone") String phone,
                        @Param("nickname") String nickname,
                        @Param("gender") int gender,
                        @Param("city") String city);

    @Select("SELECT COUNT(*) FROM fh_user WHERE phone_hash = #{phoneHash}")
    long countPhoneHash(@Param("phoneHash") String phoneHash);

    @Update("UPDATE fh_user SET status = #{status} WHERE id = #{id}")
    int setStatus(@Param("id") long id, @Param("status") int status);

    /** 用户详情：基础 + 消费汇总 */
    @Select("SELECT u.id, u.nickname, "
            + " CONCAT(LEFT(u.phone_enc, 3), '****', RIGHT(u.phone_enc, 4)) AS phone, u.gender, u.city, u.bio,"
            + " u.member_tier AS memberTier, u.member_expire_at AS memberExpireAt,"
            + " u.status, u.elo_score AS eloScore, u.verified, u.created_at AS createdAt"
            + " FROM fh_user u WHERE u.id = #{id}")
    Map<String, Object> userDetail(@Param("id") long id);

    @Select("SELECT COUNT(*) FROM fh_like WHERE from_user = #{id} AND action IN (1, 3)")
    long likesGiven(@Param("id") long id);

    @Select("SELECT COUNT(*) FROM fh_like WHERE to_user = #{id} AND action IN (1, 3)")
    long likesReceived(@Param("id") long id);

    @Select("SELECT COUNT(*) FROM fh_moment WHERE user_id = #{id}")
    long momentCount(@Param("id") long id);

    // ---------- 订单 / 对账 ----------

    @Select("<script>"
            + "SELECT o.id, o.order_no AS orderNo, o.user_id AS userId, u.nickname AS nickname,"
            + " o.amount_cents AS amountCents, o.channel, o.status, o.paid_at AS paidAt,"
            + " o.created_at AS createdAt, p.tier, p.duration_days AS durationDays"
            + " FROM fh_member_order o"
            + " LEFT JOIN fh_user u ON u.id = o.user_id"
            + " LEFT JOIN fh_member_product p ON p.id = o.product_id"
            + " WHERE 1 = 1"
            + " <if test=\"userId != null\"> AND o.user_id = #{userId}</if>"
            + " <if test=\"status != null\"> AND o.status = #{status}</if>"
            + " ORDER BY o.id DESC LIMIT #{limit} OFFSET #{offset}"
            + "</script>")
    List<Map<String, Object>> orders(@Param("offset") int offset,
                                     @Param("limit") int limit,
                                     @Param("userId") Long userId,
                                     @Param("status") Integer status);

    @Select("<script>"
            + "SELECT COUNT(*) FROM fh_member_order o WHERE 1 = 1"
            + " <if test=\"userId != null\"> AND o.user_id = #{userId}</if>"
            + " <if test=\"status != null\"> AND o.status = #{status}</if>"
            + "</script>")
    long countOrders(@Param("userId") Long userId, @Param("status") Integer status);

    @Select("SELECT COUNT(*) AS orders, IFNULL(SUM(amount_cents), 0) AS amountCents,"
            + " DATE(paid_at) AS day FROM fh_member_order WHERE status = 1"
            + " AND paid_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)"
            + " GROUP BY DATE(paid_at) ORDER BY day DESC")
    List<Map<String, Object>> revenueByDay();

    @Select("SELECT status, COUNT(*) AS cnt, IFNULL(SUM(amount_cents), 0) AS amountCents"
            + " FROM fh_member_order GROUP BY status")
    List<Map<String, Object>> ordersByStatus();

    @Select("SELECT COUNT(*) FROM fh_member_order WHERE product_id = #{productId}")
    long countOrdersOfProduct(@Param("productId") long productId);

    // ---------- 行为日志 ----------

    @Select("<script>"
            + "SELECT e.id, e.user_id AS userId, u.nickname AS nickname, e.event,"
            + " e.props, e.created_at AS createdAt"
            + " FROM fh_event e LEFT JOIN fh_user u ON u.id = e.user_id"
            + " WHERE 1 = 1"
            + " <if test=\"userId != null\"> AND e.user_id = #{userId}</if>"
            + " <if test=\"event != null and event != ''\"> AND e.event = #{event}</if>"
            + " ORDER BY e.id DESC LIMIT #{limit} OFFSET #{offset}"
            + "</script>")
    List<Map<String, Object>> events(@Param("offset") int offset,
                                     @Param("limit") int limit,
                                     @Param("userId") Long userId,
                                     @Param("event") String event);

    @Select("<script>"
            + "SELECT COUNT(*) FROM fh_event e WHERE 1 = 1"
            + " <if test=\"userId != null\"> AND e.user_id = #{userId}</if>"
            + " <if test=\"event != null and event != ''\"> AND e.event = #{event}</if>"
            + "</script>")
    long countEvents(@Param("userId") Long userId, @Param("event") String event);

    @Select("SELECT DISTINCT event FROM fh_event ORDER BY event")
    List<String> distinctEvents();

    // ---------- 敏感词 ----------

    @Select("SELECT id, word, created_at AS createdAt FROM fh_sensitive_word ORDER BY id DESC")
    List<Map<String, Object>> listWords();

    @Select("SELECT word FROM fh_sensitive_word")
    List<String> allWords();

    @Insert("INSERT INTO fh_sensitive_word (word) VALUES (#{word})")
    int insertWord(@Param("word") String word);

    @Delete("DELETE FROM fh_sensitive_word WHERE id = #{id}")
    int deleteWord(@Param("id") long id);

    // ---------- 违规记录 ----------

    @Insert("INSERT INTO fh_violation (user_id, type, content, hit_word) "
            + "VALUES (#{userId}, #{type}, #{content}, #{hitWord})")
    int insertViolation(@Param("userId") long userId, @Param("type") String type,
                        @Param("content") String content, @Param("hitWord") String hitWord);

    @Select("<script>"
            + "SELECT v.id, v.user_id AS userId, u.nickname AS nickname, v.type,"
            + " v.content, v.hit_word AS hitWord, v.created_at AS createdAt"
            + " FROM fh_violation v LEFT JOIN fh_user u ON u.id = v.user_id"
            + " WHERE 1 = 1"
            + " <if test=\"userId != null\"> AND v.user_id = #{userId}</if>"
            + " <if test=\"type != null and type != ''\"> AND v.type = #{type}</if>"
            + " ORDER BY v.id DESC LIMIT #{limit} OFFSET #{offset}"
            + "</script>")
    List<Map<String, Object>> violations(@Param("offset") int offset,
                                         @Param("limit") int limit,
                                         @Param("userId") Long userId,
                                         @Param("type") String type);

    @Select("<script>"
            + "SELECT COUNT(*) FROM fh_violation v WHERE 1 = 1"
            + " <if test=\"userId != null\"> AND v.user_id = #{userId}</if>"
            + " <if test=\"type != null and type != ''\"> AND v.type = #{type}</if>"
            + "</script>")
    long countViolations(@Param("userId") Long userId, @Param("type") String type);

    // ---------- 举报处理 ----------

    @Select("<script>"
            + "SELECT r.id, r.reporter, ru.nickname AS reporterName, r.reported,"
            + " tu.nickname AS reportedName, r.category, r.description,"
            + " r.status, r.created_at AS createdAt"
            + " FROM fh_report r"
            + " LEFT JOIN fh_user ru ON ru.id = r.reporter"
            + " LEFT JOIN fh_user tu ON tu.id = r.reported"
            + " WHERE 1 = 1"
            + " <if test=\"status != null\"> AND r.status = #{status}</if>"
            + " ORDER BY r.id DESC LIMIT #{limit} OFFSET #{offset}"
            + "</script>")
    List<Map<String, Object>> reports(@Param("offset") int offset,
                                      @Param("limit") int limit,
                                      @Param("status") Integer status);

    @Select("<script>"
            + "SELECT COUNT(*) FROM fh_report r WHERE 1 = 1"
            + " <if test=\"status != null\"> AND r.status = #{status}</if>"
            + "</script>")
    long countReports(@Param("status") Integer status);

    @Update("UPDATE fh_report SET status = #{status} WHERE id = #{id}")
    int handleReport(@Param("id") long id, @Param("status") int status);

    // ---------- 广告位 ----------

    @Select("SELECT id, title, content, image_url AS imageUrl, link_url AS linkUrl,"
            + " position, active, created_at AS createdAt FROM fh_ad"
            + " ORDER BY id DESC")
    List<Map<String, Object>> adsAll();

    @Select("SELECT id, title, content, image_url AS imageUrl, link_url AS linkUrl"
            + " FROM fh_ad WHERE active = 1 AND position = #{position}"
            + " ORDER BY id DESC LIMIT 3")
    List<Map<String, Object>> activeAds(@Param("position") String position);

    @Insert("INSERT INTO fh_ad (title, content, image_url, link_url, position) "
            + "VALUES (#{title}, #{content}, #{imageUrl}, #{linkUrl}, #{position})")
    int insertAd(@Param("title") String title, @Param("content") String content,
                 @Param("imageUrl") String imageUrl, @Param("linkUrl") String linkUrl,
                 @Param("position") String position);

    @Update("UPDATE fh_ad SET active = #{active} WHERE id = #{id}")
    int setAdActive(@Param("id") long id, @Param("active") int active);

    @Delete("DELETE FROM fh_ad WHERE id = #{id}")
    int deleteAd(@Param("id") long id);

    // ---------- 后台操作日志 ----------

    @Insert("INSERT INTO fh_admin_log (admin, action, detail, ip) "
            + "VALUES (#{admin}, #{action}, #{detail}, #{ip})")
    int insertAdminLogWithIp(@Param("admin") String admin,
                             @Param("action") String action,
                             @Param("detail") String detail,
                             @Param("ip") String ip);

    @Insert("INSERT INTO fh_admin_log (admin, action, detail) "
            + "VALUES (#{admin}, #{action}, #{detail})")
    int insertAdminLog(@Param("admin") String admin, @Param("action") String action,
                       @Param("detail") String detail);

    @Select("<script>"
            + "SELECT id, admin, action, detail, created_at AS createdAt"
            + " FROM fh_admin_log WHERE 1 = 1"
            + " <if test=\"action != null and action != ''\"> AND action LIKE CONCAT('%', #{action}, '%')</if>"
            + " ORDER BY id DESC LIMIT #{limit} OFFSET #{offset}"
            + "</script>")
    List<Map<String, Object>> adminLogs(@Param("offset") int offset,
                                        @Param("limit") int limit,
                                        @Param("action") String action);

    @Select("<script>"
            + "SELECT COUNT(*) FROM fh_admin_log WHERE 1 = 1"
            + " <if test=\"action != null and action != ''\"> AND action LIKE CONCAT('%', #{action}, '%')</if>"
            + "</script>")
    long countAdminLogs(@Param("action") String action);

    // ---------- 管理员账号（RBAC） ----------

    @org.apache.ibatis.annotations.Select("SELECT id, username, role, status, "
            + "created_at AS createdAt FROM fh_admin_user ORDER BY id")
    java.util.List<Map<String, Object>> adminAccounts();

    @org.apache.ibatis.annotations.Select("SELECT * FROM fh_admin_user WHERE username = #{username}")
    Map<String, Object> findAdminByUsername(@Param("username") String username);

    @org.apache.ibatis.annotations.Insert("INSERT INTO fh_admin_user (username, password_hash, salt, role) "
            + "VALUES (#{username}, #{passwordHash}, #{salt}, #{role})")
    int insertAdminAccount(@Param("username") String username,
                           @Param("passwordHash") String passwordHash,
                           @Param("salt") String salt, @Param("role") String role);

    @org.apache.ibatis.annotations.Update("UPDATE fh_admin_user SET status = #{status} WHERE id = #{id}")
    int setAdminStatus(@Param("id") long id, @Param("status") int status);

    @org.apache.ibatis.annotations.Update("UPDATE fh_admin_user SET password_hash = #{passwordHash}, salt = #{salt} WHERE id = #{id}")
    int resetAdminPassword(@Param("id") long id,
                           @Param("passwordHash") String passwordHash, @Param("salt") String salt);

    @org.apache.ibatis.annotations.Select("SELECT id FROM fh_user WHERE status = 1")
    java.util.List<Long> activeUserIds();

    @org.apache.ibatis.annotations.Insert("INSERT INTO fh_notification (user_id, type, title, content) "
            + "VALUES (#{userId}, #{type}, #{title}, #{content})")
    int insertNotification(@Param("userId") long userId, @Param("type") String type,
                           @Param("title") String title, @Param("content") String content);

    @org.apache.ibatis.annotations.Select("SELECT id, url, is_avatar AS isAvatar,"
            + " review_status AS reviewStatus, sort_order AS sortOrder"
            + " FROM fh_photo WHERE user_id = #{userId} ORDER BY sort_order, id")
    java.util.List<Map<String, Object>> adminUserPhotos(@Param("userId") long userId);

    /** 软删除并释放手机号：phone_hash 改写为不可逆占位，nickname 匿名化 */
    @org.apache.ibatis.annotations.Update("UPDATE fh_user SET status = 9, "
            + "phone_hash = CONCAT('deleted-', id, '-', UNIX_TIMESTAMP()), "
            + "phone_enc = '', nickname = CONCAT('已注销用户', id), "
            + "avatar_url = NULL, bio = '', wechat = NULL, instagram = NULL, facebook = NULL, "
            + "social_showcase = NULL WHERE id = #{id}")
    int anonymizeDeletedUser(@Param("id") long id);

    @org.apache.ibatis.annotations.Select("<script>"
            + "SELECT id FROM fh_user WHERE status = 1"
            + " <if test=\"tier == 9\"> AND member_tier IN (1, 2)</if>"
            + " <if test=\"tier == 1\"> AND member_tier = 1</if>"
            + " <if test=\"tier == 2\"> AND member_tier = 2</if>"
            + "</script>")
    java.util.List<Long> activeUserIdsByTier(@Param("tier") int tier);

    @org.apache.ibatis.annotations.Select("SELECT * FROM fh_report WHERE id = #{id}")
    Map<String, Object> findReportById(@Param("id") long id);
}