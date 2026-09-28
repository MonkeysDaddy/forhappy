# ForHappy App（Flutter · 对接真实后端）

基于 `docs/ForHappy-设计文档.md` 实现的前端工程，**已全量对接 Spring Boot 后端**（`../backend`，默认 `localhost:8080`），无 Mock 数据残留。

## 运行

```bash
# 1. 先启动后端（见 ../backend/README.md，8080 端口）
# 2. 再运行 App
cd app
flutter pub get

# macOS 桌面窗口（最快预览）
flutter run -d macos

# 或 iOS 模拟器
open -a Simulator && flutter run -d iphone

# 或 Android 模拟器/真机
flutter run
```

> 国内网络建议先设置镜像：
> `export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`

## 演示账号

- 手机号 `13800000100`（Demo体验官），验证码固定 `123456`（登录页可点"获取验证码"，60s 防重发）
- 任意新手机号 + `123456` 自动注册 → 首次进入弹出**引导三问**（性别/想看谁/出生年份，未满 18 拦截）
- 登录态本地持久化（shared_preferences），重启免登录；"账号与安全"里可退出登录 / 注销（7 天冷静期）

## 已实现页面（对应设计文档）

| 页面 | 对应章节 | 功能 |
|---|---|---|
| Tab1 发现 | 4.3 | 瀑布流 ⇄ 列表切换；距离/推荐/活跃排序（推荐=距离+兴趣交集+活跃+Elo 实时打分）；城市切换（**真实 GPS 重新定位**：上报坐标→反解城市，拒绝授权自动降级手动选）；搜索；**筛选弹层（年龄区间/距离上限）**；**游标分页触底加载**；顶栏 ❤ 剩余喜欢次数；卡片 ❤ 喜欢；详情页（照片轮播/共同点/联系方式配对解锁/撤销喜欢） |
| Tab2 动态 | — | 图文动态流（距离排序）、点赞、评论（超出 MVP 范围的增值功能） |
| Tab3 配对 | 4.4/4.8 | **互相配对列表**（直达聊天）；**"喜欢我的人"**：免费用户模糊头像墙 + VIP 引导，会员完整列表可快捷喜欢；配对成功经 **WebSocket 实时推送** |
| Tab4 消息 | 4.5 | 会话列表、未读角标（**WS 实时刷新**）、聊天页（安全提醒条、破冰话术、**图片消息**、**AI 帮你回**） |
| Tab5 我的 | 4.7 | 资料卡（**头像上传**）、会员横幅、**编辑资料**（昵称/城市/身高/学历/收入/职业/兴趣标签/简介/联系方式）、**账号与安全**（黑名单/退出/注销）、**黑名单管理**（列表+移除） |
| 会员中心/收银台 | 4.8/4.9 | 权益矩阵、商品金额实时取后台、演示支付 → 权益全局生效 |
| 引导 | 3.1 | 登录后未 onboarding 弹**三问问卷**（必答）→ 玩法引导 |

## 可重点体验的闭环

1. **新用户注册**：换一个新手机号登录 → 引导三问 → 进发现页（feed 已按"想看谁"过滤）；
2. **配对闭环**：喜欢"喜欢我的人"列表中的用户（如杭州的「徒步的猫」）→ 配对弹窗展示**后端计算的共同点与破冰话术** → 点话术直发进聊天；
3. **VIP 权益**：免费用户喜欢到 30 次/日配额 → 付费墙弹窗；"喜欢我的人"模糊墙 → 开通 VIP → 列表解锁（会话/会员横幅同步更新）；
4. **安全闭环**：详情页/聊天页右上角举报（6 类目表单）与拉黑（即时双向移出信息流、会话关闭）；黑名单可在"我的-账号与安全"管理；
5. **AI 回复**：进入任一聊天，点输入框左侧 ✨ → 弹出 3 条候选回复 → 点击填入输入框微调后发送（后端未配置 `LLM_API_KEY` 时为模板建议，配置后为大模型生成）；
6. **实时消息**：登录后自动建立 WebSocket 长连接（25s 心跳、断线指数退避重连）——两个账号互发消息/配对，另一端即时收到，无需刷新；
7. **图片消息**：聊天页输入框左侧 🖼 选图发送（压缩上传，点击气泡全屏查看）；详情页/编辑资料支持上传真实照片作为头像；
8. **筛选与分页**：发现页点 ⚙ 筛选（年龄区间/距离上限）→ 信息流自动重置；列表滚动触底自动加载下一页；
9. **反悔（VIP）**：详情页点"已喜欢"→ 撤销（免费用户弹 VIP 引导，VIP 每日 5 次）。

