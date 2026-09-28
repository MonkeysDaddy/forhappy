package com.forhappy.mapper;

import com.forhappy.entity.MomentCommentVO;
import java.util.List;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface MomentCommentMapper {

    @Select("""
            SELECT c.id, c.moment_id, c.user_id, u.nickname AS author, c.content, c.created_at
            FROM fh_moment_comment c
            JOIN fh_user u ON u.id = c.user_id
            WHERE c.moment_id = #{momentId}
            ORDER BY c.created_at ASC
            """)
    List<MomentCommentVO> list(@Param("momentId") long momentId);

    @Insert("INSERT INTO fh_moment_comment (moment_id, user_id, content) "
            + "VALUES (#{momentId}, #{userId}, #{content})")
    int insert(@Param("momentId") long momentId, @Param("userId") long userId,
               @Param("content") String content);
}
