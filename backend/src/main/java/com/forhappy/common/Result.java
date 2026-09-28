package com.forhappy.common;

import lombok.Data;

/** 统一响应包：{code, msg, data} */
@Data
public class Result<T> {

    public static final int OK = 0;
    public static final int QUOTA_EXCEEDED = 4001;
    public static final int AI_REPLY_LIMIT = 4002;
    public static final int NOT_MEMBER = 4003;

    private int code;
    private String msg;
    private T data;

    public static <T> Result<T> ok(T data) {
        Result<T> r = new Result<>();
        r.code = OK;
        r.msg = "ok";
        r.data = data;
        return r;
    }

    public static <T> Result<T> ok() {
        return ok(null);
    }

    public static <T> Result<T> fail(int code, String msg) {
        Result<T> r = new Result<>();
        r.code = code;
        r.msg = msg;
        return r;
    }

    public static <T> Result<T> fail(String msg) {
        return fail(500, msg);
    }
}
