import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../lib/inventory_store.dart';
import '../lib/telegram_service.dart';

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final dataFile = Platform.environment['DATA_FILE'] ?? 'data/inventory.json';
  final store = InventoryStore(dataFile);
  final telegram = TelegramService();
  await store.load();

  Future<bool> sendTelegram(String token, String chatId, String text) =>
      telegram.sendMessage(token: token, chatId: chatId, text: text);

  Future<void> checkAndLog() async {
    final result = await store.checkStocks(sendTelegram);
    stdout.writeln(
        '[StockAlert] ${result['checked']} produtos verificados; ${result['sent']} alertas enviados.');
  }

  final server = await HttpServer.bind('0.0.0.0', port);
  stdout.writeln('[StockAlert] Dart backend em http://0.0.0.0:$port');
  await checkAndLog();
  final minutes =
      int.tryParse(Platform.environment['SCHEDULE_MINUTES'] ?? '') ?? 5;
  Timer.periodic(Duration(minutes: minutes), (_) => checkAndLog());

  await for (final request in server) {
    _handle(request, store, checkAndLog);
  }
}

Future<void> _handle(HttpRequest request, InventoryStore store,
    Future<void> Function() checkAndLog) async {
  request.response.headers
    ..set('content-type', 'application/json; charset=utf-8')
    ..set('access-control-allow-origin', '*')
    ..set('access-control-allow-methods',
        'GET, POST, PUT, PATCH, DELETE, OPTIONS')
    ..set('access-control-allow-headers', 'content-type');
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  try {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/api/health')
      return await _json(
          request, {'status': 'ok', 'service': 'stockalert-dart'});
    if (request.method == 'GET' && path == '/api/dashboard')
      return await _json(request, store.dashboard());
    if (request.method == 'GET' && path == '/api/products')
      return await _json(request, {'products': store.products});
    if (request.method == 'GET' && path == '/api/settings')
      return await _json(request, {'settings': store.publicSettings()});
    if (request.method == 'GET' && path == '/api/alerts')
      return await _json(request, {'alerts': store.alerts});
    if (request.method == 'POST' && path == '/api/alerts/check') {
      await checkAndLog();
      return await _json(
          request, {'checked': store.products.length, 'created': 0, 'sent': 0});
    }

    final segments = path.split('/').where((part) => part.isNotEmpty).toList();
    if (segments.length >= 3 &&
        segments[0] == 'api' &&
        segments[1] == 'products') {
      final id = int.tryParse(segments[2]);
      if (id == null)
        return await _json(request, {'error': 'ID inválido'}, status: 400);
      if (request.method == 'DELETE' && segments.length == 3) {
        store.deleteProduct(id);
        await store.save();
        return await _json(request, {'success': true});
      }
      if (request.method == 'PATCH' && segments.length == 3) {
        final body = await _body(request);
        final product = store.updateProduct(id, body);
        await store.save();
        return await _json(request, {'product': product});
      }
      if (request.method == 'POST' &&
          segments.length == 4 &&
          segments[3] == 'adjust') {
        final body = await _body(request);
        final product = store.adjustStock(id, (body['change'] as num).toInt(),
            body['reason'] as String? ?? 'Ajuste manual');
        await store.save();
        return await _json(request, {'product': product});
      }
    }
    if (request.method == 'POST' && path == '/api/products') {
      final product = store.createProduct(await _body(request));
      await store.save();
      return await _json(request, {'product': product}, status: 201);
    }
    if (request.method == 'PUT' && path == '/api/settings') {
      final settings = store.saveSettings(await _body(request));
      await store.save();
      return await _json(request, {'settings': settings});
    }
    if (request.method == 'POST' && path == '/api/settings/test') {
      final body = await _body(request);
      final ok = await TelegramService().sendMessage(
          token: body['botToken'] as String,
          chatId: body['chatId'] as String,
          text: 'StockAlert conectado. Os alertas estão prontos.');
      if (!ok)
        return await _json(request, {'error': 'Telegram recusou a mensagem.'},
            status: 502);
      return await _json(request, {'success': true});
    }
    return await _json(request, {'error': 'Rota não encontrada.'}, status: 404);
  } on StateError catch (error) {
    return await _json(request, {'error': error.message}, status: 400);
  } catch (error) {
    stderr.writeln('[StockAlert] $error');
    return await _json(request, {'error': 'Erro interno do servidor.'},
        status: 500);
  }
}

Future<Map<String, dynamic>> _body(HttpRequest request) async =>
    jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;

Future<void> _json(HttpRequest request, Map<String, dynamic> body,
    {int status = 200}) async {
  request.response.statusCode = status;
  request.response.write(jsonEncode(body));
  await request.response.close();
}
