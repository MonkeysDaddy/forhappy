<script lang="ts" setup>
import { onMounted, ref } from 'vue';

import { Button, Card, Input, message, Table } from 'ant-design-vue';

import { addWordApi, deleteWordApi, getWordsApi } from '#/api/admin';

const loading = ref(true);
const words = ref<Array<{ createdAt: string; id: number; word: string }>>([]);
const newWord = ref('');
const adding = ref(false);

const columns = [
  { dataIndex: 'id', title: 'ID', width: 80 },
  { dataIndex: 'word', title: '敏感词' },
  { dataIndex: 'createdAt', title: '添加时间', width: 180 },
  { key: 'actions', title: '操作', width: 100 },
];

async function load() {
  loading.value = true;
  try {
    words.value = await getWordsApi();
  } finally {
    loading.value = false;
  }
}

async function add() {
  const w = newWord.value.trim();
  if (!w) return;
  adding.value = true;
  try {
    await addWordApi(w);
    message.success(`已添加，聊天/动态发布即刻拦截「${w}」`);
    newWord.value = '';
    await load();
  } catch (e: any) {
    message.error(e?.response?.data?.msg ?? '添加失败');
  } finally {
    adding.value = false;
  }
}

async function remove(record: any) {
  await deleteWordApi(record.id);
  message.success('已删除');
  await load();
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <Card class="mb-4">
      <div class="flex items-center gap-2">
        <Input
          v-model:value="newWord"
          allow-clear
          :maxlength="64"
          placeholder="输入敏感词，回车添加"
          style="width: 320px; text-align: left"
          @press-enter="add"
        />
        <Button :loading="adding" type="primary" @click="add">添加</Button>
      </div>
    </Card>

    <Table
      :columns="columns"
      :data-source="words"
      :loading="loading"
      :pagination="{ pageSize: 20 }"
      row-key="id"
      size="middle"
    >
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'actions'">
          <Button danger size="small" @click="remove(record)">删除</Button>
        </template>
      </template>
    </Table>
  </div>
</template>
