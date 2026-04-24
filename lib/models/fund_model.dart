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

  FundEstimate({
    required this.fundCode,
    required this.name,
    required this.jzrq,
    required this.dwjz,
    required this.gsz,
    required this.gszzl,
    required this.gztime,
  });

  factory FundEstimate.fromJson(Map<String, dynamic> json) {
    return FundEstimate(
      fundCode: json['fundcode'] ?? '',
      name: json['name'] ?? '',
      jzrq: json['jzrq'] ?? '',
      dwjz: json['dwjz'] ?? '',
      gsz: json['gsz'] ?? '',
      gszzl: json['gszzl'] ?? '',
      gztime: json['gztime'] ?? '',
    );
  }

  double get changePercent => double.tryParse(gszzl) ?? 0.0;
  bool get isUp => changePercent >= 0;
}
