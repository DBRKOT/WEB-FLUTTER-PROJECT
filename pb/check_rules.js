'use strict';

// Проверка разграничения прав на стороне сервера.
// Запуск:  node check_rules.js   (PocketBase должен быть запущен)
//
// Показывает, что доступ определяется правилами коллекций, а не интерфейсом:
// запрос выполняется напрямую к REST API, минуя Flutter-приложение.

const BASE = process.env.PB_URL || 'http://127.0.0.1:8090';

const ACCOUNTS = {
  client: { email: 'client@tm.local', password: 'client123456' },
  manager: { email: 'manager@tm.local', password: 'manager123456' },
  admin: { email: 'admin@tm.local', password: 'admin123456' },
};

async function login(role) {
  const res = await fetch(`${BASE}/api/collections/users/auth-with-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      identity: ACCOUNTS[role].email,
      password: ACCOUNTS[role].password,
    }),
  });
  if (!res.ok) throw new Error(`Вход ${role}: ${res.status}`);
  return (await res.json()).token;
}

async function attempt(token, method, path, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      Authorization: token,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  const count = data.totalItems ?? (data.id ? 1 : 0);
  return { status: res.status, ok: res.ok, count, id: data.id };
}

const mark = (ok, expected) => (ok === expected ? 'верно  ' : 'НЕВЕРНО');

async function main() {
  const tokens = {
    client: await login('client'),
    manager: await login('manager'),
    admin: await login('admin'),
  };

  console.log('\nРаздел клиента: свои заявки на ремонт');
  let r = await attempt(tokens.client, 'GET', '/api/collections/repair_orders/records');
  console.log(`  ${mark(r.ok, true)} клиент читает свои заявки → ${r.status}, записей: ${r.count}`);

  console.log('\nРаздел менеджера: сервисный центр');
  r = await attempt(tokens.manager, 'GET', '/api/collections/repair_orders/records');
  console.log(`  ${mark(r.ok, true)} менеджер читает все заявки → ${r.status}, записей: ${r.count}`);

  const service = { name: 'Проверка прав ' + Date.now(), price: 100, normHours: 1 };
  r = await attempt(tokens.manager, 'POST', '/api/collections/services/records', service);
  console.log(`  ${mark(r.ok, true)} менеджер добавляет услугу → ${r.status}`);
  const createdServiceId = r.id;

  r = await attempt(tokens.admin, 'POST', '/api/collections/services/records', {
    name: 'Услуга от админа ' + Date.now(),
    price: 100,
    normHours: 1,
  });
  console.log(`  ${mark(r.ok, false)} администратору услуга запрещена → ${r.status}`);

  r = await attempt(tokens.client, 'POST', '/api/collections/services/records', {
    name: 'Услуга от клиента ' + Date.now(),
    price: 100,
    normHours: 1,
  });
  console.log(`  ${mark(r.ok, false)} клиенту услуга запрещена → ${r.status}`);

  console.log('\nРаздел администратора: склад');
  r = await attempt(tokens.admin, 'GET', '/api/collections/stock/records');
  console.log(`  ${mark(r.ok, true)} администратор видит склад → ${r.status}, записей: ${r.count}`);

  r = await attempt(tokens.client, 'GET', '/api/collections/stock/records');
  console.log(`  ${mark(r.count === 0, true)} клиент склад не видит → ${r.status}, записей: ${r.count}`);

  console.log('\nРаздел администратора: пользователи');
  r = await attempt(tokens.admin, 'GET', '/api/collections/users/records');
  console.log(`  ${mark(r.ok, true)} администратор видит пользователей → ${r.status}, записей: ${r.count}`);

  r = await attempt(tokens.client, 'GET', '/api/collections/users/records');
  console.log(`  ${mark(r.count === 0, true)} клиент список пользователей не видит → ${r.status}, записей: ${r.count}`);

  console.log('\nКаталог: изменять может только сотрудник');
  r = await attempt(tokens.client, 'POST', '/api/collections/products/records', {
    title: 'Товар от клиента',
    sku: 'CLIENT-' + Date.now(),
    price: 1000,
  });
  console.log(`  ${mark(r.ok, false)} клиенту создание товара запрещено → ${r.status}`);

  console.log('\nКонтакты клиентов: нужны сотрудникам для работы с заявками');
  r = await attempt(tokens.manager, 'GET', '/api/collections/profiles/records');
  console.log(`  ${mark(r.count > 0, true)} менеджер видит профили клиентов → ${r.status}, записей: ${r.count}`);

  r = await attempt(tokens.client, 'GET', '/api/collections/profiles/records');
  console.log(`  ${mark(r.count === 1, true)} клиент видит только свой профиль → ${r.status}, записей: ${r.count}`);

  // Сортировка и поиск по полю связанной записи требуют права на список
  // связанной коллекции. Если у сотрудников его отнять, запрос не выдаст
  // ошибку, а молча вернёт ноль записей — и списки клиентов опустеют.
  console.log('\nСортировка и поиск по имени клиента (поле связанной записи)');
  r = await attempt(
    tokens.manager,
    'GET',
    '/api/collections/profiles/records?sort=user.fullName',
  );
  console.log(`  ${mark(r.count > 0, true)} менеджер сортирует клиентов по имени → ${r.status}, записей: ${r.count}`);

  r = await attempt(
    tokens.manager,
    'GET',
    "/api/collections/profiles/records?filter=user.fullName~'а'",
  );
  console.log(`  ${mark(r.count > 0, true)} менеджер ищет клиента по имени → ${r.status}, записей: ${r.count}`);

  console.log('\nСвязь один к одному: вторая складская запись у товара невозможна');
  const stock = await attempt(tokens.admin, 'GET', '/api/collections/stock/records?perPage=1');
  const first = await fetch(`${BASE}/api/collections/stock/records?perPage=1`, {
    headers: { Authorization: tokens.admin },
  }).then((res) => res.json());
  const productId = first.items?.[0]?.product;
  if (productId) {
    r = await attempt(tokens.admin, 'POST', '/api/collections/stock/records', {
      product: productId,
      quantity: 1,
      location: 'Z-99-99',
    });
    console.log(
      `  ${mark(r.ok, false)} повторная запись отклонена уникальным индексом → ${r.status}`
    );
  } else {
    console.log(`  пропущено: складских записей нет (${stock.status})`);
  }

  // уборка
  if (createdServiceId) {
    await attempt(tokens.manager, 'DELETE', `/api/collections/services/records/${createdServiceId}`);
  }
  console.log('');
}

main().catch((err) => {
  console.error('ОШИБКА: ' + err.message);
  process.exit(1);
});