## 工程说明

- 状态管理 `flutter_riverpod`；网络 `dio`（统一响应包拆解 + JWT 拦截器 + ApiException 业务码）；
- `lib/api/api.dart` 与设计文档第 9 章接口一一对应；
- 共同点/破冰话术：后端配对时计算返回（设计 4.6），客户端仅作无服务端数据时的兜底模板；
- 城市与字典暂存于 `lib/core/dicts.dart`（真实工程由后端字典接口下发）；
- 静态分析 0 告警（`flutter analyze`），widget 冒烟测试见 `test/`。

## 设计系统（Quiet Luxury · Photo First）

- 令牌：`lib/core/theme.dart` — `AppMotion`（150/240/380ms + easeOutCubic）、`AppShadows.card`（低强度投影）、`AppRadius.card = 18`、`AppType` 字阶。卡片阴影统一走 `AppShadows`，不再散落 BoxShadow。
- 发现页卡片：图片即卡片（无白边卡片），信息浮层化 — 底部深色 scrim `[0xC2, 0x66, 0x00]`，昵称/年龄/性别/职业、左下毛玻璃 DistanceChip、右下毛玻璃 LikeButton(32)、右上徽章；交错宽高比 3/4 与 3/3.62；入场 fade+14px 位移、按压 scale 0.965。
- 列表卡：间距分组节奏（身份 → 城市 → bio → 标签：8/4/10），喜欢按钮垂直居中。
- 触感：点赞 lightImpact、配对成功 mediumImpact（设计 7.6）。
- 排序控件：分段式控制（AnimatedContainer + AppMotion.normal）。
- 设计走查：`flutter test --update-goldens test/design_preview_test.dart` 生成 `test/goldens/waterfall.png` / `list.png`（离线 HTTP 桩 + 纯色 PNG，无需网络）。

### 全页面设计走查（第二轮，2026-08-31）

- 登录页：无图标下划线式输入（divider 底线 + 品牌色聚焦线）、渐变字标 40px、错误提示为浅红胶囊（AnimatedSize 展开）、间距节奏 36/44。
- 消息页：Tile 重写（54 头像 + 右上未读小红点、99+ 胶囊、未读副文案加重）、分隔线 indent 78。
- 聊天页：AppBar 带对方向头像、气泡限宽 300；破冰 chips / AI 帮你回 / 发图输入栏维持。
- 资料详情页：照片区毛玻璃计数章（1/N）、章节标题统一品牌竖条 + 14px、区块间距 22。
- 会员中心：hero 卡金卡质感（goldGradient+md 阴影）/非会员暗奢深色，徽章描边圆钮。
- 收银台：hero 渐变跟随档位（SVIP 金色）。
- 动态/配对/发现/消息页标题统一 26px 渐变字标；动态卡留白 16、点赞触感。
- 引导三问：选择/翻页 selectionClick 触感。
- golden 走查新增 goldens/login.png。

### 正式化收尾（2026-08-31 第三轮）

