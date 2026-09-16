'use strict';

// Тестовые данные «ТехноМаркет» для PocketBase.
// Запуск:  node seed_data.js   (PocketBase должен быть запущен)
//
// Создаёт три учётные записи с ролями и заполняет все коллекции,
// включая связи 1:1, 1:N и M:N. Повторный запуск пересоздаёт данные заново.

const BASE = process.env.PB_URL || 'http://127.0.0.1:8090';
const EMAIL = process.env.PB_EMAIL || 'admin@techmarket.local';
const PASSWORD = process.env.PB_PASSWORD || 'admin12345678';

let token = '';

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

const create = (collection, body) =>
  api(`/api/collections/${collection}/records`, { method: 'POST', body });

/** Очистка коллекции перед повторным заполнением. */
async function wipe(collection) {
  const { items } = await api(
    `/api/collections/${collection}/records?perPage=500&fields=id`
  );
  for (const item of items) {
    await api(`/api/collections/${collection}/records/${item.id}`, { method: 'DELETE' });
  }
}

/** Пользователь: создаётся или обновляется по email. */
async function upsertUser({ email, password, role, fullName }) {
  const found = await api(
    `/api/collections/users/records?filter=(email='${email}')&perPage=1`
  );
  if (found.items.length) {
    const id = found.items[0].id;
    await api(`/api/collections/users/records/${id}`, {
      method: 'PATCH',
      body: { role, fullName, verified: true },
    });
    return id;
  }
  const user = await create('users', {
    email,
    password,
    passwordConfirm: password,
    role,
    fullName,
    verified: true,
    emailVisibility: true,
  });
  return user.id;
}

const iso = (y, m, d, h = 10) => new Date(Date.UTC(y, m - 1, d, h)).toISOString();

