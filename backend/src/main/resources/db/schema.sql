-- ForHappy schema（表名前缀 fh_ 避开 MySQL 保留字：user/like/match 等）
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS fh_user (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  phone_hash    CHAR(64)  NOT NULL UNIQUE,
  phone_enc     VARCHAR(64) NOT NULL,
  nickname      VARCHAR(48) NOT NULL DEFAULT '',
  avatar_url    VARCHAR(255) NULL,
  gender        TINYINT NOT NULL DEFAULT 0 COMMENT '1男 2女',
  prefer_gender TINYINT NOT NULL DEFAULT 0 COMMENT '1男 2女 3都看',
  birthday      DATE NULL,
  city          VARCHAR(16) NOT NULL DEFAULT '',
  height_cm     SMALLINT NULL,
  weight_kg     SMALLINT NULL,
  education     VARCHAR(16) NULL,
  occupation    VARCHAR(64) NULL,
  income        VARCHAR(16) NULL COMMENT '年收入区间 key',
  bio           VARCHAR(600) NULL,
  tags          JSON NULL,
  verified      TINYINT NOT NULL DEFAULT 0,
  member_tier   TINYINT NOT NULL DEFAULT 0 COMMENT '0无 1VIP 2SVIP',
  member_expire_at DATETIME NULL,
  wechat        VARCHAR(64) NULL,
  instagram     VARCHAR(64) NULL,
  facebook      VARCHAR(64) NULL,
  lat           DOUBLE NULL,
  lng           DOUBLE NULL,
  last_active_minutes INT NOT NULL DEFAULT 0 COMMENT '演示用：距最后活跃分钟数',
  elo_score     INT NOT NULL DEFAULT 1200 COMMENT '互动先验分（设计5.2，男女分池简化为统一池）',
  hide_distance TINYINT NOT NULL DEFAULT 0 COMMENT '1=对他人隐藏精确距离',
  social_showcase JSON NULL COMMENT '社交账号展示 [{platform,account}]（需社交展示卡订阅）',
  mute_until DATETIME NULL COMMENT '禁言截止时间（分级处置）',
  social_expire_at DATETIME NULL COMMENT '社交展示卡到期时间',
  status        TINYINT NOT NULL DEFAULT 1,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 埋点事件（设计10.4 最小集）
CREATE TABLE IF NOT EXISTS fh_event (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT NOT NULL,
  event      VARCHAR(64) NOT NULL,
  props      JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_event (event),
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_photo (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id       BIGINT NOT NULL,
  url           VARCHAR(255) NOT NULL,
  sort_order    TINYINT NOT NULL DEFAULT 0,
  is_avatar     TINYINT NOT NULL DEFAULT 0,
  review_status TINYINT NOT NULL DEFAULT 1,
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_like (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  from_user  BIGINT NOT NULL,
  to_user    BIGINT NOT NULL,
  action     TINYINT NOT NULL COMMENT '1喜欢 2隐藏 3超级喜欢',
  matched    TINYINT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_from_to (from_user, to_user),
  KEY idx_to (to_user)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_match (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_lo     BIGINT NOT NULL,
  user_hi     BIGINT NOT NULL,
  status      TINYINT NOT NULL DEFAULT 1 COMMENT '1活跃 2解除',
  common_tags JSON NULL COMMENT '配对时计算的共同点（设计4.6）',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_pair (user_lo, user_hi)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_conversation (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  match_id     BIGINT NOT NULL UNIQUE,
  user_a       BIGINT NOT NULL,
  user_b       BIGINT NOT NULL,
  last_message VARCHAR(500) NOT NULL DEFAULT '',
  a_unread     INT NOT NULL DEFAULT 0,
  b_unread     INT NOT NULL DEFAULT 0,
  status       TINYINT NOT NULL DEFAULT 1,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_a (user_a), KEY idx_b (user_b)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_message (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  conv_id    BIGINT NOT NULL,
  from_user  BIGINT NOT NULL,
  type       TINYINT NOT NULL DEFAULT 1 COMMENT '1文本 2图片 3系统',
  content    TEXT NOT NULL,
  read_at    DATETIME NULL COMMENT '对方已读时间（已读回执，设计 4.8）',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_conv (conv_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_moment (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT NOT NULL,
  caption    VARCHAR(500) NOT NULL DEFAULT '',
  photos     JSON NOT NULL,
  likes_base INT NOT NULL DEFAULT 0 COMMENT '种子点赞数',
  status     TINYINT NOT NULL DEFAULT 0 COMMENT '0审核中 1通过 2驳回（先审后发）',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_moment_like (
  user_id   BIGINT NOT NULL,
  moment_id BIGINT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, moment_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_moment_comment (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  moment_id  BIGINT NOT NULL,
  user_id    BIGINT NOT NULL,
  content    VARCHAR(500) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_moment (moment_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_report (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  reporter    BIGINT NOT NULL,
  reported    BIGINT NOT NULL,
  category    TINYINT NOT NULL,
  description VARCHAR(500) NOT NULL DEFAULT '',
  status      TINYINT NOT NULL DEFAULT 0,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_block (
  blocker BIGINT NOT NULL,
  blocked BIGINT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (blocker, blocked)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_member_product (
  id                BIGINT PRIMARY KEY AUTO_INCREMENT,
  tier              TINYINT NOT NULL COMMENT '1VIP 2SVIP',
  duration_days     INT NOT NULL,
  duration_label    VARCHAR(32) NULL,
  price_cents       INT NOT NULL,
  original_cents    INT NULL,
  first_price_cents INT NULL,
  badge             VARCHAR(32) NULL,
  status            TINYINT NOT NULL DEFAULT 1,
  sort_order        TINYINT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_member_order (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_no    VARCHAR(32) NOT NULL UNIQUE,
  user_id     BIGINT NOT NULL,
  product_id  BIGINT NOT NULL,
  amount_cents INT NOT NULL,
  channel     TINYINT NOT NULL DEFAULT 1 COMMENT '1微信 2支付宝 3IAP 4赠送',
  status      TINYINT NOT NULL DEFAULT 0 COMMENT '0待支付 1已支付 2取消 3退款',
  paid_at     DATETIME NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 管理后台扩展（2026-09-27）：敏感词 / 违规记录 / 后台操作日志
CREATE TABLE IF NOT EXISTS fh_sensitive_word (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  word       VARCHAR(64) NOT NULL UNIQUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_violation (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT NOT NULL,
  type       VARCHAR(16) NOT NULL COMMENT 'chat/moment',
  content    VARCHAR(600) NOT NULL,
  hit_word   VARCHAR(64) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fh_admin_log (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  admin      VARCHAR(32) NOT NULL DEFAULT 'admin',
  action     VARCHAR(64) NOT NULL,
  detail     VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 通知中心（设计 4.7）：系统公告 / 配对 / 喜欢 / 到期提醒
CREATE TABLE IF NOT EXISTS fh_notification (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT NOT NULL,
  type       VARCHAR(16) NOT NULL DEFAULT 'system' COMMENT 'system/match/like/expiry',
  title      VARCHAR(64) NOT NULL,
  content    VARCHAR(300) NOT NULL DEFAULT '',
  read_at    DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 广告位（管理后台投放，App 端按位置拉取）
CREATE TABLE IF NOT EXISTS fh_ad (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  title      VARCHAR(64) NOT NULL,
  content    VARCHAR(300) NOT NULL DEFAULT '',
  image_url  VARCHAR(300) NULL,
  link_url   VARCHAR(300) NULL,
  position   VARCHAR(16) NOT NULL DEFAULT 'feed' COMMENT 'feed/discover_top',
  active     TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 管理员账号（RBAC：super 全部 / ops 商业化与运营 / reviewer 内容安全 / support 用户）
CREATE TABLE IF NOT EXISTS fh_admin_user (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  username      VARCHAR(32) NOT NULL UNIQUE,
  password_hash VARCHAR(64) NOT NULL COMMENT 'sha256(salt + password)',
  salt          VARCHAR(32) NOT NULL,
  role          VARCHAR(16) NOT NULL DEFAULT 'support',
  status        TINYINT NOT NULL DEFAULT 1,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE fh_admin_log ADD COLUMN ip VARCHAR(45) NULL AFTER admin;
