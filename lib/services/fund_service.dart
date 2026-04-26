import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fast_gbk/fast_gbk.dart';
import '../models/fund_model.dart';

class FundService {
  final HttpClient _httpClient = HttpClient();

  Future<String> _get(String url, {Map<String, String>? headers, bool isGbk = false}) async {
    final request = await _httpClient.getUrl(Uri.parse(url));
    headers?.forEach((key, value) {
      request.headers.add(key, value);
    });
    
    if (headers == null || !headers.containsKey('User-Agent')) {
      request.headers.add('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    }

    final response = await request.close().timeout(const Duration(seconds: 5));
    final bytes = await response.fold<List<int>>([], (p, e) => p..addAll(e));
    
    if (isGbk) {
      return gbk.decode(bytes);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<FundEstimate?> fetchEstimate(String code, FundDataSource source) async {
    try {
      switch (source) {
        case FundDataSource.tiantian:
          return await _fetchTiantian(code);
        case FundDataSource.sina:
          return await _fetchSina(code);
        case FundDataSource.tencent:
          return await _fetchTencent(code);
        case FundDataSource.xueqiu:
          return await _fetchXueqiu(code);
      }
    } catch (e) {
      debugPrint('Error fetching fund $code from ${source.label}: $e');
    }
    return null;
  }

  Future<FundEstimate?> _fetchTiantian(String code) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final gzUrl = 'https://fundgz.1234567.com.cn/js/$code.js?rt=$timestamp';
    final lsjzUrl = 'https://api.fund.eastmoney.com/f10/lsjz?fundCode=$code&pageIndex=1&pageSize=1';

    try {
      final results = await Future.wait([
        _get(gzUrl).timeout(const Duration(seconds: 3)),
        _get(lsjzUrl, headers: {'Referer': 'https://fundf10.eastmoney.com/'}).timeout(const Duration(seconds: 3)),
      ]);

      final gzBody = results[0];
      final lsjzBody = results[1];

      Map<String, dynamic>? gzData;
      final start = gzBody.indexOf('(') + 1;
      final end = gzBody.lastIndexOf(')');
      if (start > 0 && end > start) {
        gzData = json.decode(gzBody.substring(start, end));
      }

      Map<String, dynamic>? officialData;
      final lsjzFull = json.decode(lsjzBody);
      if (lsjzFull != null && lsjzFull['Data'] != null && lsjzFull['Data']['LSJZList'] != null) {
        final list = lsjzFull['Data']['LSJZList'] as List;
        if (list.isNotEmpty) {
          officialData = list[0] as Map<String, dynamic>;
        }
      }

      if (gzData != null) {
        final jzrqGz = gzData['jzrq']?.toString() ?? '';
        final jzrqOfficial = officialData?['FSRQ']?.toString() ?? '';
        var finalJzrq = jzrqGz;
        if (jzrqOfficial.compareTo(finalJzrq) > 0) finalJzrq = jzrqOfficial;

        String finalDwjz = gzData['dwjz']?.toString() ?? '0.0000';
        String? finalLzzl;

        if (finalJzrq == jzrqOfficial && officialData != null) {
          finalDwjz = officialData['DWJZ']?.toString() ?? finalDwjz;
          finalLzzl = officialData['JZZZL']?.toString();
        }

        return FundEstimate(
          fundCode: code,
          name: gzData['name'] ?? '',
          jzrq: finalJzrq,
          dwjz: finalDwjz,
          gsz: gzData['gsz']?.toString() ?? '',
          gszzl: gzData['gszzl']?.toString() ?? '',
          gztime: gzData['gztime']?.toString() ?? '',
          lzzl: finalLzzl,
        );
      }
    } catch (e) {
      debugPrint('Tiantian Fetch Error ($code): $e');
    }
    return null;
  }

  Future<FundEstimate?> _fetchSina(String code) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = 'https://hq.sinajs.cn/list=f_$code?_=$timestamp';
      final body = await _get(url, headers: {
        'Referer': 'https://finance.sina.com.cn',
      }, isGbk: true).timeout(const Duration(seconds: 3));

      final start = body.indexOf('"') + 1;
      final end = body.lastIndexOf('"');
      if (start > 0 && end > start) {
        final dataStr = body.substring(start, end);
        final parts = dataStr.split(',');
        if (parts.length >= 6) {
          final dwjz = double.tryParse(parts[1]) ?? 0.0;
          final prevDwjz = double.tryParse(parts[3]) ?? 0.0;
          double growth = 0.0;
          if (prevDwjz != 0) {
            growth = (dwjz - prevDwjz) / prevDwjz * 100;
          }

          return FundEstimate(
            fundCode: code,
            name: parts[0],
            jzrq: parts[4],
            dwjz: parts[1],
            gsz: parts[1], 
            gszzl: growth.toStringAsFixed(2),
            gztime: '${parts[4]} 15:00',
            lzzl: growth.toStringAsFixed(2),
          );
        }
      }
    } catch (e) {
      debugPrint('Sina Error ($code): $e');
    }
    return null;
  }

  Future<FundEstimate?> _fetchTencent(String code) async {
    try {
      final url = 'https://qt.gtimg.cn/q=jj$code';
      final body = await _get(url, headers: {
        'Referer': 'https://gu.qq.com/',
      }, isGbk: true).timeout(const Duration(seconds: 3));

      final start = body.indexOf('"') + 1;
      final end = body.lastIndexOf('"');
      if (start > 0 && end > start) {
        final dataStr = body.substring(start, end);
        final parts = dataStr.split('~');
        // v_jj161725="161725~招商中证白酒指数(LOF)A~0.0000~0.0000~~0.6402~2.3563~0.4708~2026-04-24~";
        if (parts.length >= 9) {
          final rawGrowth = double.tryParse(parts[7]) ?? 0.0;
          final formattedGrowth = rawGrowth.toStringAsFixed(2);
          
          return FundEstimate(
            fundCode: code,
            name: parts[1],
            jzrq: parts[8],
            dwjz: parts[5],
            gsz: parts[5],
            gszzl: formattedGrowth,
            gztime: '${parts[8]} 15:00',
            lzzl: formattedGrowth,
          );
        }
      }
    } catch (e) {
      debugPrint('Tencent Error ($code): $e');
    }
    return null;
  }

  Future<FundEstimate?> _fetchXueqiu(String code) async {
    try {
      // Xueqiu is currently blocking some environments. 
      // We will try a different endpoint or handle failure gracefully.
      final url = 'https://stock.xueqiu.com/v5/stock/realtime/quotec.json?symbol=F$code';
      final body = await _get(url, headers: {
        'Referer': 'https://xueqiu.com/S/F$code',
        'Cookie': 'xq_a_token=666; ',
      }).timeout(const Duration(seconds: 3));

      if (body.contains('Forbidden')) {
        debugPrint('Xueqiu access forbidden (Blacklisted IP)');
        return null;
      }

      final json = jsonDecode(body);
      if (json['data'] != null && json['data'] is List && (json['data'] as List).isNotEmpty) {
        final data = json['data'][0];
        return FundEstimate(
          fundCode: code,
          name: data['name'] ?? '',
          jzrq: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0).toString().split(' ')[0],
          dwjz: (data['current'] ?? 0).toString(),
          gsz: (data['current'] ?? 0).toString(),
          gszzl: (data['percent'] ?? 0).toString(),
          gztime: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0).toString(),
          lzzl: (data['percent'] ?? 0).toString(),
        );
      }
    } catch (e) {
      debugPrint('Xueqiu Error ($code): $e');
    }
    return null;
  }

  Future<List<FundHistoryItem>> fetchHistory(String code, {int pageSize = 20}) async {
    final url = 'https://api.fund.eastmoney.com/f10/lsjz?fundCode=$code&pageIndex=1&pageSize=$pageSize';
    try {
      final body = await _get(url, headers: {
        'Referer': 'https://fundf10.eastmoney.com/',
      }).timeout(const Duration(seconds: 5));

      final jsonResponse = json.decode(body);
      if (jsonResponse != null && jsonResponse['Data'] != null && jsonResponse['Data']['LSJZList'] != null) {
        final list = jsonResponse['Data']['LSJZList'] as List;
        return list.map((item) => FundHistoryItem.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching history for $code: $e');
    }
    return [];
  }
}
