enum FundDataSource {
  tiantian('天天基金', 'fundgz.1234567.com.cn'),
  sina('新浪财经', 'hq.sinajs.cn');

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
    if (lzzl != null) return true; // 如果有官方涨跌幅，必然是官方数据

    try {
      // 提取日期部分进行比较 (格式通常为 yyyy-MM-dd)
      final gzDateStr = gztime.contains(' ') ? gztime.split(' ')[0] : gztime;
      final gzDate = DateTime.parse(gzDateStr);
      final jzDate = DateTime.parse(jzrq);
      
      // 1. 如果估值日期不晚于净值日期，说明显示的是确认值
      if (!gzDate.isAfter(jzDate)) return true;

      // 2. 特殊处理周末：如果今天是周六/周日，且净值日期是周五或更晚，说明官方已更新
      final now = DateTime.now();
      if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
        final diff = now.difference(jzDate).inDays;
        if (diff <= 2) return true; // 周五的净值在周六显示为 official
      }
    } catch (_) {
      // 解析失败时回退到简单的字符串包含判断
      if (gztime.contains(jzrq)) return true;
    }
    
    return false;
  }

  double get displayChangePercent {
    final val = (isOfficial && lzzl != null) ? lzzl : gszzl;
    return double.tryParse(val ?? '0') ?? 0.0;
  }

  bool get isUp => displayChangePercent >= 0;
}
