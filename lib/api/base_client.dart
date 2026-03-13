import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = "http://52.187.89.101:9000/api";
// const String baseUrl = "https://app.cubehous.com/api";

class BaseClient {
  static const int timeoutDuration = 30; // seconds

  // GET request
  static Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
      ).timeout(
        const Duration(seconds: timeoutDuration),
        onTimeout: () => throw TimeoutException('Request timeout'),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('GET Request failed: $e');
    }
  }

  // POST request
  static Future<dynamic> post(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: timeoutDuration),
        onTimeout: () => throw TimeoutException('Request timeout'),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('POST Request failed: $e');
    }
  }

  // PUT request
  static Future<dynamic> put(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: timeoutDuration),
        onTimeout: () => throw TimeoutException('Request timeout'),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('PUT Request failed: $e');
    }
  }

  // DELETE request
  static Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
      ).timeout(
        const Duration(seconds: timeoutDuration),
        onTimeout: () => throw TimeoutException('Request timeout'),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('DELETE Request failed: $e');
    }
  }

  // Handle API response
  static dynamic _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        if (response.body.trim().isEmpty) return <String, dynamic>{};
        return jsonDecode(response.body);
      case 400:
        throw BadRequestException(response.body);
      case 401:
        throw UnauthorizedException(response.body);
      case 403:
        throw ForbiddenException(response.body);
      case 404:
        throw NotFoundException(response.body);
      case 500:
        throw InternalServerException(response.body);
      default:
        throw ServerException(
          'Error with status code: ${response.statusCode}',
        );
    }
  }

  // Request headers
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }


}

// Custom Exception Classes
class BadRequestException implements Exception {
  final String message;
  BadRequestException(this.message);

  @override
  String toString() => 'Bad Request: $message';
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);

  @override
  String toString() => 'Unauthorized: $message';
}

class ForbiddenException implements Exception {
  final String message;
  ForbiddenException(this.message);

  @override
  String toString() => 'Forbidden: $message';
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);

  @override
  String toString() => 'Not Found: $message';
}

class InternalServerException implements Exception {
  final String message;
  InternalServerException(this.message);

  @override
  String toString() => 'Internal Server Error: $message';
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);

  @override
  String toString() => 'Server Exception: $message';
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'Timeout: $message';
}
