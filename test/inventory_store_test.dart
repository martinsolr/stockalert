import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../backend/lib/inventory_store.dart';

void main() {
  late Directory temp;
  late InventoryStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('stockalert-test-');
    store = InventoryStore('${temp.path}/inventory.json');
    await store.load();
  });

  tearDown(() => temp.delete(recursive: true));

  test('cria produto e identifica estoque crítico', () {
    final product = store.createProduct({
      'name': 'Teste',
      'sku': 'T-001',
      'category': 'Teste',
      'stock': 2,
      'minimumStock': 5,
      'status': 'active',
    });
    expect(product['stock'], 2);
    expect(store.dashboard()['stats'], containsPair('criticalProducts', 4));
  });

  test('ajuste não permite estoque negativo e registra delta real', () {
    final product = store.adjustStock(1, -100, 'Venda');
    expect(product['stock'], 0);
    expect(store.movements.last['change'], -6);
  });

  test('verificação cria alerta apenas uma vez para o mesmo produto', () async {
    Future<bool> send(String token, String chatId, String message) async =>
        true;
    final first = await store.checkStocks(send);
    final second = await store.checkStocks(send);
    expect(first['created'], 3);
    expect(second['created'], 0);
    expect(store.alerts.length, 3);
  });
}
