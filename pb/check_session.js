'use strict';

// Проверка работы сессии так, как её использует приложение:
// вход по адресу почты, продление токена, запрет повышения роли при регистрации.
// Запуск:  node check_session.js

const BASE = process.env.PB_URL || 'http://127.0.0.1:8090';

async function post(path, body, token) {
  const res = await fetch(BASE + path, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: token } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, data: await res.json().catch(() => ({})) };
}

async function main() {
  const login = await post('/api/collections/users/auth-with-password', {
    identity: 'client@tm.local',
    password: 'client123456',
  });
  console.log(
    `вход по почте → ${login.status}, ` +
      `пользователь: ${login.data.record?.email}, роль: ${login.data.record?.role}`
  );

  const refresh = await post(
    '/api/collections/users/auth-refresh',
    null,
    login.data.token
  );
  const renewed = Boolean(refresh.data.token);
  console.log(
    `продление сессии → ${refresh.status}, новый токен получен: ${renewed}`
  );

  const badToken = await post(
    '/api/collections/users/auth-refresh',
    null,
    'invalid.token.value'
  );
  console.log(`продление с неверным токеном → ${badToken.status} (ожидается 401)`);

  const wrongPass = await post('/api/collections/users/auth-with-password', {
    identity: 'client@tm.local',
    password: 'неверный-пароль',
  });
  console.log(`вход с неверным паролем → ${wrongPass.status} (ожидается 400)`);

  const escalate = await post('/api/collections/users/records', {
    email: `probe${Date.now()}@tm.local`,
    password: 'probe12345678',
    passwordConfirm: 'probe12345678',
    role: 'admin',
    fullName: 'Попытка получить админа',
  });
  console.log(
    `регистрация с ролью admin → ${escalate.status} (ожидается 400, правило сервера)`
  );

  const normal = await post('/api/collections/users/records', {
    email: `probe${Date.now()}@tm.local`,
    password: 'probe12345678',
    passwordConfirm: 'probe12345678',
    role: 'client',
    fullName: 'Обычная регистрация',
  });
  console.log(`регистрация с ролью client → ${normal.status} (ожидается 200)`);

  if (normal.data.id) {
    const admin = await post('/api/collections/_superusers/auth-with-password', {
      identity: process.env.PB_EMAIL || 'admin@techmarket.local',
      password: process.env.PB_PASSWORD || 'admin12345678',
    });
    await fetch(`${BASE}/api/collections/users/records/${normal.data.id}`, {
      method: 'DELETE',
      headers: { Authorization: admin.data.token },
    });
  }
}

main().catch((err) => {
  console.error('ОШИБКА: ' + err.message);
  process.exit(1);
});
