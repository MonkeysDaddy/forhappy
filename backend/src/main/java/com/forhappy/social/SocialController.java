package com.forhappy.social;

import com.forhappy.common.CityGeo;
import com.forhappy.common.Result;
import com.forhappy.common.UserContext;
import com.forhappy.entity.User;
import com.forhappy.entity.UserCardVO;
import com.forhappy.mapper.BlockMapper;
import com.forhappy.mapper.LikeMapper;
import com.forhappy.mapper.ReportMapper;
import com.forhappy.mapper.UserMapper;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
public class SocialController {

    private final SocialService socialService;
    private final LikeMapper likeMapper;
    private final BlockMapper blockMapper;
    private final ReportMapper reportMapper;
    private final UserMapper userMapper;

    @PostMapping("/api/v1/likes")
    public Result<Map<String, Object>> like(@RequestBody Map<String, Object> body) {
        long to = ((Number) body.get("toUser")).longValue();
        int action = body.containsKey("action")
                ? ((Number) body.get("action")).intValue() : 1;
        return Result.ok(socialService.like(UserContext.get(), to, action));
    }

    @DeleteMapping("/api/v1/likes/{toUser}")
    public Result<Map<String, Object>> undoLike(@PathVariable long toUser) {
        return Result.ok(socialService.undoLike(UserContext.get(), toUser));
    }

    /** 喜欢我的人：非会员仅返回模糊墙（blurred=true，客户端模糊头像），会员返回完整列表（设计 4.8/9.3） */
    @GetMapping("/api/v1/likes/me")
    public Result<Map<String, Object>> likedMe() {
        long uid = UserContext.get();
        User me = userMapper.findById(uid);
        String city = me.getCity() != null && !me.getCity().isBlank() ? me.getCity() : "杭州";
        List<UserCardVO> items = likeMapper.likedMeCards(uid,
                me.getLat() != null ? me.getLat() : CityGeo.lat(city),
                me.getLng() != null ? me.getLng() : CityGeo.lng(city));
        boolean member = me.getMemberTier() != null && me.getMemberTier() > 0;
        Map<String, Object> data = new HashMap<>();
        data.put("blurred", !member);
        data.put("count", items.size());
        data.put("items", items);
        return Result.ok(data);
    }

    @PostMapping("/api/v1/matches/{matchId}/unmatch")
    public Result<Void> unmatch(@PathVariable long matchId) {
        socialService.unmatch(UserContext.get(), matchId);
        return Result.ok();
    }

    @PostMapping("/api/v1/blocks")
    public Result<Void> block(@RequestBody Map<String, Object> body) {
        blockMapper.insert(UserContext.get(), ((Number) body.get("blockedUser")).longValue());
        return Result.ok();
    }

    @DeleteMapping("/api/v1/blocks/{blockedUser}")
    public Result<Void> unblock(@PathVariable long blockedUser) {
        blockMapper.delete(UserContext.get(), blockedUser);
        return Result.ok();
    }

    @GetMapping("/api/v1/blocks")
    public Result<List<UserCardVO>> blocks() {
        return Result.ok(blockMapper.listCardsFor(UserContext.get()));
    }

    @PostMapping("/api/v1/reports")
    public Result<Void> report(@RequestBody Map<String, Object> body) {
        long reported = ((Number) body.get("reportedUser")).longValue();
        reportMapper.insert(
                UserContext.get(),
                reported,
                ((Number) body.getOrDefault("category", 6)).intValue(),
                String.valueOf(body.getOrDefault("description", "")));
        userMapper.adjustElo(reported, -30); // 被举报降权（设计 5.2 惩罚项）
        return Result.ok();
    }
}
