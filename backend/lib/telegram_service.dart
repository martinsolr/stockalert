import 'dart:convert';

import 'package:http/http.dart' as http;

class TelegramService {
  TelegramService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<bool> sendMessage(
      {required String token,
      required String chatId,
      required String text}) async {
    final response = await _client.post(
        Uri.parse('https://api.telegram.org/bot$token/sendMessage'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'chat_id': chatId, 'text': text}));
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['ok'] == true;
  }
}
