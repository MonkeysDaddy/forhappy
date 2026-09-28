<script lang="ts" setup>
import type { AdminUser } from '#/api/admin';

import { onMounted, ref } from 'vue';

import {
  Avatar,
  Button,
  Drawer,
  Dropdown,
  Image as AImage,
  Input,
  Menu,
  MenuItem,
  message,
  Modal,
  Descriptions,
  DescriptionsItem,
  Select,
  Statistic,
  Table,
  Tag,
} from 'ant-design-vue';

import { requestClient } from '#/api/request';
import {
  createUserApi,
  deleteUserApi,
  getUserDetailApi,
  getUsersApi,
  setUserStatusApi,
} from '#/api/admin';

const loading = ref(true);
const users = ref<AdminUser[]>([]);
const total = ref(0);
const page = ref(1);
const q = ref('');
const statusFilter = ref<undefined | number>(undefined);
const tierFilter = ref<undefined | number>(undefined);

const statusText: Record<number, { color: string; label: string }> = {
  1: { color: 'green', label: '正常' },
  2: { color: 'red', label: '已禁用' },
  3: { color: 'red', label: '已封禁' },
  9: { color: 'default', label: '已删除' },
};
const tierText: Record<number, string> = { 1: 'VIP', 2: 'SVIP' };

const columns = [
  { dataIndex: 'avatarUrl', key: 'avatar', title: '', width: 56 },
  { dataIndex: 'id', title: 'ID', key: 'id', width: 60 },
  { dataIndex: 'nickname', title: '昵称', key: 'nickname' },
  { dataIndex: 'phone', title: '手机号', key: 'phone', width: 130 },
  { dataIndex: 'gender', title: '性别', key: 'gender', width: 70 },
  { dataIndex: 'memberTier', title: '会员', key: 'memberTier', width: 160 },
  { dataIndex: 'status', title: '状态', key: 'status', width: 90 },
  { dataIndex: 'createdAt', title: '注册时间', key: 'createdAt', width: 110 },
  { key: 'actions', title: '操作', width: 210 },
];

const orderColumns = [
  { dataIndex: 'orderNo', title: '订单号' },
  { dataIndex: 'amountCents', key: 'amountCents', title: '金额', width: 90 },
  { dataIndex: 'status', key: 'status', title: '状态', width: 80 },
];

const chatColumns = [
  { dataIndex: 'fromUser', key: 'fromUser', title: '发送方', width: 70 },
  { dataIndex: 'content', key: 'content', title: '内容' },
  { dataIndex: 'createdAt', title: '时间', width: 160 },
];

const detailOpen = ref(false);
const detail = ref<Record<string, any>>();
const detailOrders = ref<any[]>([]);
const detailPhotos = ref<any[]>([]);
const detailChat = ref<Array<{
  content: string;
  fromUser: number;
  id: number;
}>>([]);

const createOpen = ref(false);
const creating = ref(false);
const createForm = ref({ city: '杭州', gender: 2, nickname: '', phone: '' });

async function load() {
  loading.value = true;
  try {
    const res = await getUsersApi({
      limit: 20,
      offset: (page.value - 1) * 20,
      q: q.value || undefined,
      status: statusFilter.value,
      tier: tierFilter.value,
    });
    users.value = res.items;
    total.value = res.total;
  } finally {
    loading.value = false;
  }
}

function search() {
  page.value = 1;
  load();
}

async function openDetail(record: AdminUser) {
  detail.value = await getUserDetailApi(record.id);
  detailOrders.value = (detail.value?.orders ?? []) as any[];
  detailPhotos.value = (detail.value?.photos ?? []) as any[];
  detailChat.value = [];
  try {
    const convs = await requestClient.get<any[]>(`/chats/of-user/${record.id}`);
    if (convs?.length) {
      const messages = await requestClient.get<any[]>(
        `/chats/${convs[0].id}/messages`,
      );
      detailChat.value = messages.slice(-30).reverse();
    }
  } catch (_) {
    // 聊天取证失败不阻塞详情
  }
  detailOpen.value = true;
}

function toggleStatus(record: AdminUser) {
  const disable = record.status === 1;
  Modal.confirm({
    title: disable ? `禁用 ${record.nickname}？` : `启用 ${record.nickname}？`,
    content: disable
      ? '禁用后该用户无法登录，且从信息流中消失'
      : '启用后恢复正常使用',
    okText: disable ? '禁用' : '启用',
    cancelText: '取消',
    onOk: async () => {
      await setUserStatusApi(record.id, disable ? 2 : 1);
      message.success(disable ? '已禁用' : '已启用');
      await load();
    },
  });
}

async function muteUser(record: AdminUser, days: number) {
  await requestClient.put(`/users/${record.id}/mute`, { days });
  message.success(`已禁言 ${days} 天`);
  await load();
}

async function unmuteUser(record: AdminUser) {
  await requestClient.put(`/users/${record.id}/unmute`);
  message.success('已解除禁言');
  await load();
}

