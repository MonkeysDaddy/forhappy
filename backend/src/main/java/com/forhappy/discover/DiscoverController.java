package com.forhappy.discover;

import com.forhappy.common.CityGeo;
import com.forhappy.common.Result;
import com.forhappy.common.UserContext;
import com.forhappy.entity.User;
import com.forhappy.entity.UserCardVO;
import com.forhappy.mapper.MatchMapper;
import com.forhappy.mapper.UserMapper;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/discover")
@RequiredArgsConstructor
public class DiscoverController {

    private final UserMapper userMapper;
    private final MatchMapper matchMapper;
    private final RecommendService recommendService;

    @GetMapping("/feed")
    public Result<Map<String, Object>> feed(
            @RequestParam(defaultValue = "distance") String sort,
            @RequestParam(required = false) String city,
            @RequestParam(defaultValue = "20") int ageMin,
            @RequestParam(defaultValue = "32") int ageMax,
            @RequestParam(defaultValue = "0") int maxDist,
            @RequestParam(defaultValue = "") String q,
            @RequestParam(defaultValue = "false") boolean verifiedOnly,
            @RequestParam(required = false) String education,
            @RequestParam(required = false) String occupation,
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(defaultValue = "0") int cursor) {
        long uid = UserContext.get();
        User me = userMapper.findById(uid);
        // 权益门槛（设计 4.8）：只看已认证=VIP；学历/职业高级筛选=SVIP（无权者静默忽略参数）
        int myTier = me != null && me.getMemberTier() != null ? me.getMemberTier() : 0;
        final String keyword = q == null ? "" : q.trim();
        final int verifiedFlag = verifiedOnly && myTier > 0 ? 1 : 0;
        final String eduFilter = myTier >= 2 && education != null ? education : "";
        final String occuFilter = myTier >= 2 && occupation != null ? occupation.trim() : "";
        // 未完成引导的用户（prefer/gender 为空）兜底：默认看异性，避免 SQL 匹配不到任何人
        int prefer = me.getPreferGender() != null && me.getPreferGender() > 0
                ? me.getPreferGender()
                : me.getGender() != null && me.getGender() > 0 ? 3 - me.getGender() : 3;
        int myGender = me.getGender() != null && me.getGender() > 0 ? me.getGender() : 3;
        String targetCity = (city == null || city.isBlank())
                ? me.getCity() != null && !me.getCity().isBlank() ? me.getCity() : "杭州"
                : city;
        // 坐标兜底：未上报定位的用户按目标城市中心计算距离
        double lat = me.getLat() != null ? me.getLat() : CityGeo.lat(targetCity);
        double lng = me.getLng() != null ? me.getLng() : CityGeo.lng(targetCity);
        // 游标分页（设计 9.3）：distance 排序下用 OFFSET 游标，切筛选/排序时客户端重置为 0
        limit = Math.clamp(limit, 1, 50);
        int offset = Math.max(cursor, 0);
        List<UserCardVO> items;
        if ("reco".equals(sort)) {
            // 推荐优先（设计 5.1-5.3）：硬过滤取候选集 → Java 打分（距离/兴趣/活跃/Elo/新用户加权）
            // → 多样性注入 → 确定性排序后按游标切片
            List<UserCardVO> ranked = recommendService.rank(me, userMapper.feedCandidates(
                    uid, prefer, myGender, targetCity, lat, lng,
                    ageMin, ageMax, maxDist, keyword, verifiedFlag, eduFilter, occuFilter, 300));
            items = ranked.subList(offset, Math.min(offset + limit, ranked.size()));
        } else if ("active".equals(sort)) {
            items = userMapper.feedByActive(uid, prefer, myGender, targetCity, lat, lng,
                    ageMin, ageMax, maxDist, keyword, verifiedFlag, eduFilter, occuFilter,
                    limit, offset);
        } else {
            items = userMapper.feedByDistance(uid, prefer, myGender, targetCity, lat, lng,
                    ageMin, ageMax, maxDist, keyword, verifiedFlag, eduFilter, occuFilter,
                    limit, offset);
        }
        Map<String, Object> data = new HashMap<>();
        data.put("items", items);
        // -1 表示没有下一页（客户端 hasMore = nextCursor >= 0）
        data.put("nextCursor", items.size() < limit ? -1 : offset + limit);
        return Result.ok(data);
    }

    @GetMapping("/matches")
    public Result<List<UserCardVO>> matches() {
        long uid = UserContext.get();
        User me = userMapper.findById(uid);
        String city = me.getCity() != null && !me.getCity().isBlank() ? me.getCity() : "杭州";
        return Result.ok(matchMapper.listForUser(uid,
                me.getLat() != null ? me.getLat() : CityGeo.lat(city),
                me.getLng() != null ? me.getLng() : CityGeo.lng(city)));
    }
}
