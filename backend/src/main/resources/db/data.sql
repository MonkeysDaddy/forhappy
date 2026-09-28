-- ForHappy 种子数据（与 Flutter 端 Mock 对齐；可重复执行：先清空）
SET NAMES utf8mb4;
DELETE FROM fh_moment_comment; DELETE FROM fh_moment_like; DELETE FROM fh_moment;
DELETE FROM fh_photo; DELETE FROM fh_like; DELETE FROM fh_match;
DELETE FROM fh_conversation; DELETE FROM fh_message;
DELETE FROM fh_member_order; DELETE FROM fh_member_product;
DELETE FROM fh_report; DELETE FROM fh_block; DELETE FROM fh_user;

INSERT INTO fh_user (id, phone_hash, phone_enc, nickname, avatar_url, gender, prefer_gender, city,
  height_cm, weight_kg, education, occupation, income, bio, tags, verified, member_tier,
  wechat, instagram, facebook, last_active_minutes) VALUES
(1,  SHA2('13800000001',256),'13800000001','豆腐脑','https://randomuser.me/api/portraits/women/44.jpg',2,1,'杭州',163,48,'本科','UI 设计师','w10to20','周末不是在西湖边就是在去西湖边的路上。',JSON_ARRAY('摄影','咖啡','徒步'),1,1,'doufunao_design','tofu.brain',NULL,3),
(2,  SHA2('13800000002',256),'13800000002','夜航西飞','https://randomuser.me/api/portraits/women/65.jpg',2,1,'杭州',168,52,'硕士','产品经理','w20to50','白天写需求，晚上写小说。',JSON_ARRAY('阅读','电影','旅行'),0,0,'westward_night',NULL,NULL,25),
(3,  SHA2('13800000003',256),'13800000003','徒步的猫','https://randomuser.me/api/portraits/women/26.jpg',2,1,'杭州',160,46,'本科','自由职业','w5to10','带猫爬过 30 座山，目标 100 座。',JSON_ARRAY('徒步','露营','猫'),1,2,'hiking_cat','cat.on.trail',NULL,8),
(4,  SHA2('13800000004',256),'13800000004','山与风','https://randomuser.me/api/portraits/men/32.jpg',1,2,'杭州',181,72,'本科','户外领队','w10to20','山系生活爱好者，周末固定出队。',JSON_ARRAY('徒步','露营','摄影'),1,1,'mount_wind',NULL,NULL,12),
(5,  SHA2('13800000005',256),'13800000005','程序员小周','https://randomuser.me/api/portraits/men/45.jpg',1,2,'杭州',175,70,'硕士','后端工程师','w20to50','代码写累了就骑车去龙井。',JSON_ARRAY('骑行','电影','咖啡'),0,0,NULL,'zhou.codes',NULL,50),
(6,  SHA2('13800000006',256),'13800000006','桃桃乌龙','https://randomuser.me/api/portraits/women/12.jpg',2,1,'上海',166,50,'本科','市场运营','w10to20','看展、citywalk、找好吃的面包店。',JSON_ARRAY('看展','美食','摄影'),1,2,'peach_oolong',NULL,'taotao.oolong',5),
(7,  SHA2('13800000007',256),'13800000007','阿澈','https://randomuser.me/api/portraits/women/71.jpg',2,1,'上海',170,53,'本科','插画师','w5to10','画画的，社恐但熟了很疯。',JSON_ARRAY('绘画','电影','猫'),0,0,NULL,'ache.draws',NULL,90),
(8,  SHA2('13800000008',256),'13800000008','摄影师K','https://randomuser.me/api/portraits/men/76.jpg',1,2,'上海',179,68,'本科','商业摄影师','w20to50','胶片与数码双修，约拍可聊。',JSON_ARRAY('摄影','旅行','咖啡'),1,1,'photographer_k','k.shoots',NULL,15),
(9,  SHA2('13800000009',256),'13800000009','篮球少年','https://randomuser.me/api/portraits/men/15.jpg',1,2,'上海',186,82,'本科','体育老师','w5to10','打野球缺一个递水的。',JSON_ARRAY('篮球','健身','电影'),0,0,'hoops_boy',NULL,NULL,40),
(10, SHA2('13800000010',256),'13800000010','岛屿来信','https://randomuser.me/api/portraits/women/90.jpg',2,1,'北京',165,49,'硕士','编辑','w10to20','在胡同里开了间小小的书房。',JSON_ARRAY('阅读','写作','话剧'),1,1,'island_letter',NULL,NULL,20),
(11, SHA2('13800000011',256),'13800000011','月亮不打烊','https://randomuser.me/api/portraits/women/50.jpg',2,1,'北京',162,47,'本科','乐队键盘手','w5to10','livehouse 常驻选手。',JSON_ARRAY('音乐','电影','美食'),0,0,NULL,'moon.open24h','moonband.keys',6),
(12, SHA2('13800000012',256),'13800000012','深夜读诗','https://randomuser.me/api/portraits/men/61.jpg',1,2,'北京',177,71,'博士','高校教师','w10to20','研究古代文学，也研究现代生活。',JSON_ARRAY('阅读','话剧','徒步'),0,0,'midnight_poems',NULL,NULL,120),
(13, SHA2('13800000013',256),'13800000013','奶油苏打','https://randomuser.me/api/portraits/women/33.jpg',2,1,'深圳',164,50,'本科','前端工程师','w20to50','海边长大，代码也写，冲浪也冲。',JSON_ARRAY('冲浪','健身','电影'),0,0,NULL,'cream.soda',NULL,10),
(14, SHA2('13800000014',256),'13800000014','冲浪教练','https://randomuser.me/api/portraits/men/88.jpg',1,2,'深圳',183,76,'本科','冲浪教练','w10to20','西涌常驻，教你站板。',JSON_ARRAY('冲浪','健身','露营'),1,2,'surf_coach','surf.coach.sz',NULL,30),
(15, SHA2('13800000015',256),'13800000015','健身Fan','https://randomuser.me/api/portraits/men/22.jpg',1,2,'深圳',180,78,'本科','健身教练','w10to20','三分练七分吃，剩九十分靠坚持。',JSON_ARRAY('健身','美食','篮球'),0,0,'gym_fan',NULL,NULL,70),
(16, SHA2('13800000016',256),'13800000016','小满','https://randomuser.me/api/portraits/women/5.jpg',2,1,'成都',158,44,'本科','烘焙师','below5','甜品治愈一切，包括周一。',JSON_ARRAY('烘焙','猫','电影'),0,0,'xiaoman_bakes',NULL,NULL,18),
(17, SHA2('13800000017',256),'13800000017','吉他手','https://randomuser.me/api/portraits/men/51.jpg',1,2,'成都',178,65,'本科','音乐老师','w5to10','玉林路小酒馆常客。',JSON_ARRAY('音乐','美食','阅读'),0,0,NULL,'guitar.chengdu',NULL,45),
(18, SHA2('13800000018',256),'13800000018','户外大刘','https://randomuser.me/api/portraits/men/95.jpg',1,2,'成都',182,74,'本科','户外领队','w10to20','川西环线走了二十遍。',JSON_ARRAY('徒步','露营','摄影'),1,1,'outdoor_liu',NULL,NULL,55),
(100,SHA2('13800000100',256),'13800000100','Demo体验官','https://randomuser.me/api/portraits/men/10.jpg',1,2,'杭州',178,70,'本科','产品体验官','w10to20','来 ForHappy 认真找个人。',JSON_ARRAY('摄影','徒步','电影'),1,0,'demo_wechat',NULL,NULL,0);

