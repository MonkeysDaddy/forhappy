<script lang="ts" setup>
import { onMounted, ref } from 'vue';

import { Button, message, Modal, Select, Table } from 'ant-design-vue';

import { requestClient } from '#/api/request';
import { getViolationsApi } from '#/api/admin';

const loading = ref(true);
const items = ref<any[]>([]);
const total = ref(0);
const page = ref(1);
const typeFilter = ref<'' | 'chat' | 'moment'>('');

const columns = [
  { key: 'quickActions', title: '快捷处置', width: 150 },

  { dataIndex: 'id', title: 'ID', width: 70 },
  { dataIndex: 'nickname', key: 'user', title: '用户', width: 130 },
  { dataIndex: 'type', key: 'type', title: '来源', width: 90 },
  { dataIndex: 'hitWord', key: 'hit', title: '命中词', width: 120 },
  { dataIndex: 'content', key: 'content', title: '内容' },
  { dataIndex: 'createdAt', title: '时间', width: 170 },
];

async function load() {
  loading.value = true;
  try {
    const res = await getViolationsApi({
      limit: 20,
      offset: (page.value - 1) * 20,
      type: typeFilter.value || undefined,
    });
    items.value = res.items;
    total.value = res.total;
  } finally {
    loading.value = false;
  }
}

async function quickMute(userId: number) {
  await requestClient.put(`/users/${userId}/mute`, { days: 7 });
  message.success(`用户 #${userId} 已禁言 7 天`);
}

async function quickBan(userId: number) {
  Modal.confirm({
    title: `封禁用户 #${userId}？`,
    content: '封禁后无法登录且全站不可见',
    okText: '封禁',
    okType: 'danger',
    cancelText: '取消',
    onOk: async () => {
      await requestClient.put(`/users/${userId}/ban`);
      message.success('已封禁');
    },
  });
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <div class="mb-3 flex items-center gap-2">
      <Select
        v-model:value="typeFilter"
        allow-clear
        placeholder="全部来源"
        style="width: 140px"
        :options="[
          { label: '聊天', value: 'chat' },
          { label: '动态', value: 'moment' },
        ]"
        @change="() => { page = 1; load(); }"
      />
    </div>
    <Table
      :columns="columns"
      :data-source="items"
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
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'quickActions'">
          <Button size="small" @click="quickMute(record.userId)">
            禁言7天
          </Button>
          <Button danger size="small" type="link" @click="quickBan(record.userId)">
            封禁
          </Button>
        </template>
        <template v-else-if="column.key === 'user'">
          {{ record.nickname ?? `#${record.userId}` }}
        </template>
        <template v-else-if="column.key === 'type'">
          {{ record.type === 'chat' ? '聊天' : '动态' }}
        </template>
        <template v-else-if="column.key === 'hit'">
          <span class="font-semibold text-red-500">{{ record.hitWord }}</span>
        </template>
        <template v-else-if="column.key === 'content'">
          <span class="text-gray-400">{{ record.content }}</span>
        </template>
      </template>
    </Table>
  </div>
</template>
