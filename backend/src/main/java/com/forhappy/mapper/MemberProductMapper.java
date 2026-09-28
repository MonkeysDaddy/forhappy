package com.forhappy.mapper;

import com.forhappy.entity.MemberProduct;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface MemberProductMapper {

    @Select("SELECT * FROM fh_member_product WHERE status = 1 ORDER BY sort_order")
    List<MemberProduct> listOnShelf();

    @Select("SELECT * FROM fh_member_product WHERE id = #{id} AND status = 1")
    MemberProduct findById(@Param("id") long id);

    // ---------- admin 后台 ----------

    @Select("SELECT * FROM fh_member_product ORDER BY sort_order")
    List<MemberProduct> listAll();

    /** 部分字段更新（null 跳过）；改价即时生效于新订单（设计 4.9） */
    @Update("""
            <script>
            UPDATE fh_member_product
            <set>
              <if test="priceCents != null">price_cents = #{priceCents},</if>
              <if test="originalCents != null">original_cents = #{originalCents},</if>
              <if test="firstPriceCents != null">first_price_cents = #{firstPriceCents},</if>
              <if test="status != null">status = #{status},</if>
              <if test="sortOrder != null">sort_order = #{sortOrder},</if>
            </set>
            WHERE id = #{id}
            </script>
            """)
    int adminUpdate(@Param("id") long id, @Param("priceCents") Integer priceCents,
                    @Param("originalCents") Integer originalCents,
                    @Param("firstPriceCents") Integer firstPriceCents,
                    @Param("status") Integer status, @Param("sortOrder") Integer sortOrder);

    @org.apache.ibatis.annotations.Insert("INSERT INTO fh_member_product "
            + "(tier, duration_days, duration_label, price_cents, original_cents, first_price_cents, badge, sort_order) "
            + "VALUES (#{tier}, #{durationDays}, #{durationLabel}, #{priceCents}, #{originalCents}, #{firstPriceCents}, #{badge}, #{sortOrder})")
    @org.apache.ibatis.annotations.Options(useGeneratedKeys = true, keyProperty = "id")
    int adminCreate(@Param("tier") int tier, @Param("durationDays") int durationDays,
                    @Param("durationLabel") String durationLabel,
                    @Param("priceCents") int priceCents,
                    @Param("originalCents") Integer originalCents,
                    @Param("firstPriceCents") Integer firstPriceCents,
                    @Param("badge") String badge, @Param("sortOrder") int sortOrder);

    @org.apache.ibatis.annotations.Delete("DELETE FROM fh_member_product WHERE id = #{id}")
    int adminDelete(@Param("id") long id);

    @org.apache.ibatis.annotations.Select("SELECT COUNT(*) FROM fh_member_order WHERE product_id = #{productId}")
    long countOrdersOfProduct2(@Param("productId") long productId);
}