- JWT 迁移 Keychain/Keystore（flutter_secure_storage），旧明文 token 首启自动搬迁并删除；clearSession 只删会话 key。
- WS 鉴权改首帧认证：握手 URL 不再带 token（防网关日志泄露）；连接后 5 秒内须发 {"type":"auth","token"}，服务端 JwtUtil 校验后回 pong 确认；超时调度器主动踢未认证连接（1008）。客户端收到 pong 才算连接可用（清退避计数）。
- 深色模式：AppColors 变亮/暗双色板（_dark 静态开关，buildAppTheme(Brightness) 时设置），MaterialApp theme+darkTheme+ThemeMode.system 跟随系统；暗色为暖炭/石墨体系，品牌珊瑚渐变/香槟金/语义色保持。新增 token 时用 `static Color get x => _c(light, dark)` 形式。

### 产品功能补全（2026-09-27，对标中国社交产品标准）

- **动态发布**：POST /moments（文案 ContentFilter 过滤联系方式 + 照片须先上传 /files/ + 每日 10 条上限）；动态页右下悬浮发布按钮 → 发布页（多选照片最多 6 张 + 500 字文案）。
- **超级喜欢**：fh_like.action=3（表结构原生支持）；VIP 每日 1 次 / SVIP 每日 5 次 / 免费用户引导开通（4003）；Elo +40（普通喜欢 +10）；卡片金色星形按钮（mediumImpact 触感）。
- **真人认证**：POST /profile/verify（演示自动通过）；我的页 → 认证中心页，拍自拍上传即点亮徽章。
- **照片墙管理**：我的页 → 照片墙，GridView 多图上传（≤9 张）/删除/设为门面（第一张）。
- **距离隐私**：fh_user.hide_distance 开关（账号与安全页切换）；feed/detail 对开启者返回 null 距离；feed 排序用原生距离表达式（不用别名防 NULL 干扰）。
- **语音消息**：type=3（后端支持 /files/ 录音路径，会话列表显示「[语音]」）；聊天页麦克风按钮按说话（record 包 + Info.plist 麦克风权限），气泡带声波示意 + just_audio 播放。
- **推荐理由**：卡片距离旁「都喜欢 {标签}」珊瑚胶囊（前端算兴趣交集，让推荐分可解释）。
- **滑动卡片**：ViewMode.swipe 第三种浏览形态（发现页视图切换三段），右滑喜欢/左滑隐藏，阈值 110px + 旋转动效 + 底卡缩放层叠。
- **表情面板**：聊天输入行表情按钮 → 40 个常用 emoji 网格，点击插入输入框。
- **图片缓存**：CachedPhoto（cached_network_image）全量替换 Image.network（7 处），测试环境（FLUTTER_TEST）自动退回 Image.network 配合 golden HTTP 桩。
- **资料完成度**：我的页环形进度横幅（照片 30/简介 20/标签 20/职业 10/学历 10/身高 10），未满 100 显示。

### 视觉精修第三轮（2026-09-27，"去出厂感"八项）

1. **骨架屏**：shimmer 包 + SkeletonBox/SkeletonCircle/FeedSkeleton/ListRowSkeleton/MomentsSkeleton，五个 Tab 及黑名单 loading 全部替换（按钮内迷你转圈保留）。
2. **图标库**：lucide_icons_flutter 全量替换 Material Icons（23 文件，脚本映射表）；保留三类 Material：LikeButton 与动态点赞的 favorite/favorite_border 状态心形、性别 ♂♀、Apple Pay 标。
3. **品牌字体**：得意黑 SmileySans-Oblique（assets/fonts，免费商用）用于字标/页头 27px 标题/详情大字与数据/价格/配对标题/完成度数字；正文保持系统字。
4. **头像状态环**：PersonAvatar 新增 onlineMinutes/verified 参数——在线绿环、认证珊瑚渐变环（Story 环语言），消息/配对/动态启用。
5. **金卡流光**：SheenOverlay 高光带每 3.2s 扫过会员中心金卡。
6. **分时渐变**：headerGradientForNow()——清晨蜜桃(5-10)/白天珊瑚(10-17)/傍晚霞紫(17-20)/深夜暗珊瑚(20-5)，暗色模式整体压深 28%；GradientPageHeader/GradientAppBar 已接入，CTA 按钮保持品牌主渐变。
7. **点赞粒子**：LikeButton 点击爆出 8 颗品牌色粒子（TickerProviderStateMixin 双控制器）；刷新指示器加白底与位移调优。
8. **暗色细节**：暗色模式照片卡加 9% 白描边；夜间头部渐变自动加深。

