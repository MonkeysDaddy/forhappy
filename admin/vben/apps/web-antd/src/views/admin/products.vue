<script lang="ts" setup>
import type { AdminProduct } from '#/api/admin';

import { onMounted, ref } from 'vue';

import {
  Button,
  message,
  Modal,
  Table,
  Tag,
} from 'ant-design-vue';

import { createProductApi, deleteProductApi, getProductsApi, updateProductApi } from '#/api/admin';

const loading = ref(true);
const products = ref<AdminProduct[]>([]);
const createOpen = ref(false);
const creating = ref(false);
const createForm = ref({
  badge: '' as string | undefined,
  durationDays: 30,
  firstPriceCents: undefined as number | undefined,
  originalCents: undefined as number | undefined,
  priceCents: undefined as number | undefined,
  tier: 1,
});

function openCreate() {
  createForm.value = {
    badge: '',
    durationDays: 30,
    firstPriceCents: undefined,
    originalCents: undefined,
    priceCents: undefined,
    tier: 1,
  };
  createOpen.value = true;
}

async function submitCreate() {
  const f = createForm.value;
  if (!f.priceCents || f.priceCents <= 0) {
    message.error('请填写现价（分）');
    return;
  }
  creating.value = true;
  try {
    await createProductApi({
      badge: f.badge || undefined,
      durationDays: f.durationDays,
      firstPriceCents: f.firstPriceCents,
      originalCents: f.originalCents,
      priceCents: f.priceCents,
      tier: f.tier,
    });
    message.success('方案已创建');
    createOpen.value = false;
    await load();
  } catch (e: any) {
    message.error(e?.response?.data?.msg ?? '创建失败');
  } finally {
    creating.value = false;
  }
}

function removeProduct(record: AdminProduct) {
  Modal.confirm({
    title: `删除方案 ${tierLabel(record.tier)} ${record.durationLabel}？`,
    content: '仅可删除没有订单记录的方案',
    okText: '删除',
    okType: 'danger',
    cancelText: '取消',
    onOk: async () => {
      await deleteProductApi(record.id);
      message.success('已删除');
      await load();
    },
  });
}

const columns = [
  { title: '档位', key: 'tier', width: 80 },
  { title: '时长', key: 'durationLabel', width: 100 },
  { title: '现价', key: 'priceCents' },
  { title: '原价', key: 'originalCents' },
  { title: '首月价', key: 'firstPriceCents' },
  { title: '状态', key: 'status', width: 100 },
  { title: '操作', key: 'actions', width: 90 },
];

const tierLabel = (tier: number) => (tier === 2 ? 'SVIP' : 'VIP');
const yuan = (cents?: null | number) =>
  cents == null ? '—' : `¥${(cents / 100).toFixed(2)}`;

async function load() {
  loading.value = true;
  try {
    products.value = await getProductsApi();
  } catch {
    message.error('商品加载失败，请确认后端已启动');
  } finally {
    loading.value = false;
  }
}

function editPrice(
  record: AdminProduct,
  field: 'first' | 'original' | 'price',
) {
  const label =
    field === 'price' ? '现价' : field === 'original' ? '原价' : '首月价';
  const current =
    field === 'price'
      ? record.priceCents
      : field === 'original'
        ? record.originalCents
        : record.firstPriceCents;
  Modal.confirm({
    icon: undefined,
    okText: '保存',
    title: `修改${label} · ${tierLabel(record.tier)} ${record.durationLabel}`,
    content: `<input id="fh-price-input" type="number" min="0" step="1" value="${current ?? ''}" style="width:100%;padding:6px 10px;border:1px solid #d9d9d9;border-radius:6px" placeholder="单位：分（如 1800 = ¥18.00）" />`,
    onOk: async () => {
      const el = document.querySelector<HTMLInputElement>('#fh-price-input');
      const raw = el?.value?.trim();
      if (raw === '' || Number.isNaN(Number(raw))) {
        message.error('请输入有效金额（分）');
        return Promise.reject();
      }
      const cents = Math.round(Number(raw));
      const body =
        field === 'price'
          ? { priceCents: cents }
          : field === 'original'
            ? { originalCents: cents }
            : { firstPriceCents: cents };
      await updateProductApi(record.id, body);
      message.success('已保存，新价格即时生效于新订单');
      await load();
    },
  });
}

