# ТехноМаркет (Flutter Web)

Учебный клиент магазина техники. Репозиторий: WEB-FLUTTER-PROJECT.

# Getting Started

flutter pub get

# Запуск API

cd api
node mock-server.js --port 8080 --origin http://localhost:5555

Если сайт открыт с другого адреса — поменять origin, например:
node mock-server.js --port 8080 --origin http://127.0.0.1:8001

# Запуск веб (разработка)

flutter run -d chrome --web-port=5555

Открыть: http://localhost:5555/

Учётки: admin/admin123, manager/manager123, client/client123

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
flutter build web --release --base-href /WEB-FLUTTER-PROJECT/ --dart-define=API_BASE_URL=http://localhost:8080/api
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

# Куда заходить в приложении

/login — вход (все)
/register — регистрация (все)
/products — каталог (после входа)
/brands /categories /suppliers /customers — справочники (manager, admin)
/orders — заказы клиентов (manager, admin)
/my-orders — свои заказы (client)
/admin/users /admin/stats — админка (admin)
/forbidden — нет доступа

# Скрипты

scripts\build_gh_pages.ps1 — release + base-href + dart-define + 404.html
scripts\build_wasm.ps1 — release --wasm
scripts\serve_web.py — локальный HTTP (нормальные MIME для .mjs/.wasm)
scripts\serve_base_href.ps1 — превью как на Pages
scripts\measure_size.ps1 — замер размера сборки

# Адаптив

F12 далее Ctrl+Shift+M → Responsive → ширины 360, 768, 1280, 1920.