### 全面交互/动效 QA（2026-09-27，两路专项审查后统一修复）

**严重（功能性）修复**
- 引导弹层「下一步」曾直接关闭弹层 → 改为真正翻页（nextPage），末页才「开始发现」。
- 照片墙删除钮被整格 InkWell 挡住（永远点不到/误触设为门面）→ Stack 层级重排：照片+InkWell 在下、删除钮置顶 + opaque 命中。
- 退出登录 `ref as Ref` 必崩 → logout() 改收 WidgetRef。
- AppColors._dark 全局开关因两套 Theme 同时构建被恒置暗色 → 移除构建期 setScheme，改由 MaterialApp.builder 按 Theme.of(context).brightness 设置。
- 语音气泡分支丢失（发送后显示裸路径）→ 补齐 isVoice 分支（播放/停止 + 声波示意），_toggleVoice 接回。
- 搜索态顶栏缺状态栏安全区 → 补 MediaQuery top padding。
- 滑动卡模式：包 ListView 使下拉刷新/触底预加载可用；手势改横向拖动；左滑 hide 移到飞出动画完成后执行（修复吞卡+错乱动画）。

**中/轻修复（摘要）**
- LikeButton 弹性停格（1.18 永久放大）→ TweenSequence 放大回落；glass 心形命中区扩到整圆；超级喜欢热区 44。
- 表情面板与键盘互斥（开面板 unfocus / 点输入框收面板）；键盘弹出自动回滚到底；WS 新消息仅接近底部时回滚；失败消息按类型重试（图片红框角标/语音直发）；录音 60s 上限 + 计时胶囊 + 发送中态；语音 setUrl 容错。
- 筛选 sheet「重置」同时清空拖动草稿；翻页失败后滚动不再自动重试；搜索键提交收起键盘。
- 四页写死白底（编辑资料/账号安全/黑名单/引导三问）→ AppColors.surface；matches/me/member/checkout/city_sheet/user_detail/chat 暗色不可见文字全部 token 化；两个底部 sheet 背景暗色适配；Dock 暗色底。
- 收银台商品错误态可重试、商品卡选择动画；引导弹层高度 300 修溢出；配对骨架 4 圆防横向溢出；举报 sheet 键盘全量避让 + 网络异常兜底；发布页/编辑资料未保存离开确认；距离开关防抖 + 失败提示；完成度改 watch 实时刷新；动态照片 +N 角标；评论失败提示；模糊墙 pushThrottled；onboarding picker 控制器泄漏修复；瀑布流 chip 行防溢出；晨昏渐变加深保证白字对比度。

### 继续收尾（2026-09-27 第四轮）

- **瀑布流懒加载重构**：单ChildScrollView 全量构建 → 左右两条 ListView.builder（卡片等高 3:4 交替均分），只构建可见卡；入场动画仅首屏（index<20）播放，翻页新卡不重播。
- **Dock 重复点击当前 Tab → 主列表回顶部**：TabScrollRegistry（一 Tab 多控制器，瀑布流左右列各一），五个主列表已接入。
- 点赞在途返回 processing（不再误报"已经喜欢过"）；发送按钮 _sending 禁用；PersonAvatar 死参数清理；动态操作按钮/VIP 查看命中区扩到 40px；金冠死三元清理；发布页死字段清理；onboarding AnimatedSize 消除步骤高度跳变；收银台协议行整行可点；分隔线 F0F1F3 残留全部 token 化。

### 提分轮（2026-09-27，功能完整度 + 页面编排）