async function main() {
  const auth = await api('/api/collections/_superusers/auth-with-password', {
    method: 'POST',
    body: { identity: EMAIL, password: PASSWORD },
  });
  token = auth.token;

  console.log('Очистка старых данных…');
  for (const c of [
    'order_items',
    'orders',
    'repair_orders',
    'stock',
    'profiles',
    'products',
    'masters',
    'services',
    'brands',
    'categories',
    'suppliers',
  ]) {
    await wipe(c);
  }

  // ─── пользователи трёх ролей ───

  const clientId = await upsertUser({
    email: 'client@tm.local',
    password: 'client123456',
    role: 'client',
    fullName: 'Иванова Мария Сергеевна',
  });
  const managerId = await upsertUser({
    email: 'manager@tm.local',
    password: 'manager123456',
    role: 'manager',
    fullName: 'Петров Андрей Викторович',
  });
  const adminId = await upsertUser({
    email: 'admin@tm.local',
    password: 'admin123456',
    role: 'admin',
    fullName: 'Соколова Ольга Павловна',
  });
  console.log('Учётные записи: client, manager, admin');

  // ─── 1:1 профили ───

  await create('profiles', {
    user: clientId,
    phone: '+7 900 111-22-33',
    address: 'г. Казань, ул. Баумана, 12, кв. 45',
    birthDate: iso(1998, 4, 17),
  });
  await create('profiles', {
    user: managerId,
    phone: '+7 900 222-33-44',
    address: 'г. Казань, ул. Профсоюзная, 3',
    birthDate: iso(1990, 11, 2),
  });
  await create('profiles', {
    user: adminId,
    phone: '+7 900 333-44-55',
    address: 'г. Казань, пр. Победы, 100',
    birthDate: iso(1985, 6, 30),
  });

  // ─── справочники ───

  const brands = {};
  for (const b of [
    { name: 'Samsung', country: 'Республика Корея', foundedYear: 1938 },
    { name: 'Apple', country: 'США', foundedYear: 1976 },
    { name: 'Lenovo', country: 'Китай', foundedYear: 1984 },
    { name: 'Bosch', country: 'Германия', foundedYear: 1886 },
    { name: 'LG', country: 'Республика Корея', foundedYear: 1958 },
  ]) {
    const rec = await create('brands', { ...b, description: 'Производитель техники' });
    brands[b.name] = rec.id;
  }

  const cats = {};
  for (const c of [
    { name: 'Смартфоны', description: 'Мобильные телефоны и аксессуары' },
    { name: 'Ноутбуки', description: 'Портативные компьютеры' },
    { name: 'Крупная бытовая техника', description: 'Стиральные машины, холодильники' },
    { name: 'Телевизоры', description: 'Телевизоры и медиаприставки' },
    { name: 'Периферия', description: 'Мыши, клавиатуры, мониторы' },
  ]) {
    const rec = await create('categories', c);
    cats[c.name] = rec.id;
  }

  const sups = {};
  for (const s of [
    {
      name: 'ООО «ТехноОпт»',
      city: 'Москва',
      phone: '+7 495 100-20-30',
      email: 'sales@technoopt.ru',
      contractNumber: 'ДП-2024/17',
    },
    {
      name: 'ЗАО «Электроснаб»',
      city: 'Санкт-Петербург',
      phone: '+7 812 400-50-60',
      email: 'info@elsnab.ru',
      contractNumber: 'ДП-2024/23',
    },
    {
      name: 'ИП Кузнецов А.А.',
      city: 'Казань',
      phone: '+7 843 200-30-40',
      email: 'kuznetsov@mail.ru',
      contractNumber: 'ДП-2025/04',
    },
  ]) {
    const rec = await create('suppliers', s);
    sups[s.name] = rec.id;
  }
  console.log('Справочники: 5 брендов, 5 категорий, 3 поставщика');

  // ─── товары (1:N) + склад (1:1) ───

  const catalog = [
    ['Samsung Galaxy S24 128 ГБ', 'SM-S24-128', 74990, 'Samsung', 'Смартфоны', 'ООО «ТехноОпт»', 24, 12, 'A-01-03'],
    ['Apple iPhone 15 256 ГБ', 'AP-I15-256', 99990, 'Apple', 'Смартфоны', 'ООО «ТехноОпт»', 12, 5, 'A-01-04'],
    ['Lenovo IdeaPad 3 15', 'LN-IP3-15', 54990, 'Lenovo', 'Ноутбуки', 'ЗАО «Электроснаб»', 24, 8, 'B-02-01'],
    ['Apple MacBook Air 13 M3', 'AP-MBA-M3', 134990, 'Apple', 'Ноутбуки', 'ЗАО «Электроснаб»', 12, 3, 'B-02-02'],
    ['Bosch WLP 20260 стиральная машина', 'BS-WLP-260', 46990, 'Bosch', 'Крупная бытовая техника', 'ИП Кузнецов А.А.', 36, 4, 'C-03-01'],
    ['LG GA-B509 холодильник', 'LG-GAB-509', 61990, 'LG', 'Крупная бытовая техника', 'ИП Кузнецов А.А.', 24, 2, 'C-03-02'],
    ['LG OLED55C4 телевизор', 'LG-OL55-C4', 129990, 'LG', 'Телевизоры', 'ООО «ТехноОпт»', 24, 6, 'D-01-01'],
    ['Samsung QE43Q60D телевизор', 'SM-QE43-60D', 43990, 'Samsung', 'Телевизоры', 'ООО «ТехноОпт»', 24, 9, 'D-01-02'],
    ['Lenovo Legion M600 мышь', 'LN-LGM-600', 4990, 'Lenovo', 'Периферия', 'ЗАО «Электроснаб»', 12, 25, 'E-04-07'],
    ['Samsung ViewFinity S6 монитор', 'SM-VF-S6', 27990, 'Samsung', 'Периферия', 'ЗАО «Электроснаб»', 36, 0, 'E-04-08'],
  ];

  const products = [];
  for (const [title, sku, price, brand, cat, sup, warranty, qty, loc] of catalog) {
    const rec = await create('products', {
      title,
      sku,
      price,
      warrantyMonths: warranty,
      brand: brands[brand],
      category: cats[cat],
      supplier: sups[sup],
      description: `${title}. Гарантия ${warranty} мес.`,
      archived: false,
    });
    products.push(rec);
    await create('stock', { product: rec.id, quantity: qty, location: loc });
  }
  console.log('Товары: 10, складских записей: 10 (связь 1:1)');

  // ─── заказы + позиции (M:N) ───

  const orders = [
    { status: 'done', comment: 'Самовывоз', items: [[0, 1], [8, 2]] },
    { status: 'paid', comment: 'Доставка на дом', items: [[2, 1], [9, 1]] },
    { status: 'new', comment: '', items: [[6, 1]] },
    { status: 'shipped', comment: 'Оплата при получении', items: [[4, 1], [5, 1]] },
  ];

  for (const o of orders) {
    let total = 0;
    for (const [idx, qty] of o.items) total += products[idx].price * qty;
    const rec = await create('orders', {
      client: clientId,
      status: o.status,
      total,
      comment: o.comment,
      archived: false,
    });
    for (const [idx, qty] of o.items) {
      await create('order_items', {
        order: rec.id,
        product: products[idx].id,
        quantity: qty,
        price: products[idx].price,
      });
    }
  }
  console.log('Заказы: 4 с позициями (связь M:N)');

  // ─── сервисный центр ───

  // Ставка норма-часа сервисного центра. То же значение используется
  // в форме заявки на ремонт, поэтому суммы совпадают.
  const HOURLY_RATE = 1200;

  const priceList = [
    { name: 'Диагностика устройства', price: 900, normHours: 0.5 },
    { name: 'Замена дисплейного модуля', price: 6500, normHours: 2 },
    { name: 'Чистка от пыли и замена термопасты', price: 2400, normHours: 1.5 },
    { name: 'Замена аккумулятора', price: 3200, normHours: 1 },
    { name: 'Восстановление программного обеспечения', price: 1800, normHours: 1 },
  ];

  const services = {};
  for (const s of priceList) {
    const rec = await create('services', { ...s, archived: false });
    services[s.name] = rec.id;
  }

  /** Стоимость ремонта: цены услуг плюс норма-часы по ставке. */
  const repairTotal = (names) =>
    names.reduce((sum, n) => {
      const s = priceList.find((x) => x.name === n);
      return sum + s.price + Math.round(s.normHours * HOURLY_RATE);
    }, 0);

  const masters = [];
  for (const m of [
    { fullName: 'Гарипов Ильдар Ринатович', specialization: 'Мобильная техника', hireDate: iso(2021, 3, 1) },
    { fullName: 'Носов Дмитрий Олегович', specialization: 'Ноутбуки и ПК', hireDate: iso(2019, 9, 16) },
    { fullName: 'Салимов Тимур Раисович', specialization: 'Крупная бытовая техника', hireDate: iso(2023, 2, 6) },
  ]) {
    const rec = await create('masters', { ...m, archived: false });
    masters.push(rec.id);
  }

  const repairs = [
    {
      product: 1,
      master: 0,
      services: ['Диагностика устройства', 'Замена дисплейного модуля'],
      problem: 'Разбит экран после падения, изображение отсутствует.',
      start: iso(2026, 9, 14, 9),
      end: iso(2026, 9, 14, 12),
      status: 'issued',
    },
    {
      product: 3,
      master: 1,
      services: ['Чистка от пыли и замена термопасты'],
      problem: 'Перегрев и шум вентилятора при нагрузке, самопроизвольное выключение.',
      start: iso(2026, 9, 15, 10),
      end: iso(2026, 9, 15, 13),
      status: 'ready',
    },
    {
      product: 0,
      master: 0,
      services: ['Диагностика устройства', 'Замена аккумулятора'],
      problem: 'Быстро разряжается батарея, держит менее двух часов.',
      start: iso(2026, 9, 16, 9),
      end: iso(2026, 9, 16, 11),
      status: 'in_work',
    },
    {
      product: 4,
      master: 2,
      services: ['Диагностика устройства'],
      problem: 'Не сливает воду, останавливается на этапе отжима.',
      start: iso(2026, 9, 17, 14),
      end: iso(2026, 9, 17, 16),
      status: 'diagnostics',
    },
    {
      product: 6,
      master: 1,
      services: ['Восстановление программного обеспечения'],
      problem: 'Не запускается операционная система телевизора, циклическая перезагрузка.',
      start: iso(2026, 9, 18, 11),
      end: iso(2026, 9, 18, 13),
      status: 'new',
    },
  ];

  for (const r of repairs) {
    const ids = r.services.map((n) => services[n]);
    const total = repairTotal(r.services);
    await create('repair_orders', {
      client: clientId,
      product: products[r.product].id,
      master: masters[r.master],
      services: ids,
      problem: r.problem,
      startAt: r.start,
      endAt: r.end,
      status: r.status,
      total,
      archived: false,
    });
  }
  console.log('Сервис: 5 услуг, 3 мастера, 5 заявок на ремонт');

  console.log('\nГотово. Учётные записи приложения:');
  console.log('  client@tm.local  / client123456   — клиент');
  console.log('  manager@tm.local / manager123456  — менеджер сервиса');
  console.log('  admin@tm.local   / admin123456    — администратор');
}

main().catch((err) => {
  console.error('\nОШИБКА:\n' + err.message);
  process.exit(1);
});
