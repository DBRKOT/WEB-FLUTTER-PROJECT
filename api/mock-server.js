
'use strict';

const http = require('node:http');
const crypto = require('node:crypto');


const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf('--' + name);
  return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
}

const PORT = Number(arg('port', 8080));
const ORIGIN = arg('origin', '*');
const SECRET = 'учебный-ключ-не-для-продакшена';
const ACCESS_TTL = Number(arg('ttl', 900));      // секунд
const REFRESH_TTL = 60 * 60 * 24 * 7;

// ─────────────────────────────── токены ───────────────────────────────

function b64url(buf) {
  return Buffer.from(buf).toString('base64url');
}

function sign(payload) {
  const withId = { ...payload, jti: crypto.randomUUID() };
  const body = b64url(JSON.stringify(withId));
  const mac = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  return body + '.' + mac;
}

function verify(token) {
  if (typeof token !== 'string' || !token.includes('.')) return null;
  const [body, mac] = token.split('.');
  const expected = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  if (mac !== expected) return null;
  let payload;
  try {
    payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (payload.exp && payload.exp * 1000 < Date.now()) return null;
  return payload;
}

// ─────────────────────────────── данные ───────────────────────────────

let db;

function seed() {
  db = {
    seq: {},
    publishers: [],
    authors: [],
    genres: [],
    books: [],
    readers: [],
    cards: [],
    loans: [],
    users: [],
    refreshTokens: new Set(),
  };

  const P = (name, city, foundedYear) => push('publishers', { name, city, foundedYear });
  const A = (fullName, birthYear, country) => push('authors', { fullName, birthYear, country });
  const G = (name, description) => push('genres', { name, description });

  const distCenter = P('Дистрибьютор Центр', 'Россия', 2005);
  const euroTech = P('EuroTech Supply', 'Германия', 1998);
  const asiaGadgets = P('Asia Gadgets Ltd', 'Китай', 2012);

  const apple = A('Apple', 1976, 'США');
  const samsung = A('Samsung', 1938, 'Южная Корея');
  const sony = A('Sony', 1946, 'Япония');
  const lg = A('LG', 1958, 'Южная Корея');
  const xiaomi = A('Xiaomi', 2010, 'Китай');
  const asus = A('ASUS', 1989, 'Тайвань');
  const bosch = A('Bosch', 1886, 'Германия');
  const canon = A('Canon', 1937, 'Япония');
  const dyson = A('Dyson', 1991, 'Великобритания');
  const nintendo = A('Nintendo', 1889, 'Япония');

  const smartphones = G('Смартфоны', 'Мобильные телефоны');
  const laptops = G('Ноутбуки', 'Портативные ПК');
  const tablets = G('Планшеты', 'Планшетные компьютеры');
  const headphones = G('Наушники', 'Аудиоаксессуары');
  const tvs = G('Телевизоры', 'ТВ и панели');
  const consoles = G('Игровые приставки', 'Консоли');
  const home = G('Бытовая техника', 'Дом и кухня');
  const photo = G('Фототехника', 'Камеры');
  const office = G('Оргтехника', 'Принтеры и МФУ');

  const B = (title, isbn, year, pages, publisherId, authorIds, genreIds, copiesTotal, copiesAvailable) =>
    push('books', {
      title, isbn, year, pages, publisherId, authorIds, genreIds,
      copiesTotal,
      copiesAvailable: copiesAvailable ?? copiesTotal,
    });

  B('iPhone 15 Pro', 'TM-000001', 2023, 129990, distCenter, [apple], [smartphones], 20, 14);
  B('MacBook Air 13 M3', 'TM-000002', 2024, 149990, distCenter, [apple], [laptops], 12, 8);
  B('iPad Pro 11', 'TM-000003', 2024, 119990, distCenter, [apple], [tablets], 10, 6);
  B('AirPods Pro 2', 'TM-000004', 2023, 24990, distCenter, [apple], [headphones], 30, 22);
  B('Galaxy S24 Ultra', 'TM-000005', 2024, 119990, euroTech, [samsung], [smartphones], 18, 11);
  B('Samsung QE55Q80D', 'TM-000006', 2024, 99990, euroTech, [samsung], [tvs], 8, 5);
  B('Galaxy Buds 3 Pro', 'TM-000007', 2024, 19990, euroTech, [samsung], [headphones], 25, 19);
  B('PlayStation 5 Slim', 'TM-000008', 2023, 54990, asiaGadgets, [sony], [consoles], 15, 4);
  B('WH-1000XM5', 'TM-000009', 2022, 34990, asiaGadgets, [sony], [headphones], 16, 9);
  B('Sony Bravia XR-55A80L', 'TM-000010', 2023, 139990, asiaGadgets, [sony], [tvs], 6, 3);
  B('LG OLED55C3', 'TM-000011', 2023, 129990, euroTech, [lg], [tvs], 7, 2);
  B('LG gram 16', 'TM-000012', 2024, 139990, euroTech, [lg], [laptops], 9, 7);
  B('Redmi Note 13 Pro', 'TM-000013', 2024, 32990, asiaGadgets, [xiaomi], [smartphones], 40, 28);
  B('Xiaomi Robot Vacuum S10', 'TM-000014', 2023, 27990, asiaGadgets, [xiaomi], [home], 14, 10);
  B('ASUS ROG Zephyrus G16', 'TM-000015', 2024, 189990, distCenter, [asus], [laptops], 5, 2);
  B('ASUS TUF Gaming A15', 'TM-000016', 2023, 99990, distCenter, [asus], [laptops], 11, 6);
  B('Bosch Serie 8 SMS8ZCI48Q', 'TM-000017', 2023, 89990, euroTech, [bosch], [home], 8, 5);
  B('Bosch KGN39VI306', 'TM-000018', 2022, 79990, euroTech, [bosch], [home], 6, 4);
  B('Canon EOS R8', 'TM-000019', 2023, 159990, distCenter, [canon], [photo], 7, 3);
  B('Canon PIXMA G3470', 'TM-000020', 2023, 24990, distCenter, [canon], [office], 13, 9);
  B('Dyson V15 Detect', 'TM-000021', 2023, 69990, euroTech, [dyson], [home], 10, 6);
  B('Nintendo Switch OLED', 'TM-000022', 2021, 34990, asiaGadgets, [nintendo], [consoles], 20, 12);

  B('Демо-остаток: гаджет', 'TM-DEMO-409', 2024, 9990, asiaGadgets, [xiaomi], [smartphones], 1, 1);

  const readerNames = [
    ['Иван Петров', 'ivan.petrov@mail.ru', '+7-900-111-22-33'],
    ['Мария Сидорова', 'maria.sidorova@mail.ru', '+7-900-222-33-44'],
    ['Алексей Козлов', 'alex.kozlov@mail.ru', '+7-900-333-44-55'],
    ['Ольга Новикова', 'olga.novikova@mail.ru', '+7-900-444-55-66'],
    ['Дмитрий Орлов', 'dmitry.orlov@mail.ru', '+7-900-555-66-77'],
    ['Елена Васильева', 'elena.vasileva@mail.ru', '+7-900-666-77-88'],
  ];

  readerNames.forEach(([fullName, email, phone], i) => {
    const readerId = push('readers', { fullName, email, phone });
    push('cards', {
      readerId,
      number: 'TM-CARD-' + String(readerId).padStart(3, '0'),
      issuedAt: iso(2023 + (i % 3), 1, 15 + i),
      expiresAt: iso(2027, 1, 15 + i),
    });
  });

  makeLoan(1, 4, -20, 14);   // просрочена (AirPods)
  makeLoan(2, 8, -5, 14);    // активна (PS5)
  makeLoan(3, 11, -30, 14, true); // возвращена (LG OLED)

  push('users', { username: 'admin', passwordHash: hash('admin123'), fullName: 'Администратор ТехноМаркет', email: 'admin@technomarket.local', role: 'admin', readerId: null });
  push('users', { username: 'manager', passwordHash: hash('manager123'), fullName: 'Менеджер магазина', email: 'manager@technomarket.local', role: 'librarian', readerId: null });
  push('users', { username: 'client', passwordHash: hash('client123'), fullName: 'Иван Петров', email: 'ivan.petrov@mail.ru', role: 'reader', readerId: 1 });
}

function push(collection, obj) {
  db.seq[collection] = (db.seq[collection] || 0) + 1;
  const id = db.seq[collection];
  db[collection].push({ id, ...obj, createdAt: new Date().toISOString(), deletedAt: null });
  return id;
}

function iso(y, m, d) {
  return new Date(Date.UTC(y, m - 1, d)).toISOString();
}

function hash(password) {
  return crypto.createHash('sha256').update(password + SECRET).digest('hex');
}

function makeLoan(readerId, bookId, issuedDaysAgo, days, returned = false) {
  const issuedAt = new Date(Date.now() + issuedDaysAgo * 86400000);
  const dueAt = new Date(issuedAt.getTime() + days * 86400000);
  const id = push('loans', {
    readerId,
    bookId,
    issuedAt: issuedAt.toISOString(),
    dueAt: dueAt.toISOString(),
    returnedAt: returned ? new Date().toISOString() : null,
  });
  if (!returned) {
    const book = db.books.find((b) => b.id === bookId);
    if (book) book.copiesAvailable = Math.max(0, book.copiesAvailable - 1);
  }
  return id;
}

// ──────────────────────── развёртывание объектов ────────────────────────

function slimPublisher(id) {
  const p = db.publishers.find((x) => x.id === id);
  return p ? { id: p.id, name: p.name } : null;
}

function expandBook(b) {
  return {
    id: b.id,
    title: b.title,
    isbn: b.isbn,
    year: b.year,
    pages: b.pages,
    publisher: slimPublisher(b.publisherId),
    authors: b.authorIds
      .map((id) => db.authors.find((a) => a.id === id))
      .filter(Boolean)
      .map((a) => ({ id: a.id, fullName: a.fullName })),
    genres: b.genreIds
      .map((id) => db.genres.find((g) => g.id === id))
      .filter(Boolean)
      .map((g) => ({ id: g.id, name: g.name })),
    copiesTotal: b.copiesTotal,
    copiesAvailable: b.copiesAvailable,
    createdAt: b.createdAt,
    deletedAt: b.deletedAt,
  };
}

function expandReader(r) {
  const card = db.cards.find((c) => c.readerId === r.id && !c.deletedAt);
  return {
    id: r.id,
    fullName: r.fullName,
    email: r.email,
    phone: r.phone,
    card: card
      ? { id: card.id, number: card.number, issuedAt: card.issuedAt, expiresAt: card.expiresAt }
      : null,
    createdAt: r.createdAt,
    deletedAt: r.deletedAt,
  };
}

function expandLoan(l) {
  const reader = db.readers.find((r) => r.id === l.readerId);
  const book = db.books.find((b) => b.id === l.bookId);
  let status = 'active';
  if (l.returnedAt) status = 'returned';
  else if (new Date(l.dueAt) < new Date()) status = 'overdue';
  return {
    id: l.id,
    reader: reader ? { id: reader.id, fullName: reader.fullName } : null,
    book: book ? { id: book.id, title: book.title } : null,
    issuedAt: l.issuedAt,
    dueAt: l.dueAt,
    returnedAt: l.returnedAt,
    status,
    deletedAt: l.deletedAt,
  };
}

function expandUser(u) {
  return { id: u.id, username: u.username, fullName: u.fullName, email: u.email, role: u.role, readerId: u.readerId };
}

const EXPANDERS = {
  books: expandBook,
  readers: expandReader,
  loans: expandLoan,
  authors: (a) => a,
  genres: (g) => g,
  publishers: (p) => p,
};

// ─────────────────────────── общие операции ───────────────────────────

function searchableText(collection, item) {
  switch (collection) {
    case 'books': return [item.title, item.isbn].join(' ');
    case 'authors': return [item.fullName, item.country].join(' ');
    case 'genres': return [item.name, item.description].join(' ');
    case 'publishers': return [item.name, item.city].join(' ');
    case 'readers': return [item.fullName, item.email, item.phone].join(' ');
    default: return '';
  }
}

function applyFilters(collection, rows, q) {
  let result = rows;

  if (q.search) {
    const needle = String(q.search).toLowerCase();
    result = result.filter((x) => searchableText(collection, x).toLowerCase().includes(needle));
  }

  if (collection === 'books') {
    if (q.genreId) result = result.filter((b) => b.genreIds.includes(Number(q.genreId)));
    if (q.authorId) result = result.filter((b) => b.authorIds.includes(Number(q.authorId)));
    if (q.publisherId) result = result.filter((b) => b.publisherId === Number(q.publisherId));
    if (q.yearFrom) result = result.filter((b) => b.year >= Number(q.yearFrom));
    if (q.yearTo) result = result.filter((b) => b.year <= Number(q.yearTo));
    if (q.available === 'true') result = result.filter((b) => b.copiesAvailable > 0);
  }

  if (collection === 'loans') {
    if (q.readerId) result = result.filter((l) => l.readerId === Number(q.readerId));
    if (q.bookId) result = result.filter((l) => l.bookId === Number(q.bookId));
    if (q.status) {
      result = result.filter((l) => expandLoan(l).status === q.status);
    }
  }

  return result;
}

function applySort(rows, sort) {
  if (!sort) return rows;
  const [field, dirRaw] = String(sort).split(',');
  const dir = (dirRaw || 'asc').toLowerCase() === 'desc' ? -1 : 1;
  return [...rows].sort((a, b) => {
    const av = a[field];
    const bv = b[field];
    if (av == null && bv == null) return 0;
    if (av == null) return 1;
    if (bv == null) return -1;
    if (typeof av === 'number' && typeof bv === 'number') return (av - bv) * dir;
    return String(av).localeCompare(String(bv), 'ru') * dir;
  });
}

function paginate(rows, q) {
  const page = Math.max(1, Number(q.page) || 1);
  const size = Math.min(100, Math.max(1, Number(q.size) || 10));
  const total = rows.length;
  const totalPages = Math.max(1, Math.ceil(total / size));
  return {
    items: rows.slice((page - 1) * size, page * size),
    page,
    size,
    total,
    totalPages,
  };
}

// ─────────────────────────────── валидация ───────────────────────────────

function validate(collection, body, id = null) {
  const e = {};
  const str = (v) => (typeof v === 'string' ? v.trim() : '');

  if (collection === 'books') {
    if (!str(body.title)) e.title = 'Укажите название';
    else if (str(body.title).length > 200) e.title = 'Не длиннее 200 символов';

    if (!str(body.isbn)) e.isbn = 'Укажите ISBN';
    else {
      const dup = db.books.find((b) => b.isbn === str(body.isbn) && b.id !== id && !b.deletedAt);
      if (dup) e.isbn = 'Книга с таким ISBN уже существует';
    }

    const year = Number(body.year);
    if (!Number.isInteger(year)) e.year = 'Год — целое число';
    else if (year < 1450) e.year = 'Год не может быть раньше 1450';
    else if (year > new Date().getFullYear()) e.year = 'Год не может быть в будущем';

    if (body.pages != null && (!Number.isInteger(Number(body.pages)) || Number(body.pages) < 1)) {
      e.pages = 'Число страниц — положительное целое';
    }
    if (body.publisherId != null && !db.publishers.find((p) => p.id === Number(body.publisherId) && !p.deletedAt)) {
      e.publisherId = 'Издательство не найдено';
    }
    const copies = Number(body.copiesTotal);
    if (!Number.isInteger(copies) || copies < 0) e.copiesTotal = 'Число экземпляров — целое, не меньше нуля';
  }

  if (collection === 'authors') {
    if (!str(body.fullName)) e.fullName = 'Укажите имя автора';
    if (body.birthYear != null) {
      const y = Number(body.birthYear);
      if (!Number.isInteger(y) || y < 1 || y > new Date().getFullYear()) e.birthYear = 'Некорректный год рождения';
    }
  }

  if (collection === 'genres') {
    if (!str(body.name)) e.name = 'Укажите название жанра';
    else {
      const dup = db.genres.find((g) => g.name.toLowerCase() === str(body.name).toLowerCase() && g.id !== id && !g.deletedAt);
      if (dup) e.name = 'Такой жанр уже существует';
    }
  }

  if (collection === 'publishers') {
    if (!str(body.name)) e.name = 'Укажите название издательства';
    if (body.foundedYear != null) {
      const y = Number(body.foundedYear);
      if (!Number.isInteger(y) || y < 1400 || y > new Date().getFullYear()) e.foundedYear = 'Некорректный год основания';
    }
  }

  if (collection === 'readers') {
    if (!str(body.fullName)) e.fullName = 'Укажите ФИО читателя';
    if (!str(body.email)) e.email = 'Укажите адрес почты';
    else if (!/^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(str(body.email))) e.email = 'Некорректный адрес почты';
    else {
      const dup = db.readers.find((r) => r.email === str(body.email) && r.id !== id && !r.deletedAt);
      if (dup) e.email = 'Читатель с такой почтой уже зарегистрирован';
    }
  }

  return e;
}


function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
  res.setHeader('Vary', 'Origin');
}

