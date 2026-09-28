package com.forhappy.mapper;

import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface MomentLikeMapper {

    @Select("SELECT COUNT(*) FROM fh_moment_like WHERE user_id = #{userId} "
            + "AND moment_id = #{momentId}")
    int exists(@Param("userId") long userId, @Param("momentId") long momentId);

    @Insert("INSERT IGNORE INTO fh_moment_like (user_id, moment_id) "
            + "VALUES (#{userId}, #{momentId})")
    int insert(@Param("userId") long userId, @Param("momentId") long momentId);

    @Delete("DELETE FROM fh_moment_like WHERE user_id = #{userId} "
            + "AND moment_id = #{momentId}")
    int delete(@Param("userId") long userId, @Param("momentId") long momentId);
}