function toggleStatus(record: AdminProduct) {
  const next = record.status === 1 ? 0 : 1;
  Modal.confirm({
    title: next === 1 ? '上架该商品？' : '下架该商品？',
    content:
      next === 1
        ? '上架后用户端收银台立即可见'
        : '下架后用户端收银台不再展示（已下单不受影响）',
    okText: next === 1 ? '上架' : '下架',
    cancelText: '取消',
    onOk: async () => {
      await updateProductApi(record.id, { status: next });
      message.success(next === 1 ? '已上架' : '已下架');
      await load();
    },
  });
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <div class="mb-3 flex justify-end">
      <Button type="primary" @click="openCreate">+ 新建方案</Button>
    </div>
    <Table
      :columns="columns"
      :data-source="products"
      :loading="loading"
      :pagination="false"
      row-key="id"
    >
      <template #bodyCell="{ column, record }: { column: any; record: any }">
        <template v-if="column.key === 'tier'">
          <Tag :color="record.tier === 2 ? 'gold' : 'volcano'">
            {{ tierLabel(record.tier) }}
          </Tag>
        </template>
        <template v-else-if="column.key === 'priceCents'">
          <span class="font-semibold">{{ yuan(record.priceCents) }}</span>
          <Button
            class="ml-2"
            size="small"
            type="link"
            @click="editPrice(record, 'price')"
          >
            改价
          </Button>
        </template>
        <template v-else-if="column.key === 'originalCents'">
          <span :class="record.originalCents == null ? 'text-gray-300' : ''">
            {{ yuan(record.originalCents) }}
          </span>
          <Button
            class="ml-2"
            size="small"
            type="link"
            @click="editPrice(record, 'original')"
          >
            改
          </Button>
        </template>
        <template v-else-if="column.key === 'firstPriceCents'">
          <span :class="record.firstPriceCents == null ? 'text-gray-300' : ''">
            {{ yuan(record.firstPriceCents) }}
          </span>
          <Button
            class="ml-2"
            size="small"
            type="link"
            @click="editPrice(record, 'first')"
          >
            改
          </Button>
        </template>
        <template v-else-if="column.key === 'status'">
          <Tag :color="record.status === 1 ? 'green' : 'default'">
            {{ record.status === 1 ? '上架中' : '已下架' }}
          </Tag>
        </template>
        <template v-else-if="column.key === 'actions'">
          <Button size="small" @click="toggleStatus(record)">
            {{ record.status === 1 ? '下架' : '上架' }}
          </Button>
          <Button
            danger
            size="small"
            type="link"
            @click="removeProduct(record)"
          >
            删除
          </Button>
        </template>
      </template>
    </Table>

    <Modal
      v-model:open="createOpen"
      :confirm-loading="creating"
      cancel-text="取消"
      ok-text="创建"
      title="新建订阅方案"
      @ok="submitCreate"
    >
      <div class="flex flex-col gap-3 pt-2">
        <Select
          v-model:value="createForm.tier"
          :options="[
            { label: 'VIP', value: 1 },
            { label: 'SVIP', value: 2 },
          ]"
        />
        <Input
          v-model:value="createForm.durationDays"
          placeholder="时长（天，如 30 / 90 / 365）"
          type="number"
        />
        <Input v-model:value="createForm.priceCents" placeholder="现价（分，如 3000 = ¥30）" type="number" />
        <Input v-model:value="createForm.originalCents" placeholder="原价（分，可选）" type="number" />
        <Input v-model:value="createForm.firstPriceCents" placeholder="首月价（分，可选）" type="number" />
        <Input v-model:value="createForm.badge" placeholder="角标文案（可选，如 限时特惠）" />
      </div>
    </Modal>
  </div>
</template>
