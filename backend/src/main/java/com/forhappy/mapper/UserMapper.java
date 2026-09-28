package com.forhappy.mapper;

import com.forhappy.entity.User;
import com.forhappy.entity.UserCardVO;
import java.util.List;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface UserMapper {

    @Select("SELECT * FROM fh_user WHERE id = #{id}")
    User findById(@Param("id") long id);

    @Select("SELECT * FROM fh_user WHERE phone_hash = #{phoneHash}")
    User findByPhoneHash(@Param("phoneHash") String phoneHash);

    @Insert("INSERT INTO fh_user (phone_hash, phone_enc, nickname, avatar_url) "
            + "VALUES (#{phoneHash}, #{phoneEnc}, #{nickname}, #{avatarUrl})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(User user);

    @Update("UPDATE fh_user SET gender=#{gender}, prefer_gender=#{preferGender}, "
            + "birthday=#{birthday}, city=#{city}, lat=#{lat}, lng=#{lng} WHERE id=#{id}")
    int onboarding(User user);

    @Update("UPDATE fh_user SET nickname=#{nickname}, bio=#{bio}, height_cm=#{heightCm}, "
            + "weight_kg=#{weightKg}, education=#{education}, occupation=#{occupation}, "
            + "income=#{income}, tags=#{tags}, wechat=#{wechat}, instagram=#{instagram}, "
            + "facebook=#{facebook}, city=#{city}, avatar_url=#{avatarUrl}, "
            + "hide_distance=#{hideDistance}, social_showcase=#{socialShowcase} WHERE id=#{id}")
    int updateProfile(User user);

    @Update("UPDATE fh_user SET member_tier=#{tier}, member_expire_at=#{expireAt} WHERE id=#{id}")
    int updateMembership(@Param("id") long id, @Param("tier") int tier,
                         @Param("expireAt") java.time.LocalDateTime expireAt);

    @Update("UPDATE fh_user SET status = 5 WHERE id = #{id}")
    int deactivate(@Param("id") long id);

    @Update("UPDATE fh_user SET avatar_url = #{avatarUrl} WHERE id = #{id}")
    int updateAvatar(@Param("id") long id, @Param("avatarUrl") String avatarUrl);

    /** 真人认证通过（演示：自拍照上传即自动通过，正式版接机审+人审） */
    @Update("UPDATE fh_user SET verified = 1 WHERE id = #{id}")
    int updateVerified(@Param("id") long id);

    @Update("UPDATE fh_user SET social_showcase = #{json} WHERE id = #{id}")
    int updateSocialShowcase(@Param("id") long id, @Param("json") String json);

    @Update("UPDATE fh_user SET mute_until = #{muteUntil} WHERE id = #{id}")
    int setMuteUntil(@Param("id") long id,
                     @Param("muteUntil") java.time.LocalDateTime muteUntil);

    /** 社交展示卡续期（月订自动顺延） */
    @Update("UPDATE fh_user SET social_expire_at = #{expireAt} WHERE id = #{id}")
    int extendSocialShowcase(@Param("id") long id,
                             @Param("expireAt") java.time.LocalDateTime expireAt);

    String CARD_COLUMNS = """
            u.id, u.nickname, u.avatar_url, u.gender, u.city, u.occupation, u.bio, u.tags,
            u.verified, u.member_tier, u.last_active_minutes, u.elo_score, u.created_at,
            (u.wechat IS NOT NULL AND u.wechat != '') AS has_wechat,
            TIMESTAMPDIFF(YEAR, u.birthday, CURDATE()) AS age,
            CASE WHEN u.hide_distance = 1 THEN NULL ELSE ROUND(ST_Distance_Sphere(POINT(u.lng, u.lat), POINT(#{lng}, #{lat})) / 1000, 1) END AS distance_km,
            EXISTS(SELECT 1 FROM fh_like l WHERE l.from_user = #{me} AND l.to_user = u.id
                   AND l.action = 1) AS liked
            """;

    String CARD_FILTER = """
            FROM fh_user u
            WHERE u.id != #{me} AND u.status = 1
              AND (#{prefer} = 3 OR u.gender = #{prefer})
              AND (u.prefer_gender = 3 OR u.prefer_gender = #{myGender})
              AND u.city = #{city}
              AND TIMESTAMPDIFF(YEAR, u.birthday, CURDATE()) BETWEEN #{ageMin} AND #{ageMax}
              AND (#{maxDist} <= 0 OR ST_Distance_Sphere(POINT(u.lng, u.lat),
                   POINT(#{lng}, #{lat})) / 1000 <= #{maxDist})
              AND NOT EXISTS (SELECT 1 FROM fh_block b
                   WHERE (b.blocker = #{me} AND b.blocked = u.id)
                      OR (b.blocker = u.id AND b.blocked = #{me}))
              AND NOT EXISTS (SELECT 1 FROM fh_like h
                   WHERE h.from_user = #{me} AND h.to_user = u.id AND h.action = 2)
              AND (#{q} = '' OR u.nickname LIKE CONCAT('%', #{q}, '%')
                   OR u.occupation LIKE CONCAT('%', #{q}, '%')
                   OR u.bio LIKE CONCAT('%', #{q}, '%'))
              AND (#{verifiedOnly} = 0 OR u.verified = 1)
              AND (#{education} = '' OR u.education = #{education})
              AND (#{occupation} = '' OR u.occupation LIKE CONCAT('%', #{occupation}, '%'))
            """;

    @Select("SELECT " + CARD_COLUMNS + CARD_FILTER
            + " ORDER BY ST_Distance_Sphere(POINT(u.lng, u.lat), POINT(#{lng}, #{lat})) ASC LIMIT #{limit} OFFSET #{offset}")
    List<UserCardVO> feedByDistance(@Param("me") long me, @Param("prefer") int prefer,
                                    @Param("myGender") int myGender, @Param("city") String city,
                                    @Param("lat") double lat, @Param("lng") double lng,
                                    @Param("ageMin") int ageMin, @Param("ageMax") int ageMax,
                                    @Param("maxDist") int maxDist,
                                    @Param("q") String q, @Param("verifiedOnly") int verifiedOnly,
                                    @Param("education") String education, @Param("occupation") String occupation,
                                    @Param("limit") int limit, @Param("offset") int offset);

    @Select("SELECT " + CARD_COLUMNS + CARD_FILTER
            + " ORDER BY u.last_active_minutes ASC LIMIT #{limit} OFFSET #{offset}")
    List<UserCardVO> feedByActive(@Param("me") long me, @Param("prefer") int prefer,
                                  @Param("myGender") int myGender, @Param("city") String city,
                                  @Param("lat") double lat, @Param("lng") double lng,
                                  @Param("ageMin") int ageMin, @Param("ageMax") int ageMax,
                                  @Param("maxDist") int maxDist,
                                  @Param("q") String q, @Param("verifiedOnly") int verifiedOnly,
                                  @Param("education") String education, @Param("occupation") String occupation,
                                  @Param("limit") int limit, @Param("offset") int offset);

    /** Elo 互动先验（设计 5.2）：被喜欢/配对加分，被隐藏/被举报减分，下限 600 */
    @Update("UPDATE fh_user SET elo_score = GREATEST(600, elo_score + #{delta}) WHERE id = #{id}")
    int adjustElo(@Param("id") long id, @Param("delta") int delta);

    @Update("UPDATE fh_user SET last_active_minutes = 0 WHERE id = #{id}")
    int touchActive(@Param("id") long id);

    @Update("UPDATE fh_user SET lat = #{lat}, lng = #{lng}, city = #{city} WHERE id = #{id}")
    int updateLocation(@Param("id") long id, @Param("lat") double lat,
                       @Param("lng") double lng, @Param("city") String city);

    /** 推荐候选集（设计 5.3 硬过滤，不排序），打分在 Java 侧完成 */
    @Select("SELECT " + CARD_COLUMNS + CARD_FILTER + " LIMIT #{limit}")
    List<UserCardVO> feedCandidates(@Param("me") long me, @Param("prefer") int prefer,
                                    @Param("myGender") int myGender, @Param("city") String city,
                                    @Param("lat") double lat, @Param("lng") double lng,
                                    @Param("ageMin") int ageMin, @Param("ageMax") int ageMax,
                                    @Param("maxDist") int maxDist,
                                    @Param("q") String q, @Param("verifiedOnly") int verifiedOnly,
                                    @Param("education") String education, @Param("occupation") String occupation,
                                    @Param("limit") int limit);

    // ---------- admin 运营统计 ----------

    @org.apache.ibatis.annotations.Select("SELECT COUNT(DISTINCT user_id) FROM fh_event "
            + "WHERE created_at >= CURDATE()")
    long countActiveToday();

    @org.apache.ibatis.annotations.Select("SELECT COUNT(*) FROM fh_user WHERE created_at >= CURDATE()")
    long countNewUsersToday();

    @Select("SELECT COUNT(*) FROM fh_user WHERE status = 1")
    long countAll();

    @Select("SELECT COUNT(*) FROM fh_match WHERE status = 1")
    long countMatches();

    @Select("SELECT COUNT(*) FROM fh_like WHERE action IN (1, 3) AND created_at >= CURDATE()")
    long countLikesTodayAll();

    @Select("SELECT COUNT(*) FROM fh_report")
    long countReports();
}
