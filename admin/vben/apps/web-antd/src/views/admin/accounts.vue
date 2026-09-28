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

interface AdminAccount {
  createdAt: string;
  id: number;
  role: string;
  status: number;
  username: string;
}

const loading = ref(true);
const accounts = ref<AdminAccount[]>([]);
const createOpen = ref(false);
const creating = ref(false);
const form = ref({ password: '', role: 'support', username: '' });

const roleText: Record<string, { color: string; label: string }> = {
  ops: { color: 'blue', label: '运营' },
  reviewer: { color: 'orange', label: '审核' },
  super: { color: 'red', label: '超级管理员' },
  support: { color: 'green', label: '客服' },
};

const columns = [
  { dataIndex: 'id', title: 'ID', width: 60 },
  { dataIndex: 'username', title: '用户名' },
  { dataIndex: 'role', key: 'role', title: '角色', width: 110 },
  { dataIndex: 'status', key: 'status', title: '状态', width: 90 },
  { dataIndex: 'createdAt', title: '创建时间', width: 120 },
  { key: 'actions', title: '操作', width: 150 },
];

async function load() {
  loading.value = true;
  try {
    accounts.value = await requestClient.get<AdminAccount[]>('/auth/accounts');
  } finally {
    loading.value = false;
  }
}

async function create() {
  creating.value = true;
  try {
    await requestClient.post('/auth/accounts', form.value);
    message.success('管理员已创建');
    createOpen.value = false;
    await load();
  } catch (e: any) {
    message.error(e?.response?.data?.msg ?? '创建失败');
  } finally {
    creating.value = false;
  }
}

async function toggle(record: AdminAccount) {
  await requestClient.put(`/auth/accounts/${record.id}/status`, {
    status: record.status === 1 ? 0 : 1,
  });
  message.success(record.status === 1 ? '已停用' : '已启用');
  await load();
}

async function resetPassword(record: AdminAccount) {
  Modal.confirm({
    title: `重置 ${record.username} 的密码？`,
    content: undefined,
    okText: '重置为 forhappy-admin',
    cancelText: '取消',
    onOk: async () => {
      await requestClient.put(`/auth/accounts/${record.id}/password`, {
        password: 'forhappy-admin',
      });
      message.success('密码已重置为初始密钥');
    },
  });
}

onMounted(load);
</script>

<template>
  <div class="p-4">
    <div class="mb-3 flex justify-end">
      <Button type="primary" @click="createOpen = true">+ 创建管理员</Button>
    </div>
    <Table
      :columns="columns"
      :data-source="accounts"
      :loading="loading"
      :pagination="false"
      row-key="id"
      size="middle"
    >
      <template #bodyCell="{ column, record }: { column: any; record: any }">
        <template v-if="column.key === 'role'">
          <Tag :color="roleText[record.role]?.color">{{ roleText[record.role]?.label ?? record.role }}</Tag>
        </template>
        <template v-else-if="column.key === 'status'">
          <Tag :color="record.status === 1 ? 'green' : 'default'">
            {{ record.status === 1 ? '启用' : '停用' }}
          </Tag>
        </template>
        <template v-else-if="column.key === 'actions'">
          <Button size="small" @click="resetPassword(record)">重置密码</Button>
          <Button
            v-if="record.username !== 'admin'"
            class="ml-2"
            size="small"
            @click="toggle(record)"
          >
            {{ record.status === 1 ? '停用' : '启用' }}
          </Button>
        </template>
      </template>
    </Table>

    <Modal
      v-model:open="createOpen"
      :confirm-loading="creating"
      cancel-text="取消"
      ok-text="创建"
      title="创建管理员"
      @ok="create"
    >
      <div class="flex flex-col gap-3 pt-2">
        <Input v-model:value="form.username" placeholder="用户名（3-32 位字母数字）" />
        <Input.Password v-model:value="form.password" placeholder="密码（至少 6 位）" />
        <Select
          v-model:value="form.role"
          :options="[
            { label: '运营（商业化+广告）', value: 'ops' },
            { label: '审核（内容安全）', value: 'reviewer' },
            { label: '客服（用户）', value: 'support' },
            { label: '超级管理员', value: 'super' },
          ]"
        />
      </div>
    </Modal>
  </div>
</template>
