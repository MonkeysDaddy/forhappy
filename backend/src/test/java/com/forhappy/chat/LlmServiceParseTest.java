package com.forhappy.chat;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import java.util.List;
import org.junit.jupiter.api.Test;

/** LLM 返回解析：JSON/围栏容错、风险内容过滤、去重、条数上限 */
class LlmServiceParseTest {

    @Test
    void parsesPlainJsonArray() {
        List<String> replies = LlmService.parseReplies("[\"第一句\",\"第二句\",\"第三句\"]");
        assertEquals(List.of("第一句", "第二句", "第三句"), replies);
    }

    @Test
    void stripsMarkdownFence() {
        List<String> replies = LlmService.parseReplies("""
                ```json
                ["围栏内的回复"]
                ```
                """);
        assertEquals(List.of("围栏内的回复"), replies);
    }

    @Test
    void filtersRiskyContent() {
        List<String> replies = LlmService.parseReplies(
                "[\"加我微信号abc123细聊\",\"周末去爬山怎么样？\",\"转账给我买礼物\"]");
        assertEquals(List.of("周末去爬山怎么样？"), replies, "联系方式/资金类候选必须丢弃");
    }

    @Test
    void deduplicatesAndCapsAtThree() {
        List<String> replies = LlmService.parseReplies(
                "[\"a\",\"a\",\"b\",\"c\",\"d\"]");
        assertEquals(List.of("a", "b", "c"), replies);
    }

    @Test
    void fallsBackToLineSplittingOnBadJson() {
        List<String> replies = LlmService.parseReplies("1. 首条回复\n2. 次条回复\n3. 末条回复");
        assertEquals(3, replies.size());
        assertFalse(replies.get(0).contains("1."), "序号前缀应被剥除");
    }
}
