package com.forhappy.common;

import java.util.regex.Pattern;

/**
 * 内容审核（设计 6.1 演示版）：联系方式正则拦截。
 * 真实工程接入云厂商内容安全 API + 自定义敏感词库，本类保留为前置兜底。
 */
public final class ContentFilter {

    /** 手机号 / 微信/QQ 引流变体 / 长数字串 */
    private static final Pattern CONTACT = Pattern.compile(
            "1[3-9]\\d{9}|(?i)(微信|加微|加V|vx|VX|weixin|扣扣|QQ)\\s*[:：号]?\\s*[a-zA-Z0-9_-]{4,}|\\d{7,11}");

    private ContentFilter() {}

    /** 昵称/简介是否命中联系方式（设计 4.2：不允许纯联系方式） */
    public static boolean hasContactInfo(String text) {
        if (text == null || text.isBlank()) {
            return false;
        }
        return CONTACT.matcher(text).find();
    }

    /** 校验昵称，违规抛业务异常 */
    public static void checkNickname(String nickname) {
        if (nickname == null || nickname.trim().length() < 2) {
            throw new BizException(400, "昵称至少 2 个字符");
        }
        if (hasContactInfo(nickname)) {
            throw new BizException(400, "昵称不能包含手机号/微信号等联系方式");
        }
    }

    /** 校验简介（选填，但不得含联系方式引流） */
    public static void checkBio(String bio) {
        if (bio != null && hasContactInfo(bio)) {
            throw new BizException(400, "简介不能包含手机号/微信号等联系方式");
        }
    }
}
