'use strict';


const BASE = process.env.PB_URL || 'http://127.0.0.1:8090';
const EMAIL = process.env.PB_EMAIL || 'admin@techmarket.local';
const PASSWORD = process.env.PB_PASSWORD || 'admin12345678';

let token = '';
const ids = {};

async function api(path, { method = 'GET', body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: token } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : {};
  if (!res.ok) {
    throw new Error(`${method} ${path} → ${res.status}\n${JSON.stringify(data, null, 2)}`);
  }
  return data;
}

async function login() {
  const data = await api('/api/collections/_superusers/auth-with-password', {
    method: 'POST',
    body: { identity: EMAIL, password: PASSWORD },
  });
  token = data.token;
}

const idField = {
  name: 'id',
  type: 'text',
  system: true,
  required: true,
  primaryKey: true,
  autogeneratePattern: '[a-z0-9]{15}',
  min: 15,
  max: 15,
  pattern: '^[a-z0-9]+$',
};

const stamps = [
  { name: 'created', type: 'autodate', onCreate: true, onUpdate: false },
  { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
];

const rel = (name, target, opts = {}) => ({
  name,
  type: 'relation',
  required: opts.required ?? false,
  collectionId: ids[target],
  cascadeDelete: opts.cascadeDelete ?? false,
  minSelect: opts.min ?? 0,
  maxSelect: opts.max ?? 1,
});

async function ensure(def) {
  const existing = await fetch(`${BASE}/api/collections/${def.name}`, {
    headers: { Authorization: token },
  });
  const payload = {
    ...def,
    type: 'base',
    fields: [idField, ...def.fields, ...stamps],
  };
  if (existing.ok) {
    const current = await existing.json();
    const updated = await api(`/api/collections/${current.id}`, {
      method: 'PATCH',
      body: payload,
    });
    ids[def.name] = updated.id;
    console.log(`  обновлена: ${def.name}`);
    return;
  }
  const created = await api('/api/collections', { method: 'POST', body: payload });
  ids[def.name] = created.id;
  console.log(`  создана:   ${def.name}`);
}

// ─────────────────── правила доступа по ролям ───────────────────

const AUTHED = '@request.auth.id != ""';
const ADMIN = '@request.auth.role = "admin"';
const MANAGER = '@request.auth.role = "manager"';
const STAFF = `${ADMIN} || ${MANAGER}`;

async function main() {
  await login();
  console.log('Схема «ТехноМаркет»:');


  // Роль в коллекции users + видимое имя. Поля добавляются один раз,
  // а правила доступа переписываются при каждом запуске: иначе исправление
  // правила пришлось бы вносить в панели управления руками.
  const users = await api('/api/collections/users');
  ids.users = users.id;
  const hasRole = users.fields.some((f) => f.name === 'role');
  await api(`/api/collections/${users.id}`, {
    method: 'PATCH',
    body: {
      fields: hasRole
        ? users.fields
        : [
            ...users.fields,
            {
              name: 'role',
              type: 'select',
              required: true,
              maxSelect: 1,
              values: ['client', 'manager', 'admin'],
            },
            { name: 'fullName', type: 'text', max: 120 },
          ],

      listRule: STAFF,
      viewRule: `${STAFF} || id = @request.auth.id`,

      createRule: '@request.body.role = "client"',

      updateRule: `${ADMIN} || (id = @request.auth.id && @request.body.role:isset = false)`,
      deleteRule: ADMIN,
    },
  });
  console.log('  обновлена: users (роль, правила регистрации)');

  // ── справочники (1:N в товары) ──

  await ensure({
    name: 'brands',
    fields: [
      { name: 'name', type: 'text', required: true, min: 2, max: 100 },
      { name: 'country', type: 'text', max: 60 },
      { name: 'foundedYear', type: 'number', onlyInt: true, min: 1800, max: 2100 },
      { name: 'description', type: 'text', max: 1000 },
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_brands_name` ON `brands` (`name`)'],
    listRule: AUTHED,
    viewRule: AUTHED,
    createRule: STAFF,
    updateRule: STAFF,
    deleteRule: ADMIN,
  });

  await ensure({
    name: 'categories',
    fields: [
      { name: 'name', type: 'text', required: true, min: 2, max: 80 },
      { name: 'description', type: 'text', max: 500 },
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_categories_name` ON `categories` (`name`)'],
    listRule: AUTHED,
    viewRule: AUTHED,
    createRule: STAFF,
    updateRule: STAFF,
    deleteRule: ADMIN,
  });

  await ensure({
    name: 'suppliers',
    fields: [
      { name: 'name', type: 'text', required: true, min: 2, max: 120 },
      { name: 'city', type: 'text', max: 60 },
      { name: 'phone', type: 'text', max: 20, pattern: '^[0-9+()\\- ]*$' },
      { name: 'email', type: 'email' },
      { name: 'contractNumber', type: 'text', max: 40 },
    ],
    listRule: STAFF,
    viewRule: STAFF,
    createRule: STAFF,
    updateRule: STAFF,
    deleteRule: ADMIN,
  });

  // ── товары ──

  await ensure({
    name: 'products',
    fields: [
      { name: 'title', type: 'text', required: true, min: 2, max: 160 },
      { name: 'sku', type: 'text', required: true, min: 3, max: 40 },
      { name: 'price', type: 'number', required: true, min: 0 },
      { name: 'warrantyMonths', type: 'number', onlyInt: true, min: 0, max: 120 },
      rel('brand', 'brands', { required: true, min: 1 }),
      rel('category', 'categories', { required: true, min: 1 }),
      rel('supplier', 'suppliers'),
      { name: 'description', type: 'text', max: 2000 },
      { name: 'archived', type: 'bool' },
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_products_sku` ON `products` (`sku`)'],
    listRule: AUTHED,
    viewRule: AUTHED,
    createRule: STAFF,
    updateRule: STAFF,
    deleteRule: ADMIN,
  });

  // ── 1:1 ──

  await ensure({
    name: 'stock',
    fields: [
      rel('product', 'products', { required: true, min: 1, cascadeDelete: true }),
      // required не ставим: в PocketBase у чисел это запрещает значение 0,
      // а нулевой остаток на складе — нормальная ситуация.
      { name: 'quantity', type: 'number', onlyInt: true, min: 0, max: 100000 },
      { name: 'location', type: 'text', max: 40 },
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_stock_product` ON `stock` (`product`)'],
    listRule: STAFF,
    viewRule: STAFF,
    createRule: ADMIN,
    updateRule: ADMIN,
    deleteRule: ADMIN,
  });

  await ensure({
    name: 'profiles',
    fields: [
      rel('user', 'users', { required: true, min: 1, cascadeDelete: true }),
      { name: 'phone', type: 'text', max: 20, pattern: '^[0-9+()\\- ]*$' },
      { name: 'address', type: 'text', max: 200 },
      { name: 'birthDate', type: 'date' },
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_profiles_user` ON `profiles` (`user`)'],
    // Сотрудники видят контакты клиентов: это нужно для работы с заявками
    // и заказами, где заказчика выбирают из списка.
    listRule: `${STAFF} || user = @request.auth.id`,
    viewRule: `${STAFF} || user = @request.auth.id`,
    createRule: AUTHED,
    updateRule: `${STAFF} || user = @request.auth.id`,
    deleteRule: ADMIN,
  });

  // ── заказы: M:N товары через order_items ──

  await ensure({
    name: 'orders',
    fields: [
      rel('client', 'users', { required: true, min: 1 }),
      {
        name: 'status',
        type: 'select',
        required: true,
        maxSelect: 1,
        values: ['new', 'paid', 'shipped', 'done', 'cancelled'],
      },
      { name: 'total', type: 'number', min: 0 },
      { name: 'comment', type: 'text', max: 500 },
      { name: 'archived', type: 'bool' },
    ],
    listRule: `${STAFF} || client = @request.auth.id`,
    viewRule: `${STAFF} || client = @request.auth.id`,
    createRule: AUTHED,
    updateRule: STAFF,
    deleteRule: ADMIN,
  });

  await ensure({
    name: 'order_items',
    fields: [
      rel('order', 'orders', { required: true, min: 1, cascadeDelete: true }),
      rel('product', 'products', { required: true, min: 1 }),
      { name: 'quantity', type: 'number', required: true, onlyInt: true, min: 1, max: 1000 },
      { name: 'price', type: 'number', required: true, min: 0 },
    ],
    listRule: AUTHED,
    viewRule: AUTHED,
    createRule: AUTHED,
    updateRule: STAFF,
    deleteRule: STAFF,
  });

  // ── сервисный центр: раздел менеджера ──

  await ensure({
    name: 'services',
    fields: [
      { name: 'name', type: 'text', required: true, min: 2, max: 120 },
      { name: 'price', type: 'number', required: true, min: 0 },
      { name: 'normHours', type: 'number', required: true, min: 0.1, max: 100 },
      { name: 'archived', type: 'bool' },
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_services_name` ON `services` (`name`)'],
    listRule: AUTHED,
    viewRule: AUTHED,
    createRule: MANAGER,
    updateRule: MANAGER,
    deleteRule: MANAGER,
  });

  await ensure({
    name: 'masters',
    fields: [
      rel('user', 'users'),
      { name: 'fullName', type: 'text', required: true, min: 2, max: 120 },
      { name: 'specialization', type: 'text', max: 80 },
      { name: 'hireDate', type: 'date' },
      { name: 'archived', type: 'bool' },
    ],
    listRule: AUTHED,
    viewRule: AUTHED,
    createRule: MANAGER,
    updateRule: MANAGER,
    deleteRule: MANAGER,
  });

  await ensure({
    name: 'repair_orders',
    fields: [
      rel('client', 'users', { required: true, min: 1 }),
      rel('product', 'products'),
      rel('master', 'masters'),
      rel('services', 'services', { max: 20 }),
      { name: 'problem', type: 'text', required: true, min: 5, max: 1000 },
      { name: 'startAt', type: 'date', required: true },
      { name: 'endAt', type: 'date', required: true },
      {
        name: 'status',
        type: 'select',
        required: true,
        maxSelect: 1,
        values: ['new', 'diagnostics', 'in_work', 'ready', 'issued', 'rejected'],
      },
      { name: 'total', type: 'number', min: 0 },
      { name: 'archived', type: 'bool' },
    ],
    listRule: `${MANAGER} || client = @request.auth.id`,
    viewRule: `${MANAGER} || client = @request.auth.id`,
    createRule: AUTHED,
    updateRule: MANAGER,
    deleteRule: MANAGER,
  });

  console.log('\nГотово. Коллекций создано: ' + Object.keys(ids).length);
}

main().catch((err) => {
  console.error('\nОШИБКА:\n' + err.message);
  process.exit(1);
});
