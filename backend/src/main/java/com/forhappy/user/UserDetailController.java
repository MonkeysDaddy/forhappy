package com.forhappy.user;

import com.forhappy.common.BizException;
import com.forhappy.common.Result;
import com.forhappy.common.UserContext;
import com.forhappy.entity.MomentVO;
import com.forhappy.entity.Photo;
import com.forhappy.entity.User;
import com.forhappy.mapper.MatchMapper;
import com.forhappy.mapper.MomentMapper;
import com.forhappy.mapper.PhotoMapper;
import com.forhappy.mapper.UserMapper;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 他人资料详情：全量字段 + 动态；联系方式仅配对后可见（产品红线） */
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserDetailController {

    private final UserMapper userMapper;
    private final PhotoMapper photoMapper;
    private final MomentMapper momentMapper;
    private final MatchMapper matchMapper;

    @GetMapping("/{id}")
    public Result<Map<String, Object>> detail(@PathVariable long id) {
        long me = UserContext.get();
        User u = userMapper.findById(id);
        if (u == null) {
            throw new BizException(404, "用户不存在");
        }
        long lo = Math.min(me, id);
        long hi = Math.max(me, id);
        boolean matched = matchMapper.findActive(lo, hi) != null;

        Map<String, Object> userMap = new HashMap<>();
        userMap.put("id", u.getId());
        userMap.put("nickname", u.getNickname());
        userMap.put("avatarUrl", u.getAvatarUrl());
        userMap.put("gender", u.getGender());
        userMap.put("city", u.getCity());
        userMap.put("heightCm", u.getHeightCm());
        userMap.put("weightKg", u.getWeightKg());
        userMap.put("education", u.getEducation());
        userMap.put("occupation", u.getOccupation());
        userMap.put("income", u.getIncome());
        userMap.put("bio", u.getBio());
        userMap.put("tags", u.getTags());
        userMap.put("verified", u.getVerified());
        userMap.put("memberTier", u.getMemberTier());
        userMap.put("lastActiveMinutes", u.getLastActiveMinutes());
        // 联系方式：未配对时不下发
        userMap.put("wechat", matched ? u.getWechat() : null);
        userMap.put("instagram", matched ? u.getInstagram() : null);
        userMap.put("facebook", matched ? u.getFacebook() : null);
        if (u.getBirthday() != null) {
            userMap.put("age", java.time.Period.between(
                    u.getBirthday(), java.time.LocalDate.now()).getYears());
        }

        List<Photo> photos = photoMapper.listByUser(id);
        List<MomentVO> moments = momentMapper.listByUser(id, me);

        // 距离（km，Haversine）；对方开启隐藏距离则不下发
        Double distanceKm = null;
        User meUser = userMapper.findById(me);
        if (!(u.getHideDistance() != null && u.getHideDistance() == 1)
                && meUser.getLat() != null && u.getLat() != null) {
            distanceKm = haversineKm(meUser.getLat(), meUser.getLng(),
                    u.getLat(), u.getLng());
        }

        Map<String, Object> data = new HashMap<>();
        data.put("user", userMap);
        data.put("photos", photos);
        data.put("moments", moments);
        data.put("matched", matched);
        data.put("distanceKm", distanceKm);
        // 社交账号展示（社交展示卡权益）：对方订阅有效才下发
        if (u.getSocialExpireAt() != null
                && u.getSocialExpireAt().isAfter(java.time.LocalDateTime.now())
                && u.getSocialShowcase() != null && !u.getSocialShowcase().isBlank()) {
            data.put("socialShowcase",
                    com.forhappy.user.SocialShowcaseController.parseShowcase(
                            u.getSocialShowcase()));
        }
        return Result.ok(data);
    }

    public static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
        double r = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return Math.round(r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)) * 10.0) / 10.0;
    }
}
