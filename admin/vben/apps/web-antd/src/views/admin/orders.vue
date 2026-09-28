<script lang="ts" setup>
import type { AdminOrder } from '#/api/admin';

import { onMounted, ref } from 'vue';

import { Button, Card, Input, message, Modal, Select, Statistic, Table, Tag } from 'ant-design-vue';

import { requestClient } from '#/api/request';
import { getOrderSummaryApi, getOrdersApi } from '#/api/admin';

const loading = ref(true);
const orders = ref<AdminOrder[]>([]);
const total = ref(0);
const page = ref(1);
const userId = ref<undefined | number>(undefined);
const statusFilter = ref<undefined | number>(undefined);
const byStatus = ref<Array<{ amountCents: number; cnt: number; status: number }>>(
  [],
);

const statusMap: Record<number, { color: string; label: string }> = {
  0: { color: 'default', label: '待支付' },
  1: { color: 'green', label: '已支付' },
  2: { color: 'default', label: '已取消' },
  3: { color: 'red', label: '已退款' },
};
const channelMap: Record<number, string> = {
  1: '微信',
  2: '支付宝',
  3: 'IAP',
  4: '赠送',
};

const summaryPaid = ref({ amountCents: 0, cnt: 0 });
const summaryPending = ref({ amountCents: 0, cnt: 0 });

const columns = [
  { dataIndex: 'orderNo', title: '订单号', width: 190 },
  { dataIndex: 'nickname', title: '用户', width: 110 },
  { dataIndex: 'tier', key: 'plan', title: '方案', width: 110 },
  { dataIndex: 'amountCents', key: 'amount', title: '金额', width: 90 },
  { dataIndex: 'channel', key: 'channel', title: '渠道', width: 80 },
  { dataIndex: 'status', key: 'status', title: '状态', width: 90 },
  { dataIndex: 'createdAt', key: 'createdAt', title: '创建时间', width: 160 },
  { dataIndex: 'paidAt', key: 'paidAt', title: '支付时间', width: 160 },
  { key: 'actions', title: '操作', width: 90 },
];

function refundOrder(record: any) {
  Modal.confirm({
    title: `订单 ${record.orderNo.slice(0, 12)}… 退款？`,
    content: `退款 ¥${(record.amountCents / 100).toFixed(2)} 将原路退回，并通知用户`,
    okText: '确认退款',
    okType: 'danger',
    cancelText: '取消',
    onOk: async () => {
      await requestClient.put(`/orders/${record.orderNo}/refund`);
      message.success('已退款并通知用户');
      await load();
    },
  });
}

async function load() {
  loading.value = true;
  try {
    const [ordersRes, summary] = await Promise.all([
      getOrdersApi({
        limit: 20,
        offset: (page.value - 1) * 20,
        status: statusFilter.value,
        userId: userId.value,
      }),
      getOrderSummaryApi(),
    ]);
    orders.value = ordersRes.items;
    total.value = ordersRes.total;
    byStatus.value = summary.byStatus;
    summaryPaid.value =
      summary.byStatus.find((s) => s.status === 1) ??
      ({ amountCents: 0, cnt: 0 } as any);
    summaryPending.value =
      summary.byStatus.find((s) => s.status === 0) ??
      ({ amountCents: 0, cnt: 0 } as any);
  } finally {
    loading.value = false;
  }
}

function search() {
  page.value = 1;
  load();
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <div class="mb-4 grid grid-cols-2 gap-4 lg:grid-cols-4">
      <Card>
        <Statistic
          :title="`已支付收入（${summaryPaid.cnt} 笔）`"
          :value="`¥${(summaryPaid.amountCents / 100).toFixed(2)}`"
        />
      </Card>
      <Card>
        <Statistic
          :title="`待支付（${summaryPending.cnt} 笔）`"
          :value="`¥${(summaryPending.amountCents / 100).toFixed(2)}`"
        />
      </Card>
    </div>


    <div class="mb-3 flex flex-wrap items-center gap-2">
      <Input
        v-model:value="userId"
        allow-clear
        placeholder="用户 ID"
        style="width: 140px"
        @press-enter="search"
      />
      <Select
        v-model:value="statusFilter"
        allow-clear
        placeholder="订单状态"
        style="width: 130px"
        :options="[
          { label: '待支付', value: 0 },
          { label: '已支付', value: 1 },
          { label: '已取消', value: 2 },
          { label: '已退款', value: 3 },
        ]"
      />
      <Button type="primary" @click="search">查询</Button>
    </div>

    <Table
      :columns="columns"
      :data-source="orders"
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
        <template v-if="column.key === 'plan'">
          <template v-if="record.tier">
            {{ record.tier === 2 ? 'SVIP' : 'VIP' }} ·
            {{ record.durationDays }}天
          </template>
          <span v-else class="text-gray-400">方案已删</span>
        </template>
        <template v-else-if="column.key === 'amount'">
          ¥{{ (record.amountCents / 100).toFixed(2) }}
        </template>
        <template v-else-if="column.key === 'channel'">
          {{ channelMap[record.channel] ?? record.channel }}
        </template>
        <template v-else-if="column.key === 'status'">
          <Tag :color="statusMap[record.status]?.color">
            {{ statusMap[record.status]?.label ?? record.status }}
          </Tag>
        </template>
        <template v-else-if="column.key === 'actions'">
          <Button
            v-if="record.status === 1"
            danger
            size="small"
            @click="refundOrder(record)"
          >
            退款
          </Button>
        </template>
      </template>
    </Table>
  </div>
</template>

<script lang="ts">

</script>
