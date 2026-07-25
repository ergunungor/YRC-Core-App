import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // debugPrint için

class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  // BURASI ÇOK ÖNEMLİ: Gerçek veya uydurma ama formatı doğru bir mail adresi ekle
  // Kendi mailini yazman en garantisidir.
  static const Map<String, String> _headers = {
    'User-Agent': 'YRCCoreApp/1.0 (ergun6e@gmail.com)',
  };

  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(
      '$_baseUrl/search?q=${Uri.encodeComponent(query)}&format=jsonv2&limit=5&countrycodes=tr',
    );

    final response = await http.get(uri, headers: _headers);

    // EĞER HATA VARSA TAM OLARAK NE OLDUĞUNU KONSOLA YAZDIRALIM
    if (response.statusCode != 200) {
      debugPrint('Nominatim API Hatası! Status: ${response.statusCode}');
      debugPrint('Dönen Cevap: ${response.body}');
      throw Exception('API Hatası: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.cast<Map<String, dynamic>>();
  }

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/reverse?lat=$latitude&lon=$longitude&format=jsonv2',
    );

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);
    return data['display_name'];
  }
}
