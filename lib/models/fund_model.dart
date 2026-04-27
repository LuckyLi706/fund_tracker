enum FundDataSource {
  tiantian('天天基金', 'fundgz.1234567.com.cn'),
  sina('新浪财经', 'hq.sinajs.cn'),
  tencent('腾讯财经', 'qt.gtimg.cn'),
  xueqiu('雪球', 'stock.xueqiu.com');

  final String label;
  final String domain;
  const FundDataSource(this.label, this.domain);
}

class FundEstimate {
  final String fundCode;
  final String name;
  final String jzrq; // 净值日期
  final String dwjz; // 单位净值
  final String gsz;  // 估算值
  final String gszzl; // 估算增长率
  final String gztime; // 估值时间
  final String? lzzl;  // 官方实际增长率 (Actual Growth Rate)

  FundEstimate({
    required this.fundCode,
    required this.name,
    required this.jzrq,
    required this.dwjz,
    required this.gsz,
    required this.gszzl,
    required this.gztime,
    this.lzzl,
  });

  factory FundEstimate.fromJson(Map<String, dynamic> json) {
    // Standardize data from different sources
    return FundEstimate(
      fundCode: json['fundcode'] ?? json['FCODE'] ?? '',
      name: json['name'] ?? json['SHORTNAME'] ?? '',
      jzrq: json['jzrq'] ?? json['JZRQ'] ?? '',
      dwjz: json['dwjz'] ?? json['DWJZ'] ?? '',
      gsz: json['gsz'] ?? json['GZ'] ?? '',
      gszzl: json['gszzl'] ?? json['GSZZL'] ?? '',
      gztime: json['gztime'] ?? json['GZTIME'] ?? '',
      lzzl: json['LZZL']?.toString(),
    );
  }

  // 判定是否为官方净值
  bool get isOfficial {
    final now = DateTime.now();
    
    // 1. 如果是周末，通常显示官方确认的周五净值
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return true;
    }

    // 2. 检查是否在 9:30 - 15:00 的交易/估值窗口内
    // 在这个窗口内，如果估算数据存在，我们认为它不是“官方最终净值”
    final minutes = now.hour * 60 + now.minute;
    final isValuationWindow = minutes >= 570 && minutes <= 900; // 9:30 - 15:00

    if (isValuationWindow && gsz.isNotEmpty) {
      // 在估值窗口内且有估算值，则不视为官方模式
      return false;
    }

    // 3. 15:00 之后或 9:30 之前的逻辑
    if (gztime.isEmpty) return true;
    
    try {
      final gzDateStr = gztime.contains(' ') ? gztime.split(' ')[0] : gztime;
      
      // 如果估值日期和净值日期一致，说明官方已经同步了该日数据
      if (gzDateStr == jzrq) return true;

      final gzDate = DateTime.parse(gzDateStr);
      final jzDate = DateTime.parse(jzrq);
      
      // 如果估值日期早于净值日期，说明当前是旧数据
      if (gzDate.isBefore(jzDate)) return true;
    } catch (_) {
      if (gztime.contains(jzrq)) return true;
    }
    
    // 默认：如果不在窗口内且日期不匹配，视情况而定
    // 但如果已经过了 15:00 且 jzrq 还没更新，由于 isValuationWindow 为 false，
    // 这里会继续往下走。如果 gzDateStr != jzrq，则返回 false（显示估算值直到真实值出现）
    return false;
  }

  String get displayNetValue {
    // 严格遵循逻辑：官方模式显示 dwjz，估算模式显示 gsz
    if (isOfficial) {
      return dwjz.isNotEmpty ? dwjz : gsz;
    } else {
      return gsz.isNotEmpty ? gsz : dwjz;
    }
  }

  String get displayTime {
    return isOfficial ? jzrq : gztime;
  }

  double get displayChangePercent {
    // 官方模式使用官方涨跌幅 (lzzl)，估算模式使用估算涨跌幅 (gszzl)
    final val = isOfficial ? (lzzl ?? gszzl) : (gszzl ?? lzzl);
    return double.tryParse(val ?? '0') ?? 0.0;
  }

  bool get isUp => displayChangePercent >= 0;
}

class FundHistoryItem {
  final String date;
  final double dwjz; // 单位净值
  final double lzzl; // 累计净值增长率 (or daily change rate)

  FundHistoryItem({
    required this.date,
    required this.dwjz,
    required this.lzzl,
  });

  factory FundHistoryItem.fromJson(Map<String, dynamic> json) {
    return FundHistoryItem(
      date: json['FSRQ'] ?? '',
      dwjz: double.tryParse(json['DWJZ']?.toString() ?? '0') ?? 0.0,
      lzzl: double.tryParse(json['JZZZL']?.toString() ?? '0') ?? 0.0,
    );
  }
}
