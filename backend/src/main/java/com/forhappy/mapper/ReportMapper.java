package com.forhappy.mapper;

import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface ReportMapper {

    @Insert("INSERT INTO fh_report (reporter, reported, category, description) "
            + "VALUES (#{reporter}, #{reported}, #{category}, #{description})")
    int insert(@Param("reporter") long reporter, @Param("reported") long reported,
               @Param("category") int category, @Param("description") String description);
}
