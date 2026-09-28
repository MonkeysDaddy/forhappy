package com.forhappy.mapper;

import com.forhappy.entity.UserCardVO;
import java.util.List;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface LikeMapper {

    @Select("SELECT action FROM fh_like WHERE from_user = #{from} AND to_user = #{to}")
    Integer findAction(@Param("from") long from, @Param("to") long to);

    @Select("SELECT COUNT(*) FROM fh_like WHERE from_user = #{from} AND to_user = #{to}")
    int exists(@Param("from") long from, @Param("to") long to);

    @Insert("INSERT INTO fh_like (from_user, to_user, action, matched) "
            + "VALUES (#{from}, #{to}, #{action}, #{matched})")
    int insert(@Param("from") long from, @Param("to") long to,
               @Param("action") int action, @Param("matched") int matched);

    @Delete("DELETE FROM fh_like WHERE from_user = #{from} AND to_user = #{to}")
    int delete(@Param("from") long from, @Param("to") long to);

    @Select("SELECT COUNT(*) FROM fh_like WHERE from_user = #{from} "
            + "AND action IN (1, 3) AND created_at >= CURDATE()")
    int countLikesToday(@Param("from") long from);

    @Select("SELECT COUNT(*) FROM fh_like WHERE from_user = #{from} "
            + "AND action = 3 AND created_at >= CURDATE()")
    int countSuperToday(@Param("from") long from);

    /** 喜欢我的人：对方喜欢过我且未形成配对，我也未喜欢过/隐藏过对方 */
    @Select("""
            SELECT u.id, u.nickname, u.avatar_url, u.gender, u.city, u.occupation, u.bio,
              u.tags, u.verified, u.member_tier, u.last_active_minutes,
              (u.wechat IS NOT NULL AND u.wechat != '') AS has_wechat,
              TIMESTAMPDIFF(YEAR, u.birthday, CURDATE()) AS age,
              ROUND(ST_Distance_Sphere(POINT(u.lng, u.lat), POINT(#{lng}, #{lat})) / 1000, 1)
                AS distance_km
            FROM fh_user u
            JOIN fh_like l ON l.from_user = u.id AND l.action IN (1, 3) AND l.matched = 0
            WHERE l.to_user = #{me} AND u.status = 1
              AND NOT EXISTS (SELECT 1 FROM fh_like m2
                   WHERE m2.from_user = #{me} AND m2.to_user = u.id)
              AND NOT EXISTS (SELECT 1 FROM fh_block b
                   WHERE (b.blocker = #{me} AND b.blocked = u.id)
                      OR (b.blocker = u.id AND b.blocked = #{me}))
            ORDER BY l.created_at DESC
            LIMIT 100
            """)
    List<UserCardVO> likedMeCards(@Param("me") long me, @Param("lat") double lat,
                                  @Param("lng") double lng);
}