**补齐权益矩阵"已售卖但未实现"的四项权益**
- **消息已读回执（VIP）**：fh_message.read_at；进会话/收新消息时 POST /conversations/{id}/read 标记 + WS {"type":"read"} 推给对方；我最后一条已读消息下方"已读"角标（免费用户不显示）。
- **只看已认证（VIP）**：feed 参数 verifiedOnly（服务端按请求者会员等级门控，无权静默忽略）；筛选 sheet 权益区开关，非会员点击 → VIP 开通页。
- **高级筛选 学历/职业（SVIP）**：feed 参数 education/occupation（LIKE）；筛选 sheet 双下拉，非 SVIP 显示🔒点击引导开通。
- **SVIP/VIP 推荐优先曝光**：RecommendService 对 member 候选 +15%/+8% 加权。

**转场编排（页面展示 82→85+ 的关键项）**
- AppPageRoute：统一页面转场（淡入 + 24px 上浮，240ms easeOutCubic），全 App 23 处 MaterialPageRoute 替换。
- Tab 切换淡入（180ms，IndexedStack 外 FadeTransition，切换时 forward from 0）。
- 瀑布流入场错帧：右列延迟 18% 起播。

**搜索服务端化**
- feed 新增 q 参数（nickname/occupation/bio LIKE）；searchQueryProvider 300ms 防抖 → feed reload；去掉"只搜已加载条目"的本地过滤。

**内容 seed**
- 注入 7 条自然感演示动态（桂花/livehouse/阳台改造/徒步等，picsum 配图，错峰时间戳），动态页不再空转。

### 细节与信息展示轮（2026-09-27 第五轮）

- **隐藏距离全链路**：FeedEntry/ApiMoment.distanceKm 可空；动态 feed SQL 同样对 hide_distance 返回 NULL；卡片显示"距离隐藏"而非错误的 0m；配对页对 null 距离不拼接。
- **时间体系**：会话列表 _chatTime（今天 HH:mm / 昨天 / 周X / MM-DD）；聊天页 >5 分钟间隔自动插入时间分隔条（今天 HH:mm / 昨天 HH:mm / 周X HH:mm / MM-DD HH:mm）；动态保持"x小时前"。
- **OnlineDot compact**：照片卡上只在"在线"时显示绿点+在线（离线不占位），详情页保留完整文案——昵称不再被截断。
- **完成度缺项明细**：横幅副标题显示"还差：照片 · 简介 · 兴趣标签"（最多 3 项），改 watch 实时刷新。
- **会员权益表**：✓ 文本 → Lucide 勾图标；当前用户档位列高亮（品牌底胶囊 + "(当前)"）；"—" 弱化禁用色。

## 管理后台（admin/，基于 Vben Admin v5.7）

- 位置：`admin/vben`（Vue 3 + Vite + Ant Design Vue，pnpm monorepo，取 apps/web-antd 裁剪）
- 启动：`cd admin/vben && pnpm install --registry=https://registry.npmmirror.com && pnpm --filter @vben/web-antd dev`（端口 5666）
- 登录：用户名 `admin`，密码 = 管理密钥（演示 `forhappy-admin`）；滑块验证后进入。密钥即 accessToken，请求头同时携带 Bearer + X-Admin-Key（后端两者兼容）。
- 功能：运营统计看板（用户/配对/订单/收入/今日埋点）+ 会员商品管理（改价/原价/首月价/上下架，带确认弹窗）；菜单在 src/router/routes/modules/forhappy.ts。
- 适配点：vite 代理 /api → 8080（保留前缀）；.env VITE_GLOB_API_URL=/api/v1/admin + 关 Nitro mock；antd 组件显式导入（vben 不做全局注册）；用户信息/权限码为静态演示实现。

## 管理后台完整版（2026-09-27 第二批，7 个功能模块）

在 Vben 后台新增 6 个页面（统计/商品之外），后端新增对应 admin API（AdminManageMapper + 5 个新控制器）：

