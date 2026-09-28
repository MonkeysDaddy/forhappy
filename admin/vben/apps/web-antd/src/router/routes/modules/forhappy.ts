import type { RouteRecordRaw } from 'vue-router';

/** 管理后台菜单：按职能归类为五个一级分组 */

const routes: RouteRecordRaw[] = [
  // ---------- 数据看板 ----------
  {
    meta: {
      icon: 'lucide:layout-dashboard',
      order: -1,
      title: '数据看板',
    },
    name: 'DashboardGroup',
    path: '/admin-dash',
    children: [
      {
        name: 'AdminStats',
        path: '/admin/stats',
        component: () => import('#/views/admin/stats.vue'),
        meta: {
          affixTab: true,
          icon: 'lucide:gauge',
          title: '运营统计',
        },
      },
    ],
  },

  // ---------- 用户中心 ----------
  {
    meta: {
      icon: 'lucide:users',
      order: 0,
      title: '用户中心',
    },
    name: 'UserGroup',
    path: '/admin-user',
    children: [
      {
        name: 'AdminUsers',
        path: '/admin/users',
        component: () => import('#/views/admin/users.vue'),
        meta: {
          icon: 'lucide:user-round',
          title: '用户管理',
        },
      },
    ],
  },

  // ---------- 商业化管理 ----------
  {
    meta: {
      icon: 'lucide:gem',
      order: 1,
      title: '商业化管理',
    },
    name: 'CommerceGroup',
    path: '/admin-commerce',
    children: [
      {
        name: 'AdminProducts',
        path: '/admin/products',
        component: () => import('#/views/admin/products.vue'),
        meta: {
          icon: 'lucide:package',
          title: '订阅方案',
        },
      },
      {
        name: 'AdminOrders',
        path: '/admin/orders',
        component: () => import('#/views/admin/orders.vue'),
        meta: {
          icon: 'lucide:receipt-text',
          title: '订阅对账',
        },
      },
    ],
  },

  // ---------- 内容安全 ----------
  {
    meta: {
      icon: 'lucide:shield-check',
      order: 2,
      title: '内容安全',
    },
    name: 'ContentGroup',
    path: '/admin-content',
    children: [
      {
        name: 'AdminWords',
        path: '/admin/words',
        component: () => import('#/views/admin/words.vue'),
        meta: {
          icon: 'lucide:shield-ban',
          title: '敏感词库',
        },
      },
      {
        name: 'AdminViolations',
        path: '/admin/violations',
        component: () => import('#/views/admin/violations.vue'),
        meta: {
          icon: 'lucide:triangle-alert',
          title: '违规记录',
        },
      },
      {
        name: 'AdminReports',
        path: '/admin/reports',
        component: () => import('#/views/admin/reports.vue'),
        meta: {
          icon: 'lucide:flag',
          title: '举报处理',
        },
      },
    ],
  },

  // ---------- 运营推广 ----------
  {
    meta: {
      icon: 'lucide:megaphone',
      order: 3,
      title: '运营推广',
    },
    name: 'OpsGroup',
    path: '/admin-ops',
    children: [
      {
        name: 'AdminNotices',
        path: '/admin/notices',
        component: () => import('#/views/admin/notices.vue'),
        meta: {
          icon: 'lucide:bell-ring',
          title: '公告群发',
        },
      },
      {
        name: 'AdminAds',
        path: '/admin/ads',
        component: () => import('#/views/admin/ads.vue'),
        meta: {
          icon: 'lucide:megaphone',
          title: '广告投放',
        },
      },
      {
        name: 'AdminLogs',
        path: '/admin/logs',
        component: () => import('#/views/admin/logs.vue'),
        meta: {
          icon: 'lucide:scroll-text',
          title: '日志中心',
        },
      },
    ],
  },

  // ---------- 系统设置 ----------
  {
    meta: {
      icon: 'lucide:settings',
      order: 4,
      title: '系统设置',
    },
    name: 'SettingsGroup',
    path: '/admin-settings',
    children: [
      {
        name: 'AdminReviewQueue',
        path: '/admin/reviews',
        component: () => import('#/views/admin/reviews.vue'),
        meta: {
          icon: 'lucide:file-check-2',
          title: '审核队列',
        },
      },
      {
        name: 'AdminAccounts',
        path: '/admin/accounts',
        component: () => import('#/views/admin/accounts.vue'),
        meta: {
          icon: 'lucide:key-round',
          title: '管理员账号',
        },
      },
    ],
  },
];

export default routes;
