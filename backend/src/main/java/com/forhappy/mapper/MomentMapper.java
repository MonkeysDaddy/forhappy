package com.forhappy.mapper;

import com.forhappy.entity.MomentVO;
import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface MomentMapper {

    @org.apache.ibatis.annotations.Insert("INSERT INTO fh_moment (user_id, caption, photos, status) "
            + "VALUES (#{userId}, #{caption}, CAST(#{photosJson} AS JSON), 0)")
    int insert(@Param("userId") long userId, @Param("caption") String caption,
               @Param("photosJson") String photosJson);

    @org.apache.ibatis.annotations.Select("SELECT COUNT(*) FROM fh_moment "
            + "WHERE user_id = #{userId} AND created_at >= CURDATE()")
    int countTodayByUser(@Param("userId") long userId);

    @Select("""
            SELECT m.id, m.caption, m.photos, m.likes_base, m.created_at,
              u.id AS user_id, u.nickname, u.avatar_url, u.gender, u.verified,
              u.member_tier, u.city,
              CASE WHEN u.hide_distance = 1 THEN NULL
                   ELSE ROUND(ST_Distance_Sphere(POINT(u.lng, u.lat), POINT(#{lng}, #{lat})) / 1000, 1)
                END AS distance_km,
              m.likes_base + (SELECT COUNT(*) FROM fh_moment_like ml
                WHERE ml.moment_id = m.id) AS like_count,
              (SELECT COUNT(*) FROM fh_moment_comment mc
                WHERE mc.moment_id = m.id) AS comment_count,
              EXISTS(SELECT 1 FROM fh_moment_like ml2
                WHERE ml2.moment_id = m.id AND ml2.user_id = #{me}) AS liked_by_me
            FROM fh_moment m
            JOIN fh_user u ON u.id = m.user_id
            WHERE m.status = 1 AND u.status = 1 AND u.city = #{city}
              AND NOT EXISTS (SELECT 1 FROM fh_block b
                   WHERE (b.blocker = #{me} AND b.blocked = u.id)
                      OR (b.blocker = u.id AND b.blocked = #{me}))
            ORDER BY distance_km ASC, m.created_at DESC
            LIMIT #{limit}
            """)
    List<MomentVO> feed(@Param("me") long me, @Param("city") String city,
                        @Param("lat") double lat, @Param("lng") double lng,
                        @Param("limit") int limit);

    @Select("""
            SELECT m.id, m.caption, m.photos, m.likes_base, m.created_at, m.user_id,
              m.likes_base + (SELECT COUNT(*) FROM fh_moment_like ml
                WHERE ml.moment_id = m.id) AS like_count,
              (SELECT COUNT(*) FROM fh_moment_comment mc
                WHERE mc.moment_id = m.id) AS comment_count,
              EXISTS(SELECT 1 FROM fh_moment_like ml2
                WHERE ml2.moment_id = m.id AND ml2.user_id = #{me}) AS liked_by_me
            FROM fh_moment m
            WHERE m.user_id = #{userId} AND m.status = 1
            ORDER BY m.created_at DESC
            """)
    List<MomentVO> listByUser(@Param("userId") long userId, @Param("me") long me);

    /** 管理端：待审动态 */
    @org.apache.ibatis.annotations.Select("""
            SELECT m.id, m.caption, m.photos, m.created_at AS createdAt, m.user_id AS userId,
              u.nickname AS nickname
            FROM fh_moment m JOIN fh_user u ON u.id = m.user_id
            WHERE m.status = 0
            ORDER BY m.id ASC
            LIMIT 50
            """)
    java.util.List<Map<String, Object>> pending();

    @org.apache.ibatis.annotations.Update("UPDATE fh_moment SET status = #{status} WHERE id = #{id}")
    int setStatus(@Param("id") long id, @Param("status") int status);

    @org.apache.ibatis.annotations.Select("SELECT user_id FROM fh_moment WHERE id = #{id}")
    Long findUserIdById(@Param("id") long id);
}