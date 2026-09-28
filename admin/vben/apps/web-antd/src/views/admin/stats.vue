<script lang="ts" setup>
import type { AdminStats } from '#/api/admin';

import { onMounted, ref } from 'vue';

import { Card, Empty, message, Spin, Statistic, Table } from 'ant-design-vue';

import { getStatsApi } from '#/api/admin';

const loading = ref(true);
const stats = ref<AdminStats>();

const cards = ref<
  Array<{ label: string; sub?: string; value: string | number }[]>
>();

function yuan(cents?: number) {
  return `¥${((cents ?? 0) / 100).toFixed(2)}`;
}

const eventColumns = [
  { dataIndex: 'event', title: '事件' },
  { dataIndex: 'count', title: '次数', width: 120 },
];

async function load() {
  loading.value = true;
  try {
    stats.value = await getStatsApi();
    const s = stats.value;
    cards.value = [
      [
        { label: '注册用户', value: s.users },
        { label: '互相配对', value: s.matches },
        { label: '付费订单', value: s.paidOrders },
        { label: '订单收入', value: yuan(s.revenueCents) },
      ],
      [
        { label: '今日喜欢', value: s.likesToday },
        { label: '待处理举报', value: s.reports },
        {
          label: '今日埋点次数',
          value: (s.eventsToday ?? []).reduce((sum, e) => sum + e.count, 0),
        },
      ],
    ];
  } catch {
    message.error('统计加载失败，请确认后端已启动');
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <Spin :spinning="loading">
      <div
        v-for="(group, gi) in cards"
        :key="gi"
        class="mb-4 grid grid-cols-2 gap-4 lg:grid-cols-4"
      >
        <Card v-for="c in group" :key="c.label" class="shadow-sm">
          <Statistic :title="c.label" :value="c.value" />
        </Card>
      </div>

      <Card class="shadow-sm" title="今日埋点事件 Top">
        <Empty
          v-if="!stats?.eventsToday?.length"
          description="今天还没有埋点数据"
        />
        <Table
          v-else
          :columns="eventColumns"
          :data-source="stats.eventsToday"
          :pagination="false"
          row-key="event"
          size="small"
        />
      </Card>
    </Spin>
  </div>
</template>