function send(res, status, payload) {
  cors(res);
  if (payload === undefined || status === 204) {
    res.writeHead(204);
    res.end();
    return;
  }
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function fail(res, status, message) {
  send(res, status, { message });
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    return null; // признак некорректного JSON
  }
}

function currentUser(req) {
  const header = req.headers['authorization'] || '';
  if (!header.startsWith('Bearer ')) return null;
  const payload = verify(header.slice(7));
  if (!payload || payload.type !== 'access') return null;
  return db.users.find((u) => u.id === payload.sub && !u.deletedAt) || null;
}

const ROLE_LEVEL = { reader: 1, librarian: 2, admin: 3 };

function requireRole(res, user, minRole) {
  if (!user) {
    fail(res, 401, 'Требуется аутентификация');
    return false;
  }
  if (ROLE_LEVEL[user.role] < ROLE_LEVEL[minRole]) {
    fail(res, 403, `Операция доступна начиная с роли «${minRole}»`);
    return false;
  }
  return true;
}

const COLLECTIONS = ['books', 'authors', 'genres', 'publishers', 'readers', 'loans'];

// ─────────────────────────────── маршруты ───────────────────────────────

async function handle(req, res, url) {
  const q = Object.fromEntries(url.searchParams.entries());
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const method = req.method.toUpperCase();
  const user = currentUser(req);

  if (q.__fail) {
    return fail(res, Number(q.__fail), 'Ошибка вызвана намеренно параметром __fail');
  }

  // ── служебные ──
  if (path === '/api/__reset' && method === 'POST') {
    seed();
    return send(res, 200, { message: 'Данные восстановлены в исходное состояние' });
  }

  if (path === '/api/__health' && method === 'GET') {
    return send(res, 200, { status: 'ok', time: new Date().toISOString() });
  }

  // ── аутентификация ──
  if (path === '/api/auth/register' && method === 'POST') {
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const errors = {};
    const username = String(body.username || '').trim();
    const password = String(body.password || '');
    if (username.length < 3) errors.username = 'Логин не короче трёх символов';
    else if (db.users.find((u) => u.username === username)) errors.username = 'Такой логин уже занят';
    if (password.length < 8) errors.password = 'Пароль не короче восьми символов';
    else if (!/\d/.test(password)) errors.password = 'Пароль должен содержать цифру';
    if (body.email && !/^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(String(body.email)))
      errors.email = 'Некорректный адрес почты';

    if (Object.keys(errors).length) {
      return send(res, 422, { message: 'Ошибка валидации', errors });
    }

    const id = push('users', {
      username,
      passwordHash: hash(password),
      fullName: String(body.fullName || username),
      email: String(body.email || ''),
      role: 'reader',
      readerId: null,
    });
    return send(res, 201, expandUser(db.users.find((u) => u.id === id)));
  }

  if (path === '/api/auth/login' && method === 'POST') {
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const found = db.users.find(
      (u) => u.username === String(body.username || '').trim() && !u.deletedAt
    );
    if (!found || found.passwordHash !== hash(String(body.password || ''))) {
      return fail(res, 401, 'Неверный логин или пароль');
    }

    const now = Math.floor(Date.now() / 1000);
    const accessToken = sign({ sub: found.id, role: found.role, type: 'access', exp: now + ACCESS_TTL });
    const refreshToken = sign({ sub: found.id, type: 'refresh', exp: now + REFRESH_TTL });
    db.refreshTokens.add(refreshToken);

    return send(res, 200, {
      accessToken,
      refreshToken,
      expiresIn: ACCESS_TTL,
      user: expandUser(found),
    });
  }

  if (path === '/api/auth/refresh' && method === 'POST') {
    const body = await readBody(req);
    const token = body && body.refreshToken;
    const payload = verify(token);
    if (!payload || payload.type !== 'refresh' || !db.refreshTokens.has(token)) {
      return fail(res, 401, 'Токен обновления недействителен');
    }
    const found = db.users.find((u) => u.id === payload.sub);
    if (!found) return fail(res, 401, 'Пользователь не найден');

    db.refreshTokens.delete(token);
    const now = Math.floor(Date.now() / 1000);
    const accessToken = sign({ sub: found.id, role: found.role, type: 'access', exp: now + ACCESS_TTL });
    const refreshToken = sign({ sub: found.id, type: 'refresh', exp: now + REFRESH_TTL });
    db.refreshTokens.add(refreshToken);

    return send(res, 200, { accessToken, refreshToken, expiresIn: ACCESS_TTL, user: expandUser(found) });
  }

  if (path === '/api/auth/me' && method === 'GET') {
    if (!user) return fail(res, 401, 'Требуется аутентификация');
    return send(res, 200, expandUser(user));
  }

  if (path === '/api/auth/logout' && method === 'POST') {
    const body = await readBody(req);
    if (body && body.refreshToken) db.refreshTokens.delete(body.refreshToken);
    return send(res, 204);
  }

  // ── управление пользователями (только admin) ──
  if (path === '/api/users' && method === 'GET') {
    if (!requireRole(res, user, 'admin')) return;
    const rows = applySort(db.users.filter((u) => !u.deletedAt), q.sort);
    const page = paginate(rows, q);
    return send(res, 200, { ...page, items: page.items.map(expandUser) });
  }

  // ── специальные операции с выдачами ──
  if (path === '/api/loans' && method === 'POST') {
    if (!requireRole(res, user, 'librarian')) return;
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const errors = {};
    const reader = db.readers.find((r) => r.id === Number(body.readerId) && !r.deletedAt);
    const book = db.books.find((b) => b.id === Number(body.bookId) && !b.deletedAt);
    if (!reader) errors.readerId = 'Читатель не найден';
    if (!book) errors.bookId = 'Книга не найдена';
    const days = Number(body.days || 14);
    if (!Number.isInteger(days) || days < 1 || days > 90) errors.days = 'Срок от 1 до 90 дней';
    if (Object.keys(errors).length) return send(res, 422, { message: 'Ошибка валидации', errors });

    if (book.copiesAvailable < 1) {
      return fail(res, 409, 'Нет свободных экземпляров этой книги');
    }

    const issuedAt = new Date();
    const dueAt = new Date(issuedAt.getTime() + days * 86400000);
    const id = push('loans', {
      readerId: reader.id,
      bookId: book.id,
      issuedAt: issuedAt.toISOString(),
      dueAt: dueAt.toISOString(),
      returnedAt: null,
    });
    book.copiesAvailable -= 1;
    return send(res, 201, expandLoan(db.loans.find((l) => l.id === id)));
  }

  let m = path.match(/^\/api\/loans\/(\d+)\/return$/);
  if (m && method === 'POST') {
    if (!requireRole(res, user, 'librarian')) return;
    const loan = db.loans.find((l) => l.id === Number(m[1]) && !l.deletedAt);
    if (!loan) return fail(res, 404, 'Выдача не найдена');
    if (loan.returnedAt) return fail(res, 409, 'Выдача уже закрыта');

    loan.returnedAt = new Date().toISOString();
    const book = db.books.find((b) => b.id === loan.bookId);
    if (book) book.copiesAvailable = Math.min(book.copiesTotal, book.copiesAvailable + 1);
    return send(res, 200, expandLoan(loan));
  }

  m = path.match(/^\/api\/loans\/(\d+)\/extend$/);
  if (m && method === 'POST') {
    if (!user) return fail(res, 401, 'Требуется аутентификация');
    const loan = db.loans.find((l) => l.id === Number(m[1]) && !l.deletedAt);
    if (!loan) return fail(res, 404, 'Выдача не найдена');
    if (loan.returnedAt) return fail(res, 409, 'Нельзя продлить закрытую выдачу');

    // Клиент (reader) — только свои заказы; менеджер/админ — любые.
    if (user.role === 'reader' && loan.readerId !== user.readerId) {
      return fail(res, 403, 'Недостаточно прав для продления чужого заказа');
    }
    if (user.role !== 'reader' && !requireRole(res, user, 'librarian')) return;

    const body = await readBody(req);
    const days = Math.max(1, Number((body && body.days) || 14));
    const base = new Date(loan.dueAt);
    base.setUTCDate(base.getUTCDate() + days);
    loan.dueAt = base.toISOString();
    return send(res, 200, expandLoan(loan));
  }

  // ── единообразный CRUD ──
  m = path.match(/^\/api\/([a-z]+)(?:\/(\d+))?(?:\/(restore))?$/);
  const bulk = path.match(/^\/api\/([a-z]+)\/bulk-delete$/);

  if (bulk && method === 'POST') {
    const collection = bulk[1];
    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');
    if (!requireRole(res, user, 'librarian')) return;

    const body = await readBody(req);
    const ids = Array.isArray(body && body.ids) ? body.ids.map(Number) : [];
    if (!ids.length) return send(res, 422, { message: 'Ошибка валидации', errors: { ids: 'Передайте непустой список идентификаторов' } });

    let deleted = 0;
    for (const row of db[collection]) {
      if (ids.includes(row.id) && !row.deletedAt) {
        row.deletedAt = new Date().toISOString();
        deleted += 1;
      }
    }
    return send(res, 200, { deleted });
  }

  if (m) {
    const collection = m[1];
    const id = m[2] ? Number(m[2]) : null;
    const action = m[3] || null;

    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');
    const expand = EXPANDERS[collection];

    // восстановление
    if (action === 'restore' && method === 'POST') {
      if (!requireRole(res, user, 'admin')) return;
      const row = db[collection].find((x) => x.id === id);
      if (!row) return fail(res, 404, 'Объект не найден');
      row.deletedAt = null;
      return send(res, 200, expand(row));
    }

    // список
    if (id === null && method === 'GET') {
      let rows = db[collection];
      if (q.includeDeleted !== 'true') rows = rows.filter((x) => !x.deletedAt);

      // читатель видит только свои выдачи
      if (collection === 'loans' && user && user.role === 'reader') {
        rows = rows.filter((l) => l.readerId === user.readerId);
      }

      rows = applyFilters(collection, rows, q);
      rows = applySort(rows, q.sort);
      const page = paginate(rows, q);
      return send(res, 200, { ...page, items: page.items.map(expand) });
    }

    // одна запись
    if (id !== null && method === 'GET') {
      const row = db[collection].find((x) => x.id === id && (q.includeDeleted === 'true' || !x.deletedAt));
      if (!row) return fail(res, 404, 'Объект не найден');
      return send(res, 200, expand(row));
    }

    // создание
    if (id === null && method === 'POST') {
      if (!requireRole(res, user, 'librarian')) return;
      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

      const errors = validate(collection, body);
      if (Object.keys(errors).length) return send(res, 422, { message: 'Ошибка валидации', errors });

      const data = normalize(collection, body);
      const newId = push(collection, data);
      const row = db[collection].find((x) => x.id === newId);
      if (collection === 'books') row.copiesAvailable = row.copiesTotal;
      return send(res, 201, expand(row));
    }

    // изменение
    if (id !== null && (method === 'PUT' || method === 'PATCH')) {
      if (!requireRole(res, user, 'librarian')) return;
      const row = db[collection].find((x) => x.id === id && !x.deletedAt);
      if (!row) return fail(res, 404, 'Объект не найден');

      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

      const merged = method === 'PATCH' ? { ...row, ...body } : body;
      const errors = validate(collection, merged, id);
      if (Object.keys(errors).length) return send(res, 422, { message: 'Ошибка валидации', errors });

      Object.assign(row, normalize(collection, merged));
      if (collection === 'books') {
        const inUse = db.loans.filter((l) => l.bookId === id && !l.returnedAt && !l.deletedAt).length;
        row.copiesAvailable = Math.max(0, row.copiesTotal - inUse);
      }
      return send(res, 200, expand(row));
    }

    // удаление
    if (id !== null && method === 'DELETE') {
      const hard = q.hard === 'true';
      if (!requireRole(res, user, hard ? 'admin' : 'librarian')) return;

      const index = db[collection].findIndex((x) => x.id === id);
      if (index === -1) return fail(res, 404, 'Объект не найден');

      if (hard) {
        if (collection === 'books') {
          const active = db.loans.some((l) => l.bookId === id && !l.returnedAt && !l.deletedAt);
          if (active) return fail(res, 409, 'Книга выдана и не может быть удалена физически');
        }
        if (collection === 'readers') {
          const active = db.loans.some((l) => l.readerId === id && !l.returnedAt && !l.deletedAt);
          if (active) return fail(res, 409, 'У читателя есть незакрытые выдачи');
        }
        db[collection].splice(index, 1);
      } else {
        db[collection][index].deletedAt = new Date().toISOString();
      }
      return send(res, 204);
    }
  }

  return fail(res, 404, `Адрес ${method} ${path} не обслуживается`);
}

