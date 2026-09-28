<script lang="ts" setup>
import { onMounted, ref } from 'vue';

import {
  Button,
  Card,
  Input,
  message,
  Table,
  Textarea,
} from 'ant-design-vue';

import { requestClient } from '#/api/request';

const title = ref('');
const content = ref('');
const target = ref('all');
const targetUserId = ref<undefined | number>(undefined);
const sending = ref(false);
const logs = ref<any[]>([]);
const logsLoading = ref(true);

const columns = [
  { dataIndex: 'id', title: 'ID', width: 70 },
  { dataIndex: 'detail', title: '详情' },
  { dataIndex: 'createdAt', title: '时间', width: 180 },
];

async function loadLogs() {
  logsLoading.value = true;
  try {
    const res = await requestClient.get<{
      items: any[];
      total: number;
    }>('/logs/admin', { params: { action: 'notice.send', limit: 10 } });
    logs.value = res.items;
  } finally {
    logsLoading.value = false;
  }
}

async function send() {
  if (!title.value.trim() || !content.value.trim()) {
    message.error('标题与内容不能为空');
    return;
  }
  sending.value = true;
  try {
    const res = await requestClient.post<{ sent: number }>('/notices', {
      content: content.value,
      title: title.value,
      target: target.value,
      userId: target.value === 'user' ? targetUserId.value : undefined,
    });
    message.success(`已群发给 ${res.sent} 位用户`);
    title.value = '';
    content.value = '';
    await loadLogs();
  } catch (e: any) {
    message.error(e?.response?.data?.msg ?? '发送失败');
  } finally {
    sending.value = false;
  }
}

onMounted(loadLogs);
</script>

<template>
  <div class="p-4">
    <Card class="mb-4">
      <div class="flex flex-col gap-3">
        <Select
          v-model:value="target"
          :options="[
            { label: '全部用户', value: 'all' },
            { label: '全部会员（VIP+SVIP）', value: 'member' },
            { label: '仅 VIP', value: 'vip' },
            { label: '仅 SVIP', value: 'svip' },
            { label: '指定用户（填用户 ID）', value: 'user' },
          ]"
        />
        <Input
          v-if="target === 'user'"
          v-model:value="targetUserId"
          placeholder="用户 ID"
          type="number"
        />
        <Input v-model:value="title" :maxlength="64" placeholder="公告标题" />
        <Textarea
          v-model:value="content"
          :maxlength="300"
          :rows="4"
          placeholder="公告内容"
          
        />
        <Button
          :loading="sending"
          class="self-start"
          type="primary"
          @click="send"
        >
          群发公告
        </Button>
      </div>
    </Card>
    <Card title="最近发送记录">
      <Table
        :columns="columns"
        :data-source="logs"
        :loading="logsLoading"
        :pagination="false"
        row-key="id"
        size="small"
      />
    </Card>
  </div>
</template>
