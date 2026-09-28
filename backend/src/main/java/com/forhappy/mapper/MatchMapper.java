package com.forhappy.mapper;

import com.forhappy.entity.UserCardVO;
import java.util.List;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface MatchMapper {

    @Select("SELECT id FROM fh_match WHERE user_lo = #{lo} AND user_hi = #{hi} AND status = 1")
    Long findActive(@Param("lo") long lo, @Param("hi") long hi);

    @Insert("INSERT INTO fh_match (user_lo, user_hi, common_tags) "
            + "VALUES (#{lo}, #{hi}, #{commonTags})")
    int insert(@Param("lo") long lo, @Param("hi") long hi,
               @Param("commonTags") String commonTags);

    @Update("UPDATE fh_match SET status = 2 WHERE id = #{id}")
    int deactivate(@Param("id") long id);

    @Select("""
            SELECT u.id, u.nickname, u.avatar_url, u.gender, u.city, u.occupation, u.bio, u.tags,
              u.verified, u.member_tier, u.last_active_minutes,
              (u.wechat IS NOT NULL AND u.wechat != '') AS has_wechat,
              TIMESTAMPDIFF(YEAR, u.birthday, CURDATE()) AS age,
              ROUND(ST_Distance_Sphere(POINT(u.lng, u.lat), POINT(#{lng}, #{lat})) / 1000, 1)
                AS distance_km,
              1 AS liked
            FROM fh_match m
            JOIN fh_user u ON u.id = CASE WHEN m.user_lo = #{me} THEN m.user_hi ELSE m.user_lo END
            WHERE m.status = 1 AND (m.user_lo = #{me} OR m.user_hi = #{me})
            ORDER BY m.created_at DESC
            """)
    List<UserCardVO> listForUser(@Param("me") long me, @Param("lat") double lat,
                                 @Param("lng") double lng);
}
