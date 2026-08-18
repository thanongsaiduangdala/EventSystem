import 'auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentType {
  final int id;
  final String paymentTypeName;

  PaymentType({required this.id, required this.paymentTypeName});

  factory PaymentType.fromJson(Map<String, dynamic> json) {
    return PaymentType(
      id: json['PaymentTypeID'] as int,
      paymentTypeName: json['PaymentTypeName'] as String,
    );
  }
}

class OrderModel {
  final int id;
  final int accountId;
  final int paymentTypeId;
  final DateTime? paymentDate;
  final String? proveOfPayment;

  OrderModel({
    required this.id,
    required this.accountId,
    required this.paymentTypeId,
    this.paymentDate,
    this.proveOfPayment,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['OrderID'] as int,
      accountId: json['AccountID'] as int,
      paymentTypeId: json['PaymentTypeID'] as int,
      paymentDate: json['PaymentDateYMDT'] == null
          ? null
          : DateTime.parse(json['PaymentDateYMDT'].toString()),
      proveOfPayment: json['ProveOfPayment'] as String?,
    );
  }
}

class OrdersApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Map<String, String> _authHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (AuthService.currentToken != null) {
      headers['Authorization'] = 'Bearer ${AuthService.currentToken}';
    }
    return headers;
  }

  static Exception _handleError(http.Response response, String fallbackMsg) {
    if (response.statusCode == 401) {
      return Exception('Session expired. Please log in again.');
    }
    if (response.statusCode == 403) {
      return Exception('Developer access required.');
    }
    try {
      final error = jsonDecode(response.body);
      return Exception(error['detail']?.toString() ?? fallbackMsg);
    } catch (_) {
      return Exception(fallbackMsg);
    }
  }

  // ---------------- payment types ----------------

  static Future<List<PaymentType>> getAllPaymentTypes() async {
    final url = Uri.parse('$baseUrl/orders/paymenttype/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => PaymentType.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load payment types');
    }
  }

  // ---------------- orders ----------------

  static Future<List<OrderModel>> getAllOrders() async {
    final url = Uri.parse('$baseUrl/orders/order/all');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load orders');
    }
  }

  static Future<Map<String, dynamic>> createOrder({
    required int accountId,
    required int paymentTypeId,
    String? paymentDateYMDT,
    String? proveOfPayment,
  }) async {
    final url = Uri.parse('$baseUrl/orders/order/create');

    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'AccountID': accountId,
        'PaymentTypeID': paymentTypeId,
        'PaymentDateYMDT': paymentDateYMDT,
        'ProveOfPayment': proveOfPayment,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create order');
    }
  }

  static Future<void> updateOrder({
    required int orderId,
    required int accountId,
    required int paymentTypeId,
    String? paymentDateYMDT,
    String? proveOfPayment,
  }) async {
    final url = Uri.parse('$baseUrl/orders/order/update');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'OrderID': orderId,
        'AccountID': accountId,
        'PaymentTypeID': paymentTypeId,
        'PaymentDateYMDT': paymentDateYMDT,
        'ProveOfPayment': proveOfPayment,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update order');
    }
  }

  static Future<void> deleteOrder(int orderId) async {
    final url = Uri.parse('$baseUrl/orders/order/$orderId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete order');
    }
  }
}