INSERT INTO fh_photo (user_id, url, sort_order, is_avatar) VALUES
(1,'https://randomuser.me/api/portraits/women/44.jpg',0,1),(1,'https://randomuser.me/api/portraits/women/45.jpg',1,0),
(2,'https://randomuser.me/api/portraits/women/65.jpg',0,1),(2,'https://randomuser.me/api/portraits/women/66.jpg',1,0),
(3,'https://randomuser.me/api/portraits/women/26.jpg',0,1),(3,'https://randomuser.me/api/portraits/women/27.jpg',1,0),
(4,'https://randomuser.me/api/portraits/men/32.jpg',0,1),(4,'https://randomuser.me/api/portraits/men/33.jpg',1,0),
(5,'https://randomuser.me/api/portraits/men/45.jpg',0,1),(5,'https://randomuser.me/api/portraits/men/46.jpg',1,0),
(6,'https://randomuser.me/api/portraits/women/12.jpg',0,1),(6,'https://randomuser.me/api/portraits/women/13.jpg',1,0),
(7,'https://randomuser.me/api/portraits/women/71.jpg',0,1),(7,'https://randomuser.me/api/portraits/women/72.jpg',1,0),
(8,'https://randomuser.me/api/portraits/men/76.jpg',0,1),(8,'https://randomuser.me/api/portraits/men/77.jpg',1,0),
(9,'https://randomuser.me/api/portraits/men/15.jpg',0,1),(9,'https://randomuser.me/api/portraits/men/16.jpg',1,0),
(10,'https://randomuser.me/api/portraits/women/90.jpg',0,1),(10,'https://randomuser.me/api/portraits/women/91.jpg',1,0),
(11,'https://randomuser.me/api/portraits/women/50.jpg',0,1),(11,'https://randomuser.me/api/portraits/women/51.jpg',1,0),
(12,'https://randomuser.me/api/portraits/men/61.jpg',0,1),(12,'https://randomuser.me/api/portraits/men/62.jpg',1,0),
(13,'https://randomuser.me/api/portraits/women/33.jpg',0,1),(13,'https://randomuser.me/api/portraits/women/34.jpg',1,0),
(14,'https://randomuser.me/api/portraits/men/88.jpg',0,1),(14,'https://randomuser.me/api/portraits/men/89.jpg',1,0),
(15,'https://randomuser.me/api/portraits/men/22.jpg',0,1),(15,'https://randomuser.me/api/portraits/men/23.jpg',1,0),
(16,'https://randomuser.me/api/portraits/women/5.jpg',0,1),(16,'https://randomuser.me/api/portraits/women/6.jpg',1,0),
(17,'https://randomuser.me/api/portraits/men/51.jpg',0,1),(17,'https://randomuser.me/api/portraits/men/52.jpg',1,0),
(18,'https://randomuser.me/api/portraits/men/95.jpg',0,1),(18,'https://randomuser.me/api/portraits/men/96.jpg',1,0),
(100,'https://randomuser.me/api/portraits/men/10.jpg',0,1);

