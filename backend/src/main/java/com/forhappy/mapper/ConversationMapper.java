package com.forhappy.mapper;

import com.forhappy.entity.ConversationVO;
import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface ConversationMapper {

    @Select("SELECT id FROM fh_conversation WHERE match_id = #{matchId}")
    Long findByMatch(@Param("matchId") long matchId);

    @org.apache.ibatis.annotations.Select("SELECT user_a FROM fh_conversation WHERE id = #{id} "
            + "UNION ALL SELECT user_b FROM fh_conversation WHERE id = #{id}")
    java.util.List<Long> membersOf(@Param("id") long id);

    @Insert("INSERT INTO fh_conversation (match_id, user_a, user_b, last_message) "
            + "VALUES (#{matchId}, #{userA}, #{userB}, #{lastMessage})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(com.forhappy.entity.ConversationEntity e);

    @Select("SELECT id FROM fh_conversation WHERE id = #{id} AND status = 1 "
            + "AND (user_a = #{me} OR user_b = #{me})")
    Long findMine(@Param("id") long id, @Param("me") long me);

    /** 会话对端用户 id（校验归属） */
    @Select("SELECT CASE WHEN user_a = #{me} THEN user_b ELSE user_a END "
            + "FROM fh_conversation WHERE id = #{id} AND status = 1 "
            + "AND (user_a = #{me} OR user_b = #{me})")
    Long findPeer(@Param("id") long id, @Param("me") long me);

    @Select("""
            SELECT c.id, c.match_id, c.last_message, c.updated_at,
              CASE WHEN c.user_a = #{me} THEN c.a_unread ELSE c.b_unread END AS unread,
              CASE WHEN c.user_a = #{me} THEN c.user_b ELSE c.user_a END AS peer_id,
              u.nickname AS peer_nickname, u.avatar_url AS peer_avatar_url,
              u.gender AS peer_gender, u.verified AS peer_verified
            FROM fh_conversation c
            JOIN fh_user u ON u.id = CASE WHEN c.user_a = #{me} THEN c.user_b ELSE c.user_a END
            WHERE (c.user_a = #{me} OR c.user_b = #{me}) AND c.status = 1
            ORDER BY c.updated_at DESC
            """)
    List<ConversationVO> listForUser(@Param("me") long me);

    @Update("""
            UPDATE fh_conversation SET last_message = #{content},
              a_unread = CASE WHEN user_a = #{from} THEN a_unread ELSE a_unread + 1 END,
              b_unread = CASE WHEN user_b = #{from} THEN b_unread ELSE b_unread + 1 END
            WHERE id = #{id}
            """)
    int appendMessage(@Param("id") long id, @Param("from") long from,
                      @Param("content") String content);

    @Update("""
            UPDATE fh_conversation SET
              a_unread = CASE WHEN user_a = #{me} THEN 0 ELSE a_unread END,
              b_unread = CASE WHEN user_b = #{me} THEN 0 ELSE b_unread END
            WHERE id = #{id}
            """)
    int clearUnread(@Param("id") long id, @Param("me") long me);

    @Update("UPDATE fh_conversation SET status = 2 WHERE match_id = #{matchId}")
    int deactivateByMatch(@Param("matchId") long matchId);

    @org.apache.ibatis.annotations.Select("SELECT * FROM fh_conversation "
            + "WHERE (user_a = #{a} AND user_b = #{b}) OR (user_a = #{b} AND user_b = #{a}) "
            + "ORDER BY id DESC LIMIT 1")
    Map<String, Object> findBetween(@Param("a") long a, @Param("b") long b);

    /** 管理端：用户参与的全部会话（取证用） */
    @org.apache.ibatis.annotations.Select("SELECT c.id, c.user_a AS userA, c.user_b AS userB,"
            + " c.last_message AS lastMessage, c.created_at AS createdAt"
            + " FROM fh_conversation c WHERE c.user_a = #{userId} OR c.user_b = #{userId}"
            + " ORDER BY c.id DESC LIMIT 20")
    java.util.List<Map<String, Object>> listByUserAdmin(@Param("userId") long userId);
}