- **用户管理** /admin/users：搜索（昵称/手机号）+ 状态/档位筛选；创建用户（手机号注册制，用户侧验证码登录）；禁用（登录拒绝 + 信息流消失）/启用；软删除；详情抽屉（资料 + 订阅方案 + 消费订单 + 收到的喜欢/动态数）。登录侧同步拒绝 status=2/9。
- **订阅方案 CRUD**：新建（档位/时长/价格/角标）、删除（有订单的方案拒绝删除，提示下架）、原有改价上下架。
- **订阅对账** /admin/orders + /orders/summary：已支付/待支付汇总卡 + 近 7 天收入对账表 + 订单流水（按用户/状态筛选，关联昵称与方案）。
- **日志中心**：行为埋点（fh_event 按事件/用户筛选）+ 后台操作审计（fh_admin_log，所有管理操作自动落 log）。
- **敏感词管理** /admin/words：增删即时生效（SensitiveWordStore 内存缓存），聊天 + 动态发布命中即拦截。
- **违规记录** /admin/violations：拦截流水（用户/来源/命中词高亮/内容/时间）。注意：聊天违规记录在控制器层（事务外）落库，事务内会被回滚。

新表：fh_sensitive_word / fh_violation / fh_admin_log（schema.sql + 线上库已建）。

## 业务完善大版本（2026-09-27，广告/通知/多渠道支付/社交展示订阅 + 管理后台完整化）

**App 端新增**
- **通知中心**：`/notifications` 页（类型图标/未读点/全部已读），发现页顶栏铃铛 + 未读角标；WS message/match 帧自动刷新角标；后端在会员到期前 72h 自动插入到期提醒（每日一条去重）。
- **广告横幅**：发现页头部下方横幅（图 + 标题 + 文案 + 角标"广告"），点击弹详情；数据来自 `GET /ads?position=feed`（公开接口）。
- **社交账号展示（社交展示卡·月订）**：
  - 后端：fh_user.social_showcase(JSON) + social_expire_at；`GET/PUT /social-showcase`；详情接口仅对持卡用户下发 socialShowcase；PUT 在无有效订阅时强制清空（到期即隐藏）；`tier=3` 商品支付后按 durationDays 顺延社交展示期。
  - 编辑资料页：社交展示卡状态卡（展示中 · 到期日 / 未开通），账号编辑器（平台下拉 + 账号，最多 6 个），未订阅一键开通（自动下单支付 tier=3 套餐）。
  - 详情页：`社交账号` 区块 chips 展示（仅对方持卡可见）。

**管理后台新增（与 App 全量接线）**
- 用户管理：列表/搜索/创建（手机号注册制）/禁用（登录拒绝+信息流消失）/软删除/详情（资料+订阅+消费订单+互动计数）。
- 订阅对账：byStatus 汇总 + 近 7 天收入序列 + 订单流水（按用户/状态筛选）。
- 日志中心：行为埋点（fh_event 筛选）+ 后台操作审计（fh_admin_log，管理操作自动记录）。
- 广告投放：创建/停投/恢复/删除。
- 举报处理：核实（禁用被举报人）/驳回，状态流转。
- 订阅方案 CRUD：新建（tier 1/2/3）+ 删除（有订单拒绝）。

**多渠道支付**：channel 1微信/2支付宝/3IAP/4赠送 全链路落库；收银台渠道选择 UI 保留，支付后按渠道可对账。

## 合规与治理大版本（2026-09-27 第三批，P0/P1 合规路线图全量落地）

**合规红线（P0）**
- **频控**：RateLimiter 滑动窗口——短信（同号 60s 一条/日 10 条/IP 时 20 条）、登录（同号 5min 5 次/IP 时 30 次）、后台登录（5min 5 次）。超限 429。
- **手机号加密存储**：PhoneCrypto AES-GCM（密钥 forhappy.crypto.key），phone_enc 改存密文；管理端 SQL 层脱敏 `138****1234`；完整号搜索走 phone_hash 精确匹配。
- **协议合规**：App 登录页（待接：协议页面+勾选，见 App 端待办）。
- **先审后发**：照片/动态插入即 review_status/status=0（待审），管理端审核队列（通过/驳回），通过后头像照自动激活、动态进入信息流；所有展示面仅出已审内容。

