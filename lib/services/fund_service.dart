import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
    
    // 接口定义
    final urls = {
      'gz': 'https://fundgz.1234567.com.cn/js/$code.js?rt=$timestamp',
      // 使用更可靠的网页版接口获取历史净值和最新官方数据
      'lsjz': 'https://api.fund.eastmoney.com/f10/lsjz?fundCode=$code&pageIndex=1&pageSize=1',
    };

    // 安全请求函数
    Future<dynamic> safeGet(String url, {bool isJsonp = false}) async {
      try {
        final request = await _httpClient.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 3));
        
        // 关键：添加标准浏览器请求头
        request.headers.add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
        request.headers.add('Referer', 'https://fundf10.eastmoney.com/'); // 针对 api.fund.eastmoney.com 的关键 Referer
        request.headers.add('Accept', 'application/json, text/javascript, */*; q=0.01');
        
        final response = await request.close();
        if (response.statusCode != 200) {
          debugPrint('HTTP Error (${response.statusCode}): $url');
          return null;
        }
        
        final bytes = await response.fold<List<int>>([], (p, e) => p..addAll(e));
        final body = utf8.decode(bytes, allowMalformed: true);
        
        if (isJsonp) {
          final start = body.indexOf('(') + 1;
          final end = body.lastIndexOf(')');
          if (start > 0 && end > start) return json.decode(body.substring(start, end));
        } else {
          return json.decode(body);
        }
      } catch (e) {
        debugPrint('Fetch Error ($url): $e');
      }
      return null;
    }

    // 并行抓取（估值和官方净值）
    final results = await Future.wait([
      safeGet(urls['gz']!, isJsonp: true),
      safeGet(urls['lsjz']!),
    ]);

    final gzData = results[0] as Map<String, dynamic>?;
    final lsjzFull = results[1] as Map<String, dynamic>?;

    // 解析官方历史净值列表中的最新一条
    Map<String, dynamic>? officialData;
    if (lsjzFull != null && lsjzFull['Data'] != null && lsjzFull['Data']['LSJZList'] != null) {
      final list = lsjzFull['Data']['LSJZList'] as List;
      if (list.isNotEmpty) {
        officialData = list[0] as Map<String, dynamic>;
      }
    }

    if (gzData != null) {
      final jzrqGz = gzData['jzrq']?.toString() ?? '';
      final jzrqOfficial = officialData?['FSRQ']?.toString() ?? '';
      
      // 找出最晚的日期
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
    return null;
  }

  Future<FundEstimate?> _fetchSina(String code) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Sina API with HTTPS
      final url = 'https://hq.sinajs.cn/list=f_$code?_=$timestamp';
      final request = await _httpClient.getUrl(Uri.parse(url));
      
      // Critical for Sina:
      request.headers.add('Referer', 'https://finance.sina.com.cn');
      
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (p, e) => p..addAll(e));
        final body = utf8.decode(bytes, allowMalformed: true);
        
        // Format: var hq_str_f_161725="招商中证白酒指数(LOF)A,0.6372,0.6372,0.6372,2026-04-23,0.67";
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
              gsz: parts[1], 
              gszzl: parts[5],
              gztime: '${parts[4]} 15:00', // Sina's daily data is as of 15:00
              lzzl: parts[5], // On Sina, the change is the official one for that date
            );
          }
        }
      }
    } catch (e) {
      print('Error fetching Sina $code: $e');
    }
    return null;
  }
}
