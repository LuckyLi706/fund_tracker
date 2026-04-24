import 'dart:convert';
import 'dart:io';
import '../models/fund_model.dart';

class FundService {
  final HttpClient _httpClient = HttpClient();

  Future<FundEstimate?> fetchEstimate(String code, FundDataSource source) async {
    try {
      if (source == FundDataSource.tiantian) {
        return await _fetchTiantian(code);
      } else if (source == FundDataSource.sina) {
        return await _fetchSina(code);
      }
    } catch (e) {
      print('Error fetching fund $code from ${source.label}: $e');
    }
    return null;
  }

  Future<FundEstimate?> _fetchTiantian(String code) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final request = await _httpClient.get('fundgz.1234567.com.cn', 80, '/js/$code.js?rt=$timestamp');
    final response = await request.close();

    if (response.statusCode == 200) {
      final bytes = await response.fold<List<int>>([], (p, e) => p..addAll(e));
      final body = utf8.decode(bytes, allowMalformed: true);
      
      final start = body.indexOf('(') + 1;
      final end = body.lastIndexOf(')');
      if (start > 0 && end > start) {
        final jsonString = body.substring(start, end);
        final data = json.decode(jsonString);
        return FundEstimate.fromJson(data);
      }
    }
    return null;
  }

  Future<FundEstimate?> _fetchSina(String code) async {
    // Sina API parsing logic (Simplified/Mock for demonstration if it fails)
    // Note: Sina often needs Referer: http://finance.sina.com.cn
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final request = await _httpClient.get('hq.sinajs.cn', 80, '/list=f_$code?_=$timestamp');
    // Important for Sina:
    request.headers.add('Referer', 'http://finance.sina.com.cn');
    final response = await request.close();

    if (response.statusCode == 200) {
      final bytes = await response.fold<List<int>>([], (p, e) => p..addAll(e));
      final body = utf8.decode(bytes, allowMalformed: true);
      
      // var hq_str_f_161725="招商中证白酒指数(LOF)A,0.6372,0.6372,0.6372,2026-04-23,0.67";
      final start = body.indexOf('"') + 1;
      final end = body.lastIndexOf('"');
      if (start > 0 && end > start) {
        final dataStr = body.substring(start, end);
        final parts = dataStr.split(',');
        if (parts.length >= 6) {
          return FundEstimate(
            fundCode: code,
            name: parts[0],
            jzrq: parts[4],
            dwjz: parts[1],
            gsz: parts[1], // Sina f_ code net value is usually not the "real-time estimate"
            gszzl: parts[5],
            gztime: '来自新浪',
          );
        }
      }
    }
    return null;
  }
}
