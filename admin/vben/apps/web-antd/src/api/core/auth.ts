import { useAccessStore } from '@vben/stores';

import { baseRequestClient } from '#/api/request';

export namespace AuthApi {
  /** 登录接口参数 */
  export interface LoginParams {
    password?: string;
    username?: string;
  }

  /** 登录接口返回值 */
  export interface LoginResult {
    accessToken: string;
  }

  export interface RefreshTokenResult {
    data: string;
    status: number;
  }
}

/**
 * 登录：用管理密钥校验（密钥即 accessToken）
 * 用户名固定 admin；密码 = X-Admin-Key（演示环境默认 forhappy-admin）
 */
export async function loginApi(data: AuthApi.LoginParams) {
  const key = data.password ?? '';
  // 用密钥试探 stats 接口：200 即密钥有效
  await baseRequestClient.get('/admin/stats', {
    headers: { 'X-Admin-Key': key },
  });
  return { accessToken: key } as AuthApi.LoginResult;
}

/**
 * 刷新accessToken
 */
export async function refreshTokenApi() {
  // 密钥鉴权无刷新机制
  const data = useAccessStore().accessToken ?? '';
  return { data, status: 0 } as AuthApi.RefreshTokenResult;
}

/**
 * 退出登录（密钥鉴权无服务端会话，本地清理即可）
 */
export async function logoutApi() {
  return Promise.resolve(true);
}

/**
 * 获取用户权限码（演示后台不做细粒度权限，返回空）
 */
export async function getAccessCodesApi() {
  return [] as string[];
}
