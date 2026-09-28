package com.forhappy.mapper;

import com.forhappy.entity.Photo;
import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface PhotoMapper {

    @Select("SELECT * FROM fh_photo WHERE user_id = #{userId} AND review_status = 1 "
            + "ORDER BY sort_order")
    List<Photo> listByUser(@Param("userId") long userId);

    @Insert("INSERT INTO fh_photo (user_id, url, sort_order, is_avatar) "
            + "VALUES (#{userId}, #{url}, #{sortOrder}, #{isAvatar})")
    int insert(Photo photo);

    @Select("SELECT * FROM fh_photo WHERE id = #{id}")
    Photo findById(@Param("id") long id);

    @Delete("DELETE FROM fh_photo WHERE id = #{id} AND user_id = #{userId}")
    int delete(@Param("id") long id, @Param("userId") long userId);

    @Update("UPDATE fh_photo SET is_avatar = 0 WHERE user_id = #{userId}")
    int clearAvatar(@Param("userId") long userId);

    @Update("UPDATE fh_photo SET is_avatar = 1 WHERE id = #{id} AND user_id = #{userId}")
    int markAvatar(@Param("id") long id, @Param("userId") long userId);

    /** 管理端：待审照片 */
    @org.apache.ibatis.annotations.Select("SELECT p.id, p.url, p.is_avatar AS isAvatar,"
            + " p.user_id AS userId, u.nickname AS nickname"
            + " FROM fh_photo p JOIN fh_user u ON u.id = p.user_id"
            + " WHERE p.review_status = 0 ORDER BY p.id ASC LIMIT 50")
    java.util.List<Map<String, Object>> pending();

    @org.apache.ibatis.annotations.Update("UPDATE fh_photo SET review_status = #{status} WHERE id = #{id}")
    int setReviewStatus(@Param("id") long id, @Param("status") int status);


    /** 管理端：用户全部照片（含审核状态） */
    @org.apache.ibatis.annotations.Select("SELECT id, url, is_avatar AS isAvatar, "
            + "review_status AS reviewStatus, sort_order AS sortOrder"
            + " FROM fh_photo WHERE user_id = #{userId} ORDER BY sort_order, id")
    java.util.List<Map<String, Object>> adminPhotos(@Param("userId") long userId);

    /** 本人视角：全部照片（含待审/驳回，供照片墙显示审核状态） */
    @org.apache.ibatis.annotations.Select("SELECT * FROM fh_photo WHERE user_id = #{userId} ORDER BY sort_order, id")
    java.util.List<com.forhappy.entity.Photo> listMineByUser(@Param("userId") long userId);
}