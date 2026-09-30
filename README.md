# StockAlert Mobile

App mobile em **Dart/Flutter** para monitorar estoque e enviar alertas pelo Telegram.

## Estrutura

- `lib/`: aplicativo Flutter para Android e iOS.
- `lib/models/`: modelos de produtos, alertas e configurações.
- `lib/services/api_service.dart`: cliente HTTP do backend.
- `lib/screens/`: dashboard, catálogo, ajustes e configurações.
- `lib/widgets/`: tema e componentes visuais reutilizáveis.
- `backend/`: API Dart com persistência JSON, scheduler e Telegram Bot API.

## Executar o app Flutter

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Por padrão, o Android usa `http://10.0.2.2:8080/api` como API. Para apontar para um servidor publicado:

```bash
flutter run --dart-define=API_BASE_URL=https://seu-dominio.com/api
```

Em um celular físico, use o IP local do computador, não `10.0.2.2`.

## Executar o backend Dart

```bash
cd backend
dart pub get
dart run bin/server.dart
```

Variáveis opcionais:

```bash
PORT=8080 DATA_FILE=data/inventory.json SCHEDULE_MINUTES=5 dart run bin/server.dart
```

Endpoints principais:

- `GET /api/health`
- `GET /api/dashboard`
- `GET|POST /api/products`
- `PATCH|DELETE /api/products/:id`
- `POST /api/products/:id/adjust`
- `GET|PUT /api/settings`
- `POST /api/settings/test`
- `POST /api/alerts/check`

O token do Telegram fica apenas no arquivo de dados do backend e nunca é enviado de volta ao app. O scheduler verifica os limites, evita alertas duplicados enquanto o produto continua crítico e marca o alerta como resolvido quando o estoque é reposto.

## Marvel App

O Marvel App pode ser usado para prototipar as telas. O produto funcional é este projeto Flutter mobile, que deve ser aberto no Android Studio/Xcode, executado em um dispositivo ou distribuído como APK/IPA.

## GitHub

Repositório privado: https://github.com/martinsolr/stockalert
