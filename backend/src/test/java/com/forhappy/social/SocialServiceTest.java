package com.forhappy.social;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.forhappy.entity.User;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

/** 共同点计算与破冰话术（设计 4.6：最多 3 条共同点 + 3 条话术） */
class SocialServiceTest {

    private static User user(String tags, String city, int birthYear, Integer verified) {
        User u = new User();
        u.setId(1L);
        u.setNickname("测试用户");
        u.setTags(tags);
        u.setCity(city);
        u.setBirthday(LocalDate.of(birthYear, 6, 1));
        u.setVerified(verified);
        return u;
    }

    @Test
    void commonTagsAcrossAllDimensions() {
        User a = user("[\"露营\",\"摄影\"]", "杭州", 1996, 0);
        User b = user("[\"露营\",\"旅行\"]", "杭州", 1997, 0);

        List<String> tags = SocialService.commonTags(a, b);

        assertTrue(tags.contains("都喜欢露营"), "兴趣交集");
        assertTrue(tags.contains("同在杭州"), "同城");
        assertTrue(tags.contains("年龄相仿"), "年龄差 ≤3");
    }

    @Test
    void commonTagsCappedAtThree() {
        User a = user("[\"露营\",\"摄影\",\"做饭\"]", "杭州", 1996, 1);
        User b = user("[\"露营\",\"摄影\",\"做饭\"]", "杭州", 1997, 1);

        List<String> tags = SocialService.commonTags(a, b);

        assertEquals(3, tags.size(), "共同点最多 3 条（第 4 维度\"双认证\"被截断）");
    }

    @Test
    void noCommonGroundYieldsEmpty() {
        User a = user("[\"露营\"]", "杭州", 1990, 0);
        User b = user("[\"钓鱼\"]", "北京", 2000, 0);

        assertTrue(SocialService.commonTags(a, b).isEmpty());
    }

    @Test
    void icebreakersAlwaysThreeLines() {
        User other = user("[\"露营\"]", "杭州", 1996, null);
        other.setOccupation("产品经理");

        List<String> lines = SocialService.icebreakers(other, List.of("都喜欢露营", "同在杭州"));

        assertEquals(3, lines.size(), "话术固定 3 条");
        assertTrue(lines.get(0).contains("露营"), "首条基于共同兴趣");
    }
}
