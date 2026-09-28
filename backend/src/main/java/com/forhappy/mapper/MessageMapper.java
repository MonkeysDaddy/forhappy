package com.forhappy.mapper;

import com.forhappy.entity.Message;
import java.util.List;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface MessageMapper {

    @Insert("INSERT INTO fh_message (conv_id, from_user, type, content) "
            + "VALUES (#{convId}, #{fromUser}, #{type}, #{content})")
    int insert(Message message);

    @Select("SELECT * FROM fh_message WHERE conv_id = #{convId} "
            + "ORDER BY created_at DESC LIMIT #{limit}")
    List<Message> latest(@Param("convId") long convId, @Param("limit") int limit);

    /** 已读回执：把对方发来的消息标记为已读，返回受影响条数 */
    @Update("UPDATE fh_message SET read_at = NOW() WHERE conv_id = #{convId} "
            + "AND from_user != #{reader} AND read_at IS NULL")
    int markRead(@Param("convId") long convId, @Param("reader") long reader);

    @Select("SELECT COUNT(*) FROM fh_message WHERE conv_id = #{convId} "
            + "AND from_user != #{reader} AND read_at IS NULL")
    int unreadCount(@Param("convId") long convId, @Param("reader") long reader);
}
