// lib/services/shop_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'server_config.dart';

class ShopService {
  final AuthService _auth = AuthService();

  Future<List<Map<String, dynamic>>?> fetchShopItems({
    String? itemType,
    String? rarity,
  }) async {
    final token = await _auth.getToken();
    final base = ServerConfig.baseUrl;

    final queryParams = <String, String>{};
    if (itemType != null) queryParams['item_type'] = itemType;
    if (rarity != null) queryParams['rarity'] = rarity;
    if (token != null) queryParams['token'] = token;

    final uri = Uri.parse(
      '$base/shop/items',
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final items = data['items'] as List<dynamic>;
      return items.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchItemDetails(int itemId) async {
    final token = await _auth.getToken();
    final base = ServerConfig.baseUrl;
    final uri = Uri.parse(
      '$base/shop/item/$itemId${token != null ? '?token=$token' : ''}',
    );
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>?> buyItem(int shopItemId) async {
    final token = await _auth.getToken();
    final base = ServerConfig.baseUrl;
    final uri = Uri.parse(
      '$base/shop/buy${token != null ? '?token=$token' : ''}',
    );

    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final resp = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'shop_item_id': shopItemId}),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    return null;
  }

  Future<List<Map<String, dynamic>>?> fetchInventory() async {
    final token = await _auth.getToken();
    final base = ServerConfig.baseUrl;
    final uri = Uri.parse(
      '$base/inventory${token != null ? '?token=$token' : ''}',
    );
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final inventory = data['inventory'] as List<dynamic>;
      return inventory.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  Future<Map<String, dynamic>?> upgradeItem(int inventoryItemId) async {
    final token = await _auth.getToken();
    final base = ServerConfig.baseUrl;
    final uri = Uri.parse(
      '$base/inventory/upgrade${token != null ? '?token=$token' : ''}',
    );
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final resp = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'inventory_item_id': inventoryItemId}),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>?> equipItem(int inventoryItemId) async {
    final token = await _auth.getToken();
    final base = ServerConfig.baseUrl;
    final uri = Uri.parse(
      '$base/inventory/equip${token != null ? '?token=$token' : ''}',
    );
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final resp = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'inventory_item_id': inventoryItemId}),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    return null;
  }
}
