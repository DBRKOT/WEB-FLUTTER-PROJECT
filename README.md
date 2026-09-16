# ТехноМаркет (Flutter Web)

Учебный клиент магазина техники. Репозиторий: WEB-FLUTTER-PROJECT.

# Getting Started

flutter pub get

# Запуск сервера (PocketBase)

cd pb
.\pocketbase.exe serve --http 127.0.0.1:8090

Панель: http://127.0.0.1:8090/_/  (admin@techmarket.local / admin12345678)
REST API: http://127.0.0.1:8090/api/

Схема данных и тестовые записи:
node setup_schema.js
node seed_data.js

Проверки сервера:
node check_rules.js     — разграничение прав по ролям
node check_session.js   — вход, продление токена, запрет повышения роли

Учебное API из ПР2-ПР6 (api/mock-server.js) в итоговом проекте не используется.

# Запуск веб (разработка)

flutter run -d chrome --web-port=5555

Открыть: http://localhost:5555/

Вход по адресу почты:
client@tm.local / client123456
manager@tm.local / manager123456
admin@tm.local / admin123456

# Проверки

dart format lib test
flutter analyze
flutter test

# Сборка release

Обычная:
flutter build web --release

Для GitHub Pages (подкаталог + API):
.\scripts\build_gh_pages.ps1

Или с своим API:
.\scripts\build_gh_pages.ps1 -ApiBaseUrl "https://5555/api"

Вручную:
flutter build web --release --base-href /WEB-FLUTTER-PROJECT/ --dart-define=API_BASE_URL=http://127.0.0.1:8090/api
Copy-Item -Force build\web\index.html build\web\404.html

С --wasm (сравнение):
.\scripts\build_wasm.ps1

Или:
flutter build web --release --wasm -o build/web_wasm

# Локальный просмотр готовой сборки

Без base-href:
flutter build web --release -o build/web_demo
python scripts\serve_web.py build\web_demo 8001

Открыть: http://127.0.0.1:8001/

С base-href (как на Pages):
.\scripts\build_gh_pages.ps1
.\scripts\serve_base_href.ps1

Открыть: http://localhost:8000/WEB-FLUTTER-PROJECT/

Wasm:
flutter build web --release --wasm -o build/web_wasm_cmp
python scripts\serve_web.py build\web_wasm_cmp 8002

Открыть: http://127.0.0.1:8002/

# Публичный URL

https://dbrkot.github.io/WEB-FLUTTER-PROJECT/

Хостинг: GitHub Pages (ветка gh-pages и/или Actions из .github/workflows/deploy-pages.yml).


# Скрипты

scripts\build_gh_pages.ps1 — release + base-href + dart-define + 404.html
scripts\build_wasm.ps1 — release --wasm
scripts\serve_web.py — локальный HTTP (нормальные MIME для .mjs/.wasm)
scripts\serve_base_href.ps1 — превью как на Pages
scripts\measure_size.ps1 — замер размера сборки

# Адаптив

F12 далее Ctrl+Shift+M далее Responsive далее ширины 360, 768, 1280, 1920.
