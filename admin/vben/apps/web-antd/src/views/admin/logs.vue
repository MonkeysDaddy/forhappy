<script lang="ts" setup>
import { onMounted, ref } from 'vue';

import { Button, Select, Table, TabPane, Tabs } from 'ant-design-vue';

import { getAdminLogsApi, getEventLogsApi } from '#/api/admin';

const activeTab = ref('events');
const eventsLoading = ref(true);
const events = ref<any[]>([]);
const eventTotal = ref(0);
const eventPage = ref(1);
const eventFilter = ref<undefined | string>(undefined);
const eventOptions = ref<string[]>([]);
const adminLogs = ref<any[]>([]);
const adminTotal = ref(0);
const adminPage = ref(1);

const eventColumns = [
  { dataIndex: 'id', title: 'ID', width: 70 },
  { dataIndex: 'nickname', title: '用户', width: 120 },
  { dataIndex: 'event', title: '事件', width: 160 },
  { dataIndex: 'props', key: 'props', title: '参数' },
  { dataIndex: 'createdAt', title: '时间', width: 170 },
];
const adminColumns = [
  { dataIndex: 'id', title: 'ID', width: 70 },
  { dataIndex: 'admin', title: '操作人', width: 100 },
  { dataIndex: 'action', title: '动作', width: 160 },
  { dataIndex: 'detail', title: '详情' },
  { dataIndex: 'createdAt', title: '时间', width: 170 },
];

async function loadEvents() {
  eventsLoading.value = true;
  try {
    const res = await getEventLogsApi({
    event: eventFilter.value,
    limit: 20,
    offset: (eventPage.value - 1) * 20,
    userId: undefined,
  });
    events.value = res.items;
    eventTotal.value = res.total;
    if (res.distinctEvents?.length) eventOptions.value = res.distinctEvents;
  } finally {
    eventsLoading.value = false;
  }
}

async function loadAdminLogs() {
  const res = await getAdminLogsApi({
    limit: 20,
    offset: (adminPage.value - 1) * 20,
  });
  adminLogs.value = res.items;
  adminTotal.value = res.total;
}

onMounted(loadEvents);
</script>

<template>
  <div class="p-4">
    <Tabs v-model:active-key="activeTab" @change="(k: any) => k === 'admin' && loadAdminLogs()">
      <TabPane key="events" tab="行为埋点">
        <div class="mb-3 flex items-center gap-2">
          <Select
            v-model:value="eventFilter"
            allow-clear
            placeholder="按事件筛选"
            style="width: 220px"
            :options="eventOptions.map((e) => ({ label: e, value: e }))"
          />
          <Button type="primary" @click="loadEvents()">查询</Button>
        </div>
        <Table
          :columns="eventColumns"
          :data-source="events"
          :loading="eventsLoading"
          :pagination="{
            current: eventPage,
            total: eventTotal,
            pageSize: 20,
            showSizeChanger: false,
          }"
          row-key="id"
          size="middle"
          @change="(p: any) => { eventPage = p.current; loadEvents(); }"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'props'">
              <span class="text-xs text-gray-400">
                {{ record.props && record.props !== 'null' ? record.props : '—' }}
              </span>
            </template>
          </template>
        </Table>
      </TabPane>
      <TabPane key="admin" tab="后台操作日志">
        <Table
          :columns="adminColumns"
          :data-source="adminLogs"
          :pagination="{
            current: adminPage,
            total: adminTotal,
            pageSize: 20,
            showSizeChanger: false,
          }"
          row-key="id"
          size="middle"
          @change="(p: any) => { adminPage = p.current; loadAdminLogs(); }"
        />
      </TabPane>
    </Tabs>
  </div>
</template>