async function banUser(record: AdminUser) {
  Modal.confirm({
    title: `封禁 ${record.nickname}？`,
    content: '封禁后无法登录且全站不可见',
    okText: '封禁',
    okType: 'danger',
    cancelText: '取消',
    onOk: async () => {
      await requestClient.put(`/users/${record.id}/ban`);
      message.success('已封禁');
      await load();
    },
  });
}

function removeUser(record: AdminUser) {
  Modal.confirm({
    title: `删除 ${record.nickname}？`,
    content: '匿名化软删：该用户无法登录且全站不可见，手机号将被释放可重新注册',
    okText: '删除',
    okType: 'danger',
    cancelText: '取消',
    onOk: async () => {
      await deleteUserApi(record.id);
      message.success('已删除（匿名化）');
      await load();
    },
  });
}

async function grantMembership(record: any, tier: number, days: number) {
  await requestClient.put(`/users/${record.id}/membership`, { days, tier });
  message.success(`已开通 ${tierText[tier]} ${days} 天`);
  await load();
}

function createUser() {
  createOpen.value = true;
}

async function submitCreate() {
  creating.value = true;
  try {
    await createUserApi(createForm.value);
    message.success('创建成功，用户可用手机号+验证码登录');
    createOpen.value = false;
    createForm.value = { city: '杭州', gender: 2, nickname: '', phone: '' };
    await load();
  } catch (e: any) {
    message.error(e?.response?.data?.msg ?? '创建失败');
    throw e;
  } finally {
    creating.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <div class="mb-4 flex flex-wrap items-center gap-2">
      <Input
        v-model:value="q"
        allow-clear
        placeholder="昵称 / 完整手机号"
        style="width: 200px"
        @press-enter="search"
      />
      <Select
        v-model:value="statusFilter"
        allow-clear
        placeholder="状态"
        style="width: 120px"
        :options="[
          { label: '正常', value: 1 },
          { label: '已禁用', value: 2 },
        ]"
      />
      <Select
        v-model:value="tierFilter"
        allow-clear
        placeholder="会员档位"
        style="width: 120px"
        :options="[
          { label: 'VIP', value: 1 },
          { label: 'SVIP', value: 2 },
        ]"
      />
      <Button type="primary" @click="search">查询</Button>
      <div class="flex-1"></div>
      <Button type="primary" @click="createUser">+ 创建用户</Button>
    </div>

    <Table
      :columns="columns"
      :data-source="users"
      :loading="loading"
      :pagination="{
        current: page,
        total,
        pageSize: 20,
        showSizeChanger: false,
      }"
      row-key="id"
      size="middle"
      @change="(p: any) => { page = p.current; load(); }"
    >
      <template #bodyCell="{ column, record }: { column: any; record: any }">
        <template v-if="column.key === 'avatar'">
          <Avatar :src="record.avatarUrl" style="background: #f0f0f0; color: #999">
            {{ (record.nickname || '?').slice(0, 1) }}
          </Avatar>
        </template>
        <template v-else-if="column.key === 'gender'">
          {{ record.gender === 1 ? '男' : record.gender === 2 ? '女' : '—' }}
        </template>
        <template v-else-if="column.key === 'memberTier'">
          <template v-if="record.memberTier === 1 || record.memberTier === 2">
            <Tag :color="record.memberTier === 2 ? 'gold' : 'volcano'">
              {{ tierText[record.memberTier] }}
            </Tag>
            <span v-if="record.memberExpireAt" class="text-xs text-gray-400">
              {{ String(record.memberExpireAt).slice(0, 10) }} 到期
            </span>
          </template>
          <span v-else class="text-gray-400">—</span>
        </template>
        <template v-else-if="column.key === 'status'">
          <Tag :color="statusText[record.status]?.color ?? 'default'">
            {{ statusText[record.status]?.label ?? record.status }}
          </Tag>
        </template>
        <template v-else-if="column.key === 'createdAt'">
          {{ String(record.createdAt).slice(5, 16).replace('T', ' ') }}
        </template>
        <template v-else-if="column.key === 'actions'">
          <Button size="small" type="link" @click="openDetail(record)">
            详情
          </Button>
          <Button
            v-if="record.status === 1"
            size="small"
            type="link"
            @click="toggleStatus(record)"
          >
            禁用
          </Button>
          <Button
            v-else-if="record.status === 2"
            size="small"
            type="link"
            @click="toggleStatus(record)"
          >
            启用
          </Button>
          <Dropdown>
            <Button size="small" type="link">更多</Button>
            <template #overlay>
              <Menu>
                <MenuItem @click="muteUser(record, 3)">禁言 3 天</MenuItem>
                <MenuItem @click="muteUser(record, 7)">禁言 7 天</MenuItem>
                <MenuItem @click="muteUser(record, 30)">禁言 30 天</MenuItem>
                <MenuItem v-if="record.muteUntil" @click="unmuteUser(record)">
                  解除禁言
                </MenuItem>
                <MenuItem danger @click="banUser(record)">封禁账号</MenuItem>
                <MenuItem danger @click="removeUser(record)">删除</MenuItem>
              </Menu>
            </template>
          </Dropdown>
        </template>
      </template>
    </Table>

    <Drawer
      v-model:open="detailOpen"
      :title="detail?.nickname ?? '用户详情'"
      placement="right"
      width="520"
    >
      <template v-if="detail">
        <div class="mb-4 flex items-center gap-3">
          <Avatar :src="detail.avatarUrl" :size="56" style="background: #f0f0f0; color: #999">
            {{ (detail.nickname || '?').slice(0, 1) }}
          </Avatar>
          <div>
            <div class="flex items-center gap-1 font-semibold">
              {{ detail.nickname }}
              <Tag v-if="detail.memberTier === 1 || detail.memberTier === 2"
                :color="detail.memberTier === 2 ? 'gold' : 'volcano'">
                {{ tierText[detail.memberTier] }}
              </Tag>
              <Tag v-if="detail.verified === 1" color="blue">已认证</Tag>
            </div>
            <div class="text-xs text-gray-400">
              {{ detail.phone }} · {{ detail.city }}
            </div>
          </div>
        </div>

        <div class="mb-4 grid grid-cols-3 gap-2">
          <Statistic title="送出的喜欢" :value="detail.likesGiven" />
          <Statistic title="收到的喜欢" :value="detail.likesReceived" />
          <Statistic title="动态数" :value="detail.moments" />
        </div>

        <div class="mb-2 mt-4 font-semibold">订阅与会员调整</div>
        <Descriptions :column="1" bordered size="small" class="mb-2">
          <DescriptionsItem label="当前方案">
            {{
              detail.memberTier === 1
                ? 'VIP'
                : detail.memberTier === 2
                  ? 'SVIP'
                  : '免费用户'
            }}
            <template v-if="detail.memberExpireAt">
              （{{ String(detail.memberExpireAt).slice(0, 10) }} 到期）
            </template>
          </DescriptionsItem>
        </Descriptions>
        <div class="mb-4 flex gap-2">
          <Button size="small" @click="grantMembership(detail, 1, 30)">
            送 VIP 30 天
          </Button>
          <Button size="small" @click="grantMembership(detail, 2, 30)">
            送 SVIP 30 天
          </Button>
          <Button
            v-if="detail.memberTier !== 0"
            danger
            size="small"
            @click="grantMembership(detail, 0, 0)"
          >
            取消会员
          </Button>
        </div>

        <div class="mb-2 mt-4 font-semibold">照片墙（含审核状态）</div>
        <div class="mb-2 flex flex-wrap gap-2">
          <div v-for="ph in detailPhotos" :key="ph.id" class="relative">
            <AImage
              :src="ph.url"
              :width="88"
              :height="88"
              style="object-fit: cover; border-radius: 6px"
            />
            <Tag
              v-if="ph.reviewStatus === 0"
              class="absolute left-1 top-1"
              color="orange"
            >
              审核中
            </Tag>
          </div>
          <span v-if="!detailPhotos.length" class="text-gray-400">暂无照片</span>
        </div>

        <div class="mb-2 mt-4 font-semibold">最近聊天（最后 30 条，举报核实用）</div>
        <Table
          :columns="chatColumns"
          :data-source="detailChat"
          :pagination="false"
          row-key="id"
          size="small"
        >
          <template #bodyCell="{ column, record }: { column: any; record: any }">
            <template v-if="column.key === 'fromUser'">
              {{ record.fromUser === detail.id ? '本人' : '对方' }}
            </template>
            <template v-else-if="column.key === 'content'">
              <span
                :class="record.content?.startsWith('/') ? 'text-gray-400' : ''"
              >
                {{
                  record.type === 2
                    ? '[图片]'
                    : record.type === 3
                      ? '[语音]'
                      : record.content
                }}
              </span>
            </template>
          </template>
        </Table>

        <div class="mb-2 mt-4 font-semibold">消费记录</div>
        <Table
          :columns="orderColumns"
          :data-source="detailOrders"
          :pagination="false"
          row-key="id"
          size="small"
        >
          <template #bodyCell="{ column, record }: { column: any; record: any }">
            <template v-if="column.key === 'amountCents'">
              ¥{{ (record.amountCents / 100).toFixed(2) }}
            </template>
            <template v-else-if="column.key === 'status'">
              {{ record.status === 1 ? '已支付' : record.status }}
            </template>
          </template>
        </Table>
      </template>
    </Drawer>

    <Modal
      v-model:open="createOpen"
      :confirm-loading="creating"
      title="创建用户"
      ok-text="创建"
      cancel-text="取消"
      @ok="submitCreate"
    >
      <div class="flex flex-col gap-3 pt-2">
        <Input v-model:value="createForm.phone" placeholder="手机号（11 位）" />
        <Input v-model:value="createForm.nickname" placeholder="昵称（2-12 字）" />
        <Select
          v-model:value="createForm.gender"
          :options="[
            { label: '女', value: 2 },
            { label: '男', value: 1 },
          ]"
        />
        <Input v-model:value="createForm.city" placeholder="城市（默认杭州）" />
        <div class="text-xs text-gray-400">
          用户使用手机号 + 验证码登录（演示环境验证码固定 123456）
        </div>
      </div>
    </Modal>
  </div>
</template>