**管理完整性（P1）**
- **RBAC**：fh_admin_user 表 + 会话登录（8h TTL）+ 四角色权限矩阵（super 全部 / ops 商业化+运营 / reviewer 内容安全 / support 用户）；AdminApiSupport.require(permission) 全控制器接入；超管应急通道（master key 无状态 token，重启不失效）。默认账号 admin/forhappy-admin（sha256+salt）。
- **分级处置**：禁言 1-30 天（mute_until，聊天发送 403 + 通知）/ 封禁 status=3（登录 403 + 通知）/ 解除；用户管理页一键操作。
- **公告群发**：POST /admin/notices fan-out 全部正常用户；App 通知中心即时可见。
- **举报取证**：GET /admin/reports/{id}/chat 调取双方聊天记录；用户详情抽屉含最近 30 条聊天。
- **审计增强**：fh_admin_log 增 IP 字段，AdminApiSupport.log 自动记录操作者+IP。
- **系统设置分组**：审核队列 + 管理员账号页。

## 审查修正轮（2026-09-28，按审查报告优先级逐项修正）

**P0 四项**
1. **用户管理加头像**：列表头像列（Avatar 兜底首字）+ 详情抽屉头像 + 照片墙（含审核中标记，数据源切 photosMine 全量含待审）。
2. **举报聊天取证接线**：用户详情抽屉内嵌"最近聊天 30 条"（本人/对方标注、图片语音脱敏）；后端 /admin/chats/of-user/{userId} + /{convId}/messages。
3. **时间格式化**：用户表注册时间 `MM-DD HH:mm`、订单表时间列、会员列显示档位+到期日。
4. **删除匿名化**：anonymizeDeletedUser——phone_hash 改写为不可逆占位（释放手机号可重注册）、昵称改"已注销用户"、清空社交展示/资料；登录侧已删用户 403。

**P1 五项**
5. **手动开通/取消会员**：PUT /users/{id}/membership（tier 0/1/2 + days 顺延）+ 通知；详情抽屉"订阅与会员调整"按钮组。
6. **退款**：PUT /orders/{orderNo}/refund（仅已支付可退）+ 通知；订单行内退款按钮（红色确认）。
7. **禁言天数选择 + 解除禁言**：行内"更多"下拉（禁言 3/7/30 天、解除禁言、封禁、删除）。
8. **公告定向发送**：target=all/vip/svip/member/userId。
9. **审核驳回通知**：驳回动态/照片时通知用户（后端 review 端点接通知，App 通知中心可见）。

**合规红线**
- 登录页协议勾选（未勾选拦截）+ 《用户协议》《隐私政策》页面（AgreementPage，正式文案上线前替换）。

## 双端联动闭环版（2026-09-28 第三批，管理端 ↔ App 全量接线）

- **审核结果通知作者**：动态/照片 通过→「审核通过」通知；驳回→「未通过」通知（可带驳回理由，通知内容含理由）。
- **举报处理通知举报人**：核实→「已核实并处理」；驳回→「暂未发现违规」。举报行内新增「聊天取证」抽屉（调 /reports/{id}/chat，标注举报人/被举报人）。
- **违规记录快捷处置**：行内「禁言7天」「封禁」按钮直连用户处置接口。
- **公告定向**：target=all/vip/svip/member/user(+userId)，NoticeController 按 target 取人群。
- **App 会员同步**：切「我的」Tab 时 membershipProvider.syncFromServer()——管理端手动开通/取消即时生效。
- **后端**：AdminNoticeController 定向 target；AdminReviewController 驳回理由参数；AdminReportController.handle 通知举报人。
