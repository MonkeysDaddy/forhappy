# ForHappy 后端（Spring Boot 3 + MyBatis + MySQL）

## 运行

```bash
# 1. 初始化数据库（本地 Docker MySQL，库名 forhappy）
docker exec -i wiseman-mysql mysql -udms_user_simon -pmaodou2026 forhappy < src/main/resources/db/schema.sql
docker exec -i wiseman-mysql mysql -udms_user_simon -pmaodou2026 forhappy < src/main/resources/db/data.sql

# 2. 启动（8080）
mvn spring-boot:run
```

数据源默认 `jdbc:mysql://localhost:3306/forhappy`，账号 `dms_user_simon`，可用环境变量 `DB_URL/DB_USERNAME/DB_PASSWORD` 覆盖。

## 演示账号

- 手机号 `13800000100`（Demo体验官，id=100），验证码固定 `123456`（`forhappy.sms.dev-code`）
- 种子数据与 Flutter 端对齐：19 用户 / 29 动态 / 6 会员商品 / "喜欢我"关系
- 任意新手机号自动注册，首次登录返回 `onboarded=false`，App 弹引导三问后调 `POST /auth/onboarding`

## API 概览（/api/v1，除 login/sms-code 外需 Bearer Token）

| 模块 | 接口 |
|---|---|
| 认证 | POST /auth/sms-code、POST /auth/login（返回 onboarded 标志）、POST /auth/onboarding（校验 ≥18 岁，写城市中心坐标）、POST /auth/deactivate（注销→7 天冷静期，期间登录返回 403） |
| 资料 | GET/PUT /profile/me、POST /profile/photos（isAvatar=true 同步头像）、PUT/DELETE /profile/photos/{id}（设头像/删除，删头像自动回退） |
| 文件 | POST /upload（multipart 图片上传，≤10MB，jpg/png/webp/gif；存 `./data/uploads`，`/files/**` 静态访问——OSS 直传的本地替代） |
| 发现 | GET /discover/feed?city=&sort=distance\|reco\|active&ageMin=&ageMax=&maxDist=&cursor=&limit=（年龄/距离筛选 + 游标分页 `{items,nextCursor:-1=末页}`；**reco=推荐排序**：`RecommendService` 实时打分 0.35距离+0.25兴趣交集+0.20活跃+0.20Elo，新用户24h×1.5加权，每页注入≥20%带外防信息茧房，设计§5）、GET /discover/matches |
| 社交 | POST /likes（配额 30/日；互喜欢自动建配对+会话，**返回共同点与破冰话术**并落库 fh_match.common_tags）、GET /likes/me（喜欢我的人：非会员 `blurred=true` 模糊墙，会员完整列表）、DELETE /likes/{uid}（**反悔：免费 4003 引导开通，VIP 每日 5 次，SVIP 不限**，返回剩余次数）、POST /matches/{id}/unmatch、POST/GET/DELETE /blocks（GET 返回昵称/头像卡片）、POST /reports |
| 动态 | GET /moments?city=（按距离）、POST /moments/{id}/like、POST/GET /moments/{id}/comments |
| 会员 | GET /member/products、GET /member/status（含 **likesUsedToday / likesRemaining**，会员 -1=无限）、POST /member/orders、POST /member/orders/{no}/pay（演示支付，首购价自动生效，续费叠加） |
| 聊天 | GET /conversations、GET/POST /conversations/{id}/messages（文本+图片：type=2 时 content 仅允许本站 /files/ 路径）、**POST /conversations/{id}/ai-reply（AI 回复建议）** |
| 资料 | POST /profile/location（GPS 坐标上报，反解最近城市更新 lat/lng）；PUT /profile/me 经 ContentFilter 校验昵称/简介（拦截手机号/微信号引流，设计 6.1） |
| 埋点 | POST /events（批量，事件落 fh_event；最小集 app_open/card_like/card_hide/match_success/message_send，设计 10.4） |
| admin | `X-Admin-Key` 密钥鉴权（`ADMIN_KEY`，默认 forhappy-admin）：GET/PUT /admin/products（全量商品/改价/上下架，改价即时生效于新订单）、GET /admin/stats（用户/配对/今日喜欢/订单流水/举报/今日埋点） |
| WS | `ws://host/ws/chat?token=JWT`（握手校验 token，同 uid 后连踢前连）：上行 `{"type":"ping"}`→pong、`{"type":"send",convId,msgType,content,tempId}`→`{"type":"sent",tempId,message}`；下行 `{"type":"message",convId,message,fromNickname}`（新消息）与 `{"type":"match",matchId}`（配对成功即时推送，设计 4.4） |
| AI | 配置 `LLM_API_KEY`（默认智谱 GLM，OpenAI 兼容协议，可经 `LLM_BASE_URL`/`LLM_MODEL` 换任意端点）后走大模型；未配置或调用失败自动降级本地模板（响应 `source: llm|fallback`）。每用户每日 20 次（`forhappy.llm.daily-limit`），超限 code=4002 |

## AI 回复说明

- 场景：聊天中不知道怎么回，一键生成 3 条候选（顺话题提问 / 分享自己 / 轻松幽默三种风格）；
- 提示词拼装了双方资料（年龄/城市/职业/兴趣/简介）、配对共同点、最近 10 条聊天记录；空会话自动生成开场消息；
- 安全红线：服务端对输出做正则过滤（联系方式/引流/转账/性暗示直接丢弃候选），详见 `LlmService.RISKY`；
- 启用真实大模型：`export LLM_API_KEY=你的Key` 后重启（默认模型 `glm-4-flash`，免费额度即可跑通）。

## 结构约定

- 表名前缀 `fh_`（避开 user/like/match 等 MySQL 保留字）
- 统一响应 `{code, msg, data}`；业务码：配额用尽 4001、AI 超限 4002、非会员权益 4003、未登录 401
- 距离用 `ST_Distance_Sphere` 实时计算；未上报坐标的用户按 `CityGeo` 城市中心兜底（GPS 上报经 POST /profile/location 更新）
- Elo 互动先验（设计 5.2）：被喜欢 +10、互相喜欢双方 +25、被隐藏 -8、被举报 -30，下限 600
- 鉴权拦截器仅放行 `/auth/login` 与 `/auth/sms-code`；onboarding/deactivate 均需登录态；WS 在握手阶段校验 token
- 共同点/破冰话术在配对事务内计算（`SocialService.commonTags/icebreakers`，设计 4.6）
- 实时推送：`WsPushService` 维护 uid→session 在线注册表（单机内存；多实例需引入 STOMP broker 或网关按 uid 路由）
- 反悔/AI 的每日计数为单机内存 Map，多实例部署迁 Redis
