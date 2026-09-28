package com.forhappy.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/** 埋点事件（设计 10.4 最小集） */
@Mapper
public interface EventMapper {

    @Insert("INSERT INTO fh_event (user_id, event, props) VALUES "
            + "(#{userId}, #{event}, #{props})")
    int insert(@Param("userId") long userId, @Param("event") String event,
               @Param("props") String props);

    /** 事件计数（运营统计用） */
    @Select("SELECT event, COUNT(*) AS cnt FROM fh_event "
            + "WHERE created_at >= CURDATE() GROUP BY event")
    List<Map<String, Object>> countToday();
}
