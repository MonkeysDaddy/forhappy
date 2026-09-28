package com.forhappy.mapper;

import com.forhappy.entity.UserCardVO;
import java.util.List;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface BlockMapper {

    @Select("SELECT COUNT(*) FROM fh_block WHERE blocker = #{blocker} AND blocked = #{blocked}")
    int exists(@Param("blocker") long blocker, @Param("blocked") long blocked);

    @Insert("INSERT IGNORE INTO fh_block (blocker, blocked) VALUES (#{blocker}, #{blocked})")
    int insert(@Param("blocker") long blocker, @Param("blocked") long blocked);

    @Delete("DELETE FROM fh_block WHERE blocker = #{blocker} AND blocked = #{blocked}")
    int delete(@Param("blocker") long blocker, @Param("blocked") long blocked);

    @Select("SELECT blocked FROM fh_block WHERE blocker = #{blocker}")
    List<Long> listFor(@Param("blocker") long blocker);

    /** 黑名单列表（带昵称/头像，供黑名单管理页展示） */
    @Select("""
            SELECT u.id, u.nickname, u.avatar_url, u.gender, u.city
            FROM fh_block b JOIN fh_user u ON u.id = b.blocked
            WHERE b.blocker = #{blocker}
            ORDER BY b.created_at DESC
            """)
    List<UserCardVO> listCardsFor(@Param("blocker") long blocker);
}
