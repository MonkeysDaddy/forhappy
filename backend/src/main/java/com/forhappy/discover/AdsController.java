package com.forhappy.discover;

import com.forhappy.common.Result;
import com.forhappy.mapper.AdminManageMapper;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 广告位：App 按位置拉取在投广告（发现页横幅等） */
@RestController
@RequiredArgsConstructor
public class AdsController {

    private final AdminManageMapper adminManageMapper;

    @GetMapping("/api/v1/ads")
    public Result<List<Map<String, Object>>> byPosition(
            @RequestParam(defaultValue = "feed") String position) {
        return Result.ok(adminManageMapper.activeAds(position));
    }
}