function normalize(collection, body) {
  const num = (v) => (v == null || v === '' ? null : Number(v));
  const str = (v) => (v == null ? '' : String(v).trim());
  const ids = (v) => (Array.isArray(v) ? v.map(Number).filter((n) => Number.isInteger(n)) : []);

  switch (collection) {
    case 'books':
      return {
        title: str(body.title),
        isbn: str(body.isbn),
        year: num(body.year),
        pages: num(body.pages),
        publisherId: num(body.publisherId),
        authorIds: ids(body.authorIds),
        genreIds: ids(body.genreIds),
        copiesTotal: num(body.copiesTotal) ?? 0,
      };
    case 'authors':
      return { fullName: str(body.fullName), birthYear: num(body.birthYear), country: str(body.country) };
    case 'genres':
      return { name: str(body.name), description: str(body.description) };
    case 'publishers':
      return { name: str(body.name), city: str(body.city), foundedYear: num(body.foundedYear) };
    case 'readers':
      return { fullName: str(body.fullName), email: str(body.email), phone: str(body.phone) };
    default:
      return { ...body };
  }
}

// ─────────────────────────────── запуск ───────────────────────────────

seed();

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'OPTIONS') {
    cors(res);
    res.writeHead(204);
    return res.end();
  }

  const delay = Number(url.searchParams.get('__delay') || 0);
  if (delay > 0) await new Promise((r) => setTimeout(r, Math.min(delay, 10000)));

  const started = Date.now();
  try {
    await handle(req, res, url);
  } catch (err) {
    console.error(err);
    if (!res.headersSent) fail(res, 500, 'Внутренняя ошибка сервера: ' + err.message);
  }
  console.log(
    `${req.method.padEnd(6)} ${url.pathname}${url.search}  → ${res.statusCode}  ${Date.now() - started} мс`
  );
});

server.listen(PORT, () => {
  console.log('');
  console.log('  Учебное API «Библиотека»');
  console.log(`  Адрес:              http://localhost:${PORT}/api`);
  console.log(`  Разрешённый источник: ${ORIGIN}`);
  console.log(`  Срок жизни токена:  ${ACCESS_TTL} с`);
  console.log('');
  console.log('  Учётные записи:  admin/admin123   manager/manager123   client/client123');
  console.log('  Сброс данных:    POST /api/__reset');
  console.log('  Задержка ответа: любой запрос с ?__delay=1500');
  console.log('  Ошибка по требованию: любой запрос с ?__fail=500');
  console.log('');
});
