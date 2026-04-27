import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fast_gbk/fast_gbk.dart';
import '../models/fund_model.dart';

class _RawEstimate {
  final String name;
  final String jzrq;
  final String dwjz;
  final String gsz;
  final String gszzl;
  final String gztime;

  _RawEstimate({
    required this.name,
    required this.jzrq,
    required this.dwjz,
    required this.gsz,
    required this.gszzl,
    required this.gztime,
  });
}

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


  Future<Map<String, dynamic>?> _fetchOfficialData(String code) async {
    final lsjzUrl = 'https://api.fund.eastmoney.com/f10/lsjz?fundCode=$code&pageIndex=1&pageSize=1';
    try {
      final body = await _get(lsjzUrl, headers: {'Referer': 'https://fundf10.eastmoney.com/'}).timeout(const Duration(seconds: 3));
      final jsonResponse = json.decode(body);
      if (jsonResponse != null && jsonResponse['Data'] != null && jsonResponse['Data']['LSJZList'] != null) {
        final list = jsonResponse['Data']['LSJZList'] as List;
        if (list.isNotEmpty) {
          return list[0] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Official Data Fetch Error ($code): $e');
    }
    return null;
  }

  Future<FundEstimate?> fetchEstimate(String code, FundDataSource source) async {
    try {
      _RawEstimate? rawEstimate;
      switch (source) {
        case FundDataSource.tiantian:
          rawEstimate = await _fetchTiantianRaw(code);
          break;
        case FundDataSource.sina:
          rawEstimate = await _fetchSinaRaw(code);
          break;
        case FundDataSource.tencent:
          rawEstimate = await _fetchTencentRaw(code);
          break;
        case FundDataSource.xueqiu:
          rawEstimate = await _fetchXueqiuRaw(code);
          break;
      }

      // 天天基金的逻辑：对于所有数据源，都去拉取天天基金的官方净值数据进行对比和覆盖
      final officialData = await _fetchOfficialData(code);

      if (rawEstimate == null && officialData == null) return null;

      final jzrqGz = rawEstimate?.jzrq ?? '';
      final jzrqOfficial = officialData?['FSRQ']?.toString() ?? '';
      
      var finalJzrq = jzrqGz;
      if (jzrqOfficial.isNotEmpty && jzrqOfficial.compareTo(finalJzrq) > 0) {
        finalJzrq = jzrqOfficial;
      }

      String finalDwjz = rawEstimate?.dwjz ?? officialData?['DWJZ']?.toString() ?? '0.0000';
      if (finalDwjz.isEmpty) {
        finalDwjz = officialData?['DWJZ']?.toString() ?? '0.0000';
      }
      
      String? finalLzzl;

      // 如果官方日期是最新的，或者没有估算数据，则使用官方数据
      if (jzrqOfficial.isNotEmpty && (jzrqOfficial == finalJzrq || rawEstimate == null)) {
        finalDwjz = officialData?['DWJZ']?.toString() ?? finalDwjz;
        finalLzzl = officialData?['JZZZL']?.toString();
      }

      return FundEstimate(
        fundCode: code,
        name: (rawEstimate?.name != null && rawEstimate!.name.isNotEmpty) ? rawEstimate.name : (officialData?['SHORTNAME'] ?? ''),
        jzrq: finalJzrq,
        dwjz: finalDwjz,
        gsz: rawEstimate?.gsz ?? '',
        gszzl: rawEstimate?.gszzl ?? '',
        gztime: rawEstimate?.gztime ?? '',
        lzzl: finalLzzl,
      );
    } catch (e) {
      debugPrint('Error fetching fund $code from ${source.label}: $e');
    }
    return null;
  }

  Future<_RawEstimate?> _fetchTiantianRaw(String code) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final gzUrl = 'https://fundgz.1234567.com.cn/js/$code.js?rt=$timestamp';
    try {
      final gzBody = await _get(gzUrl).timeout(const Duration(seconds: 3));
      if (gzBody.contains('(')) {
        final start = gzBody.indexOf('(') + 1;
        final end = gzBody.lastIndexOf(')');
        if (start > 0 && end > start) {
          final gzData = json.decode(gzBody.substring(start, end));
          return _RawEstimate(
            name: gzData['name']?.toString() ?? '',
            jzrq: gzData['jzrq']?.toString() ?? '',
            dwjz: gzData['dwjz']?.toString() ?? '',
            gsz: gzData['gsz']?.toString() ?? '',
            gszzl: gzData['gszzl']?.toString() ?? '',
            gztime: gzData['gztime']?.toString() ?? '',
          );
        }
      }
    } catch (e) {
      debugPrint('Tiantian GZ Fetch Error ($code): $e');
    }
    return null;
  }

  Future<_RawEstimate?> _fetchSinaRaw(String code) async {
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

          return _RawEstimate(
            name: parts[0],
            jzrq: parts[4],
            dwjz: parts[3], // Sina provides the previous nav at index 3
            gsz: parts[1], 
            gszzl: growth.toStringAsFixed(2),
            gztime: '${parts[4]} 15:00',
          );
        }
      }
    } catch (e) {
      debugPrint('Sina Error ($code): $e');
    }
    return null;
  }

  Future<_RawEstimate?> _fetchTencentRaw(String code) async {
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
        if (parts.length >= 9) {
          final rawGrowth = double.tryParse(parts[7]) ?? 0.0;
          final formattedGrowth = rawGrowth.toStringAsFixed(2);
          
          return _RawEstimate(
            name: parts[1],
            jzrq: parts[8],
            dwjz: parts[5],
            gsz: parts[5],
            gszzl: formattedGrowth,
            gztime: '${parts[8]} 15:00',
          );
        }
      }
    } catch (e) {
      debugPrint('Tencent Error ($code): $e');
    }
    return null;
  }

  Future<_RawEstimate?> _fetchXueqiuRaw(String code) async {
    try {
      final url = 'https://stock.xueqiu.com/v5/stock/realtime/quotec.json?symbol=F$code';
      final body = await _get(url, headers: {
        'Referer': 'https://xueqiu.com/S/F$code',
        'Cookie': 'xq_a_token=666; ',
      }).timeout(const Duration(seconds: 3));

      if (body.contains('Forbidden')) {
        debugPrint('Xueqiu access forbidden');
        return null;
      }

      final json = jsonDecode(body);
      if (json['data'] != null && json['data'] is List && (json['data'] as List).isNotEmpty) {
        final data = json['data'][0];
        return _RawEstimate(
          name: data['name'] ?? '',
          jzrq: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0).toString().split(' ')[0],
          dwjz: (data['current'] ?? 0).toString(),
          gsz: (data['current'] ?? 0).toString(),
          gszzl: (data['percent'] ?? 0).toString(),
          gztime: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0).toString(),
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