INSERT INTO fh_moment (id, user_id, caption, photos, likes_base) VALUES
(1, 1,'西湖边的日落，今天值了',JSON_ARRAY('https://randomuser.me/api/portraits/women/47.jpg'),12),
(2, 1,'新学的拿铁拉花，勉强成型',JSON_ARRAY('https://randomuser.me/api/portraits/women/48.jpg','https://randomuser.me/api/portraits/women/49.jpg'),8),
(3, 2,'凌晨两点的第三章，终于写完',JSON_ARRAY('https://randomuser.me/api/portraits/women/67.jpg'),15),
(4, 2,'今年第 21 本书',JSON_ARRAY('https://randomuser.me/api/portraits/women/68.jpg'),6),
(5, 3,'带主子解锁第 31 座山',JSON_ARRAY('https://randomuser.me/api/portraits/women/28.jpg','https://randomuser.me/api/portraits/women/29.jpg'),23),
(6, 3,'山顶泡面是真的香',JSON_ARRAY('https://randomuser.me/api/portraits/women/30.jpg'),17),
(7, 4,'云海日出，出队第 100 次打卡',JSON_ARRAY('https://randomuser.me/api/portraits/men/34.jpg'),31),
(8, 4,'上周末的队员大合影',JSON_ARRAY('https://randomuser.me/api/portraits/men/35.jpg','https://randomuser.me/api/portraits/men/36.jpg'),19),
(9, 5,'下班骑车去龙井看日落',JSON_ARRAY('https://randomuser.me/api/portraits/men/47.jpg'),9),
(10,6,'西岸新开的展，值得二刷',JSON_ARRAY('https://randomuser.me/api/portraits/women/14.jpg','https://randomuser.me/api/portraits/women/15.jpg'),21),
(11,6,'找到一家满分可颂店',JSON_ARRAY('https://randomuser.me/api/portraits/women/16.jpg'),11),
(12,7,'新稿画完，眼睛已报废',JSON_ARRAY('https://randomuser.me/api/portraits/women/73.jpg'),14),
(13,8,'昨天拍的一组胶片，原图直出',JSON_ARRAY('https://randomuser.me/api/portraits/men/78.jpg','https://randomuser.me/api/portraits/men/79.jpg'),42),
(14,8,'棚拍幕后，灯架比人多',JSON_ARRAY('https://randomuser.me/api/portraits/men/80.jpg'),13),
(15,9,'今晚的野球局，还差两人',JSON_ARRAY('https://randomuser.me/api/portraits/men/17.jpg'),7),
(16,10,'书房的秋天，柿子熟了',JSON_ARRAY('https://randomuser.me/api/portraits/women/92.jpg'),26),
(17,10,'昨晚的话剧，后劲很大',JSON_ARRAY('https://randomuser.me/api/portraits/women/93.jpg','https://randomuser.me/api/portraits/women/94.jpg'),9),
(18,11,'周五的场子，台下全满',JSON_ARRAY('https://randomuser.me/api/portraits/women/52.jpg','https://randomuser.me/api/portraits/women/53.jpg'),33),
(19,12,'整理书房，翻出十年前的笔记',JSON_ARRAY('https://randomuser.me/api/portraits/men/63.jpg'),5),
(20,13,'周末的海，浪况不错',JSON_ARRAY('https://randomuser.me/api/portraits/women/35.jpg','https://randomuser.me/api/portraits/women/36.jpg'),18),
(21,13,'工位升级，双屏的快乐',JSON_ARRAY('https://randomuser.me/api/portraits/women/37.jpg'),4),
(22,14,'今天学员第一次站板成功',JSON_ARRAY('https://randomuser.me/api/portraits/men/90.jpg'),29),
(23,14,'西涌的晚霞，每天看不腻',JSON_ARRAY('https://randomuser.me/api/portraits/men/91.jpg','https://randomuser.me/api/portraits/men/92.jpg'),16),
(24,15,'深蹲 PR 了，140kg',JSON_ARRAY('https://randomuser.me/api/portraits/men/24.jpg'),22),
(25,16,'新品：花椒巧克力，意外好吃',JSON_ARRAY('https://randomuser.me/api/portraits/women/7.jpg','https://randomuser.me/api/portraits/women/8.jpg'),19),
(26,16,'店猫上班第一天',JSON_ARRAY('https://randomuser.me/api/portraits/women/9.jpg'),31),
(27,17,'写了首新歌，关于玉林的雨',JSON_ARRAY('https://randomuser.me/api/portraits/men/53.jpg'),12),
(28,18,'川西的星空，银河肉眼可见',JSON_ARRAY('https://randomuser.me/api/portraits/men/97.jpg','https://randomuser.me/api/portraits/men/98.jpg'),45),
(29,18,'营地早餐，咖啡配雪山',JSON_ARRAY('https://randomuser.me/api/portraits/men/99.jpg'),27);

