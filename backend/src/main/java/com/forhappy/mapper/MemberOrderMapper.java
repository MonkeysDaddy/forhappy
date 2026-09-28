package com.forhappy.mapper;

import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.Map;

@Mapper
public interface MemberOrderMapper {

    @Insert("INSERT INTO fh_member_order (order_no, user_id, product_id, amount_cents, channel) "
            + "VALUES (#{orderNo}, #{userId}, #{productId}, #{amountCents}, #{channel})")
    int insert(@Param("orderNo") String orderNo, @Param("userId") long userId,
               @Param("productId") long productId, @Param("amountCents") int amountCents,
               @Param("channel") int channel);

    @Select("SELECT * FROM fh_member_order WHERE order_no = #{orderNo}")
    Map<String, Object> findByNo(@Param("orderNo") String orderNo);

    @Update("UPDATE fh_member_order SET status = 1, paid_at = NOW() "
            + "WHERE order_no = #{orderNo} AND status = 0")
    int markPaid(@Param("orderNo") String orderNo);

    /** 已支付订单数与流水（运营看板） */
    @Select("SELECT COUNT(*) AS cnt, COALESCE(SUM(amount_cents), 0) AS amount "
            + "FROM fh_member_order WHERE status = 1")
    Map<String, Object> sumRevenue();

    @org.apache.ibatis.annotations.Update("UPDATE fh_member_order SET status = 3 "
            + "WHERE order_no = #{orderNo} AND status = 1")
    int markRefund(@Param("orderNo") String orderNo);
}