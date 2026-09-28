<script lang="ts" setup>
import { onMounted, ref } from 'vue';

import {
  Drawer,
  message,
  Modal,
  Select,
  Table,
  Tag,
} from 'ant-design-vue';

import { requestClient } from '#/api/request';

interface Report {
  category: number;
  description: string;
  id: number;
  reported: number;
  reportedName: null | string;
  reporter: number;
  reporterName: null | string;
  status: number;
  createdAt: string;
}

const loading = ref(true);
const reports = ref<Report[]>([]);
const total = ref(0);
const statusFilter = ref<undefined | number>(undefined);

const chatOpen = ref(false);
const chatLoading = ref(false);
const chatMessages = ref<any[]>([]);
const chatReporterId = ref<number>(0);
const chatTarget = ref('');

const chatColumns = [
  { dataIndex: 'fromUser', key: 'fromUser', title: '发送方', width: 80 },
  { dataIndex: 'content', key: 'content', title: '内容' },
  { dataIndex: 'createdAt', title: '时间', width: 170 },
];

const columns = [
  { dataIndex: 'id', title: 'ID', width: 60 },
  { dataIndex: 'reporterName', key: 'reporter', title: '举报人', width: 110 },
  { dataIndex: 'reportedName', key: 'reported', title: '被举报人', width: 110 },
  { dataIndex: 'category', key: 'category', title: '类型', width: 90 },
  { dataIndex: 'description', title: '描述' },
  { dataIndex: 'status', key: 'status', title: '状态', width: 90 },
  { key: 'actions', title: '操作', width: 220 },
];

const categoryText: Record<number, string> = {
  1: '虚假资料',
  2: '骚扰行为',
  3: '违规内容',
  4: '其他',
};

async function load() {
  loading.value = true;
  try {
    const res = await requestClient.get<{
      items: Report[];
      total: number;
    }>('/reports', { params: {
      limit: 20,
      offset: 0,
      status: statusFilter.value,
    } });
    reports.value = res.items;
    total.value = res.total;
  } finally {
    loading.value = false;
  }
}

async function loadChat(record: Report) {
  chatTarget.value = `${record.reporterName ?? record.reporter} ↔ ${record.reportedName ?? record.reported}`;
  chatReporterId.value = record.reporter;
  chatOpen.value = true;
  chatLoading.value = true;
  try {
    chatMessages.value = await requestClient.get<any[]>(
      `/reports/${record.id}/chat`,
    );
  } catch (_) {
    chatMessages.value = [];
  } finally {
    chatLoading.value = false;
  }
}

async function handle(record: Report, action: 1 | 2) {
  await requestClient.put(`/reports/${record.id}/handle`, { action });
  message.success(action === 2 ? '已核实，被举报人已禁用' : '已驳回');
  await load();
}

function handleConfirm(record: Report, action: 1 | 2) {
  if (action === 2) {
    Modal.confirm({
      title: `核实举报 #${record.id}？`,
      content: `确认后将被举报人 ${record.reportedName ?? record.reported} 禁用`,
      okText: '确认禁用',
      okType: 'danger',
      cancelText: '取消',
      onOk: () => handle(record, 2),
    });
  } else {
    handle(record, 1);
  }
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <div class="mb-3 flex items-center gap-2">
      <Select
        v-model:value="statusFilter"
        allow-clear
        placeholder="全部状态"
        style="width: 140px"
        :options="[
          { label: '待处理', value: 0 },
          { label: '已驳回', value: 1 },
          { label: '已处理', value: 2 },
        ]"
        @change="load"
      />
    </div>
    <Table
      :columns="columns"
      :data-source="reports"
      :loading="loading"
      :pagination="{ pageSize: 20 }"
      row-key="id"
      size="middle"
    >
      <template #bodyCell="{ column, record }: { column: any; record: any }">
        <template v-if="column.key === 'category'">
          {{ categoryText[record.category] ?? record.category }}
        </template>
        <template v-else-if="column.key === 'status'">
          <Tag
            :color="
              record.status === 0
                ? 'orange'
                : record.status === 2
                  ? 'green'
                  : 'default'
            "
          >
            {{
              record.status === 0
                ? '待处理'
                : record.status === 2
                  ? '已核实'
                  : '已驳回'
            }}
          </Tag>
        </template>
        <template v-else-if="column.key === 'actions'">
          <Button size="small" type="link" @click="loadChat(record)">
            聊天取证
          </Button>
          <template v-if="record.status === 0">
            <Button size="small" @click="handleConfirm(record, 1)">驳回</Button>
            <Button
              danger
              size="small"
              type="link"
              @click="handleConfirm(record, 2)"
            >
              核实禁用
            </Button>
          </template>
          <span v-else class="text-gray-400">已处理</span>
        </template>
      </template>
    </Table>

    <Drawer
      v-model:open="chatOpen"
      :title="`聊天取证 · ${chatTarget}`"
      placement="right"
      width="480"
    >
      <a-spin :spinning="chatLoading">
        <a-empty v-if="!chatMessages.length" description="两人之间没有会话记录" />
        <Table
          v-else
          :columns="chatColumns"
          :data-source="chatMessages"
          :pagination="{ pageSize: 20 }"
          row-key="id"
          size="small"
        >
          <template #bodyCell="{ column, record }: { column: any; record: any }">
            <template v-if="column.key === 'fromUser'">
              {{ record.fromUser === chatReporterId ? '举报人' : '被举报人' }}
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
      </a-spin>
    </Drawer>
  </div>
</template>