INSERT INTO fh_moment_comment (moment_id, user_id, content) VALUES
(7, 3,'这云海绝了，周末带我一个！'),
(7, 5,'羡慕，我还在加班写代码'),
(1, 2,'求日落机位！');

-- 生日种子（age 与 Flutter 端 Mock 对齐）
UPDATE fh_user SET birthday = CASE id
  WHEN 1 THEN '2002-05-01' WHEN 2 THEN '2000-05-01' WHEN 3 THEN '1999-05-01'
  WHEN 4 THEN '1999-05-01' WHEN 5 THEN '2000-05-01' WHEN 6 THEN '2001-05-01'
  WHEN 7 THEN '2003-05-01' WHEN 8 THEN '1997-05-01' WHEN 9 THEN '2003-05-01'
  WHEN 10 THEN '1999-05-01' WHEN 11 THEN '2001-05-01' WHEN 12 THEN '1996-05-01'
  WHEN 13 THEN '2002-05-01' WHEN 14 THEN '1998-05-01' WHEN 15 THEN '2001-05-01'
  WHEN 16 THEN '2004-05-01' WHEN 17 THEN '2002-05-01' WHEN 18 THEN '1999-05-01'
  WHEN 100 THEN '1998-05-01' END;

-- "喜欢我"关系种子（对应 Flutter 端 likesYou，供配对闭环演示）
INSERT IGNORE INTO fh_like (from_user, to_user, action) VALUES
(1,100,1),(3,100,1),(4,100,1),(6,100,1),(9,100,1),(11,100,1),(16,100,1),(18,100,1);

-- 坐标：按城市中心 + 按 id 的确定性偏移（演示距离排序）
UPDATE fh_user SET lat = CASE city WHEN '杭州' THEN 30.2741 WHEN '上海' THEN 31.2304 WHEN '北京' THEN 39.9042 WHEN '深圳' THEN 22.5431 WHEN '成都' THEN 30.5728 END,
                   lng = CASE city WHEN '杭州' THEN 120.1551 WHEN '上海' THEN 121.4737 WHEN '北京' THEN 116.4074 WHEN '深圳' THEN 114.0579 WHEN '成都' THEN 104.0668 END;
UPDATE fh_user SET lat = lat + (id * 7 % 100) / 1200.0, lng = lng + (id * 13 % 100) / 1200.0;

INSERT INTO fh_member_product (tier, duration_days, price_cents, original_cents, first_price_cents, badge, sort_order) VALUES
(1, 30,  2800, 3800, 990,  '首月特惠', 1),
(1, 90,  6800, 8400, NULL, NULL, 2),
(1, 365, 16800, 33600, NULL, '最划算', 3),
(2, 30,  4800, 6800, 1900, '首月特惠', 4),
(2, 90,  12800, 14400, NULL, NULL, 5),
(2, 365, 28800, 57600, NULL, '最划算', 6);
