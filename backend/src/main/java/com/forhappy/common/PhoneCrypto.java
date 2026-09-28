package com.forhappy.common;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;

/** 手机号 AES-GCM 加密存储（密钥由配置注入，改配置即废全部密文——需走数据迁移） */
@Component
public class PhoneCrypto {

    private final SecretKeySpec key;
    private final SecureRandom random = new SecureRandom();

    public PhoneCrypto(@Value("${forhappy.crypto.key:forhappy-dev-crypto-key-change-me}") String passphrase) {
        try {
            byte[] k = MessageDigest.getInstance("SHA-256")
                    .digest(passphrase.getBytes(StandardCharsets.UTF_8));
            this.key = new SecretKeySpec(k, "AES");
        } catch (Exception e) {
            throw new IllegalStateException("crypto init failed", e);
        }
    }

    /** 返回 base64(iv + ciphertext) */
    public String encrypt(String plain) {
        try {
            byte[] iv = new byte[12];
            random.nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(128, iv));
            byte[] ct = cipher.doFinal(plain.getBytes(StandardCharsets.UTF_8));
            byte[] out = new byte[iv.length + ct.length];
            System.arraycopy(iv, 0, out, 0, iv.length);
            System.arraycopy(ct, 0, out, iv.length, ct.length);
            return Base64.getEncoder().encodeToString(out);
        } catch (Exception e) {
            throw new IllegalStateException("encrypt failed", e);
        }
    }

    public String decrypt(String encoded) {
        try {
            byte[] all = Base64.getDecoder().decode(encoded);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key,
                    new GCMParameterSpec(128, all, 0, 12));
            return new String(cipher.doFinal(all, 12, all.length - 12),
                    StandardCharsets.UTF_8);
        } catch (Exception e) {
            return "";
        }
    }

    /** 138****1234 */
    public static String mask(String phone) {
        if (phone == null || phone.length() != 11) return "****";
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }
}
