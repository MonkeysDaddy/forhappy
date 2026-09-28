package com.forhappy.admin;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** 管理密钥持有（旧 AdminController 与新控制器共用） */
@Component
public class AdminKeyHolder {

    @Value("${forhappy.admin.key:forhappy-admin}")
    private String adminKey;

    public String adminKey() {
        return adminKey;
    }
}
