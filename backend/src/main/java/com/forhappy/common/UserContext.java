package com.forhappy.common;

/** 当前登录用户（ThreadLocal） */
public final class UserContext {

    private static final ThreadLocal<Long> UID = new ThreadLocal<>();

    private UserContext() {}

    public static void set(long userId) {
        UID.set(userId);
    }

    public static long get() {
        Long v = UID.get();
        if (v == null) {
            throw new BizException(401, "未登录");
        }
        return v;
    }

    public static void clear() {
        UID.remove();
    }
}
