package com.forhappy.moment;

import com.forhappy.common.CityGeo;
import com.forhappy.common.Result;
import com.forhappy.common.UserContext;
import com.forhappy.entity.MomentCommentVO;
import com.forhappy.entity.MomentVO;
import com.forhappy.entity.User;
import com.forhappy.mapper.MomentCommentMapper;
import com.forhappy.mapper.MomentLikeMapper;
import com.forhappy.mapper.MomentMapper;
import com.forhappy.mapper.UserMapper;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/moments")
@RequiredArgsConstructor
public class MomentController {

    private final MomentMapper momentMapper;
    private final com.forhappy.common.SensitiveWordStore sensitiveWordStore;
    private final com.forhappy.mapper.AdminManageMapper violationMapper;
    private final MomentLikeMapper momentLikeMapper;
    private final MomentCommentMapper momentCommentMapper;
    private final UserMapper userMapper;

    @GetMapping
    public Result<List<MomentVO>> feed(
            @RequestParam(required = false) String city,
            @RequestParam(defaultValue = "50") int limit) {
        long uid = UserContext.get();
        User me = userMapper.findById(uid);
        String targetCity = (city == null || city.isBlank())
                ? me.getCity() != null && !me.getCity().isBlank() ? me.getCity() : "杭州"
                : city;
        return Result.ok(momentMapper.feed(uid, targetCity,
                me.getLat() != null ? me.getLat() : CityGeo.lat(targetCity),
                me.getLng() != null ? me.getLng() : CityGeo.lng(targetCity),
                limit));
    }

    /** 发布动态：文案过联系方式正则；照片必须是本站上传的 /files/ 路径（先传后发） */
    @PostMapping
    public Result<Map<String, Object>> publish(@RequestBody Map<String, Object> body) {
        long uid = UserContext.get();
        String caption = body.get("caption") == null ? "" : body.get("caption").toString().trim();
        if (caption.isEmpty() && !(body.get("photos") instanceof java.util.List<?> list && !list.isEmpty())) {
            throw new com.forhappy.common.BizException(400, "写点什么或配一张照片吧");
        }
        if (caption.length() > 500) {
            throw new com.forhappy.common.BizException(400, "动态最多 500 字");
        }
        com.forhappy.common.ContentFilter.checkBio(caption);
        String hitWord = sensitiveWordStore.hit(caption);
        if (hitWord != null) {
            violationMapper.insertViolation(uid, "moment",
                    caption.length() > 500 ? caption.substring(0, 500) : caption, hitWord);
            throw new com.forhappy.common.BizException(400, "动态包含违规内容，已被拦截");
        }
        java.util.List<String> photos = new java.util.ArrayList<>();
        if (body.get("photos") instanceof java.util.List<?> list) {
            for (Object o : list) {
                String url = o == null ? "" : o.toString();
                if (!url.startsWith("/files/")) {
                    throw new com.forhappy.common.BizException(400, "照片必须先上传");
                }
                photos.add(url);
                if (photos.size() >= 6) break;
            }
        }
        if (momentMapper.countTodayByUser(uid) >= 10) {
            throw new com.forhappy.common.BizException(Result.QUOTA_EXCEEDED, "今天发太多啦，明天再来分享");
        }
        String photosJson;
        try {
            photosJson = new com.fasterxml.jackson.databind.ObjectMapper().writeValueAsString(photos);
        } catch (Exception e) {
            throw new com.forhappy.common.BizException(500, "发布失败");
        }
        momentMapper.insert(uid, caption, photosJson);
        userMapper.adjustElo(uid, 5); // 内容贡献 +5（互动先验）
        Map<String, Object> data = new HashMap<>();
        data.put("published", true);
        return Result.ok(data);
    }

    @PostMapping("/{id}/like")
    public Result<Map<String, Object>> toggleLike(@PathVariable long id) {
        long uid = UserContext.get();
        boolean liked = momentLikeMapper.exists(uid, id) > 0;
        if (liked) {
            momentLikeMapper.delete(uid, id);
        } else {
            momentLikeMapper.insert(uid, id);
        }
        Map<String, Object> data = new HashMap<>();
        data.put("liked", !liked);
        return Result.ok(data);
    }

    @PostMapping("/{id}/comments")
    public Result<Void> comment(@PathVariable long id,
                                @RequestBody Map<String, String> body) {
        momentCommentMapper.insert(id, UserContext.get(),
                body.getOrDefault("content", "").trim());
        return Result.ok();
    }

    @GetMapping("/{id}/comments")
    public Result<List<MomentCommentVO>> comments(@PathVariable long id) {
        return Result.ok(momentCommentMapper.list(id));
    }
}
