<script lang="ts" setup>
import { onMounted, ref } from 'vue';

import { Image as AImage } from 'ant-design-vue';
import {
  Button,
  message,
  Modal,
  Table,
  TabPane,
  Tabs,
  } from 'ant-design-vue';

import { requestClient } from '#/api/request';

const photos = ref<any[]>([]);
const moments = ref<any[]>([]);
const photosLoading = ref(true);
const momentsLoading = ref(true);

const photoColumns = [
  { dataIndex: 'id', title: 'ID', width: 70 },
  { dataIndex: 'nickname', title: '用户', width: 120 },
  { dataIndex: 'url', key: 'url', title: '照片' },
  { key: 'actions', title: '审核', width: 160 },
];
const momentColumns = [
  { dataIndex: 'id', title: 'ID', width: 70 },
  { dataIndex: 'nickname', title: '用户', width: 120 },
  { dataIndex: 'caption', title: '内容' },
  { key: 'actions', title: '审核', width: 160 },
];

async function loadPhotos() {
  photosLoading.value = true;
  try {
    photos.value = await requestClient.get<any[]>('/reviews/photos');
  } finally {
    photosLoading.value = false;
  }
}

async function loadMoments() {
  momentsLoading.value = true;
  try {
    moments.value = await requestClient.get<any[]>('/reviews/moments');
  } finally {
    momentsLoading.value = false;
  }
}

async function reviewPhoto(id: number, action: number) {
  await requestClient.post(`/reviews/photos/${id}?action=${action}`);
  message.success(action === 1 ? '已通过' : '已驳回');
  await loadPhotos();
}

async function reviewMoment(id: number, action: number, reason?: string) {
  await requestClient.post(
    `/reviews/moments/${id}?action=${action}` +
      (reason ? `&reason=${encodeURIComponent(reason)}` : ''),
  );
  message.success(action === 1 ? '已通过，动态已发布' : '已驳回并通知作者');
  await loadMoments();
}

function confirmPhoto(id: number, action: number) {
  Modal.confirm({
    title: action === 1 ? '通过该照片？' : '驳回该照片？',
    content:
      action === 1
        ? '通过后展示在用户照片墙；头像照将同步激活'
        : '驳回后照片对所有人不可见',
    okText: '确认',
    cancelText: '取消',
    onOk: () => reviewPhoto(id, action),
  });
}

function confirmMoment(id: number, action: number) {
  if (action === 1) {
    reviewMoment(id, action);
    return;
  }
  // 驳回需填写理由（将通知作者）
  let reason = '';
  Modal.confirm({
    title: '驳回该动态？',
    content: `<input id="fh-reject-reason" placeholder="驳回理由（将通知作者）" style="width:100%;padding:6px 10px;border:1px solid #d9d9d9;border-radius:6px" />`,
    okText: '驳回并通知',
    okType: 'danger',
    cancelText: '取消',
    onOk: async () => {
      const el = document.querySelector<HTMLInputElement>('#fh-reject-reason');
      reason = el?.value?.trim() ?? '';
      await reviewMoment(id, action, reason);
    },
  });
}

onMounted(() => {
  loadPhotos();
  loadMoments();
});
</script>

<template>
  <div class="p-4">
    <Tabs default-active-key="photos">
      <TabPane key="photos" tab="照片审核">
        <Table
          :columns="photoColumns"
          :data-source="photos"
          :loading="photosLoading"
          :pagination="false"
          row-key="id"
          size="middle"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'url'">
              <AImage :src="record.url" :width="72" />
            </template>
            <template v-else-if="column.key === 'actions'">
              <Button size="small" type="primary" @click="confirmPhoto(record.id, 1)">
                通过
              </Button>
              <Button
                danger
                size="small"
                type="link"
                @click="confirmPhoto(record.id, 2)"
              >
                驳回
              </Button>
            </template>
          </template>
        </Table>
      </TabPane>
      <TabPane key="moments" tab="动态审核">
        <Table
          :columns="momentColumns"
          :data-source="moments"
          :loading="momentsLoading"
          :pagination="false"
          row-key="id"
          size="middle"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'actions'">
              <Button
                size="small"
                type="primary"
                @click="confirmMoment(record.id, 1)"
              >
                通过
              </Button>
              <Button
                danger
                size="small"
                type="link"
                @click="confirmMoment(record.id, 2)"
              >
                驳回
              </Button>
            </template>
          </template>
        </Table>
      </TabPane>
    </Tabs>
  </div>
</template>
