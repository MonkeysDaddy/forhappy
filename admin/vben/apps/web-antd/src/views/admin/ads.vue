<script lang="ts" setup>
import { onMounted, ref } from 'vue';

import {
  Button,
  Input,
  message,
  Modal,
  Select,
  Table,
  Tag,
} from 'ant-design-vue';

import { requestClient } from '#/api/request';

interface Ad {
  active: number;
  content: string;
  createdAt: string;
  id: number;
  imageUrl: null | string;
  linkUrl: null | string;
  position: string;
  title: string;
}

const loading = ref(true);
const ads = ref<Ad[]>([]);
const createOpen = ref(false);
const creating = ref(false);
const form = ref({
  content: '',
  imageUrl: '',
  linkUrl: '',
  position: 'feed',
  title: '',
});

async function load() {
  loading.value = true;
  try {
    ads.value = await requestClient.get<Ad[]>('/ads');
  } finally {
    loading.value = false;
  }
}

async function create() {
  creating.value = true;
  try {
    await requestClient.post('/ads', form.value);
    message.success('广告已投放');
    createOpen.value = false;
    await load();
  } catch (e: any) {
    message.error(e?.response?.data?.msg ?? '投放失败');
  } finally {
    creating.value = false;
  }
}

async function toggle(ad: Ad) {
  await requestClient.put(`/ads/${ad.id}/active`, { active: ad.active !== 1 });
  await load();
}

async function remove(ad: Ad) {
  await requestClient.delete(`/ads/${ad.id}`);
  message.success('已删除');
  await load();
}

const columns = [
  { dataIndex: 'title', title: '标题' },
  { dataIndex: 'content', title: '内容' },
  { dataIndex: 'position', key: 'position', title: '位置', width: 110 },
  { dataIndex: 'active', key: 'active', title: '状态', width: 100 },
  { key: 'actions', title: '操作', width: 140 },
];

onMounted(load);
</script>

<template>
  <div class="p-4">
    <div class="mb-3 flex justify-end">
      <Button type="primary" @click="createOpen = true">+ 投放广告</Button>
    </div>
    <Table
      :columns="columns"
      :data-source="ads"
      :loading="loading"
      :pagination="false"
      row-key="id"
      size="middle"
    >
      <template #bodyCell="{ column, record }: { column: any; record: any }">
        <template v-if="column.key === 'position'">
          <Tag>{{ record.position === 'feed' ? '发现页横幅' : record.position }}</Tag>
        </template>
        <template v-else-if="column.key === 'active'">
          <Tag :color="record.active === 1 ? 'green' : 'default'">
            {{ record.active === 1 ? '投放中' : '已停投' }}
          </Tag>
        </template>
        <template v-else-if="column.key === 'actions'">
          <Button size="small" @click="toggle(record)">
            {{ record.active === 1 ? '停投' : '恢复' }}
          </Button>
          <Button danger size="small" type="link" @click="remove(record)">
            删除
          </Button>
        </template>
      </template>
    </Table>

    <Modal
      v-model:open="createOpen"
      :confirm-loading="creating"
      cancel-text="取消"
      ok-text="投放"
      title="投放广告"
      @ok="create"
    >
      <div class="flex flex-col gap-3 pt-2">
        <Input v-model:value="form.title" placeholder="广告标题" />
        <Input v-model:value="form.content" placeholder="广告文案" />
        <Input v-model:value="form.imageUrl" placeholder="图片 URL（可选）" />
        <Input v-model:value="form.linkUrl" placeholder="跳转链接（可选）" />
        <Select
          v-model:value="form.position"
          :options="[{ label: '发现页横幅', value: 'feed' }]"
        />
      </div>
    </Modal>
  </div>
</template>
