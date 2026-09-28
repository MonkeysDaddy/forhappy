import type { UserInfo } from '@vben/types';

/**
 * 获取用户信息（演示后台：固定运营管理员）
 */
export async function getUserInfoApi() {
  const userInfo: UserInfo = {
    userId: 'forhappy-admin',
    username: 'admin',
    realName: '运营管理员',
    avatar: '',
    desc: 'ForHappy 运营后台',
    homePath: '/admin/stats',
    roles: ['super'],
    token: '',

  };
  return userInfo;
}
