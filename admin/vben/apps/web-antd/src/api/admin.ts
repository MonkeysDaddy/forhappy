import { requestClient } from '#/api/request';

/** 运营统计（设计 7.3） */
export interface AdminStats {
  eventsToday: Array<{ event: string; count: number }>;
  likesToday: number;
  matches: number;
  paidOrders: number;
  reports: number;
  revenueCents: number;
  users: number;
}

/** 会员商品（含已下架） */
export interface AdminProduct {
  badge: null | string;
  durationDays: number;
  durationLabel: string;
  effectivePriceCents: number;
  firstPriceCents: null | number;
  id: number;
  originalCents: null | number;
  priceCents: number;
  sortOrder: number;
  status: number; // 1 上架 0 下架
  tier: number; // 1 VIP 2 SVIP
}

export function getStatsApi() {
  return requestClient.get<AdminStats>('/stats');
}

export function getProductsApi() {
  return requestClient.get<AdminProduct[]>('/products');
}

export function updateProductApi(
  id: number,
  body: Partial<{
    firstPriceCents: number;
    originalCents: number;
    priceCents: number;
    sortOrder: number;
    status: number;
  }>,
) {
  return requestClient.put(`/products/${id}`, body);
}

// ---------- 用户管理 ----------

export interface AdminUser {
  age: null | number;
  city: string;
  createdAt: string;
  eloScore: number;
  gender: number;
  id: number;
  memberExpireAt: null | string;
  memberTier: number;
  nickname: string;
  phone: string;
  status: number; // 1 正常 2 禁用 9 已删除
  verified: number;
}

export function getUsersApi(params: {
  limit?: number;
  offset?: number;
  q?: string;
  status?: number;
  tier?: number;
}) {
  return requestClient.get<{ items: AdminUser[]; total: number }>(
    '/users',
    { params },
  );
}

export function createUserApi(body: {
  city?: string;
  gender: number;
  nickname: string;
  phone: string;
}) {
  return requestClient.post('/users', body);
}

export function setUserStatusApi(id: number, status: 1 | 2) {
  return requestClient.put(`/users/${id}/status`, { status });
}

export function deleteUserApi(id: number) {
  return requestClient.delete(`/users/${id}`);
}

export function getUserDetailApi(id: number) {
  return requestClient.get<Record<string, any>>(`/users/${id}`);
}

// ---------- 订单 / 对账 ----------

export interface AdminOrder {
  amountCents: number;
  channel: number;
  createdAt: string;
  durationDays: null | number;
  nickname: null | string;
  orderNo: string;
  paidAt: null | string;
  status: number;
  tier: null | number;
  userId: number;
}

export function getOrdersApi(params: {
  limit?: number;
  offset?: number;
  status?: number;
  userId?: number;
}) {
  return requestClient.get<{ items: AdminOrder[]; total: number }>(
    '/orders',
    { params },
  );
}

export function getOrderSummaryApi() {
  return requestClient.get<{
    byStatus: Array<{ amountCents: number; cnt: number; status: number }>;
    last7Days: Array<{ amountCents: number; cnt: number; day: string }>;
  }>('/orders/summary');
}

// ---------- 日志 ----------

export function getEventLogsApi(params: {
  event?: string;
  limit?: number;
  offset?: number;
  userId?: number;
}) {
  return requestClient.get<{
    distinctEvents: string[];
    items: any[];
    total: number;
  }>('/logs/events', { params });
}

export function getAdminLogsApi(params: {
  action?: string;
  limit?: number;
  offset?: number;
}) {
  return requestClient.get<{ items: any[]; total: number }>('/logs/admin', {
    params,
  });
}

// ---------- 敏感词 ----------

export function getWordsApi() {
  return requestClient.get<
    Array<{ createdAt: string; id: number; word: string }>
  >('/words');
}

export function addWordApi(word: string) {
  return requestClient.post('/words', { word });
}

export function deleteWordApi(id: number) {
  return requestClient.delete(`/words/${id}`);
}

// ---------- 违规记录 ----------

export function getViolationsApi(params: {
  limit?: number;
  offset?: number;
  type?: string;
  userId?: number;
}) {
  return requestClient.get<{ items: any[]; total: number }>('/violations', {
    params,
  });
}

// ---------- 订阅方案 CRUD ----------

export interface ProductCreateBody {
  badge?: string;
  durationDays: number;
  firstPriceCents?: number;
  originalCents?: number;
  priceCents: number;
  sortOrder?: number;
  tier: number;
}

export function createProductApi(body: ProductCreateBody) {
  return requestClient.post('/products', body);
}

export function deleteProductApi(id: number) {
  return requestClient.delete(`/products/${id}`);
}
