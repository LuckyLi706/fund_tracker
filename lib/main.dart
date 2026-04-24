import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'providers/fund_provider.dart';
import 'models/fund_model.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => FundProvider(),
      child: const FundApp(),
    ),
  );
}

class FundApp extends StatelessWidget {
  const FundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '基金估算',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('基金实时估算', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FundProvider>().refreshAll(),
          ),
        ],
      ),
      body: Consumer<FundProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.funds.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.funds.isEmpty) {
            return const Center(child: Text('暂无基金，请点击下方添加'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.funds.length,
            itemBuilder: (context, index) {
              final fund = provider.funds[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Slidable(
                  key: Key(fund.fundCode),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio: 0.25,
                    children: [
                      SlidableAction(
                        onPressed: (context) {
                          provider.removeFund(fund.fundCode);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${fund.name} 已移除')),
                          );
                        },
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: '删除',
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                    ],
                  ),
                  child: FundCard(fund: fund, noBottomMargin: true),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加基金代码'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '例如: 161725'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<FundProvider>().addFund(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '数据源选择',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
          ),
          Consumer<FundProvider>(
            builder: (context, provider, child) {
              return Column(
                children: FundDataSource.values.map((source) {
                  return RadioListTile<FundDataSource>(
                    title: Text(source.label),
                    subtitle: Text(source.domain),
                    value: source,
                    groupValue: provider.currentSource,
                    onChanged: (value) {
                      if (value != null) {
                        provider.setDataSource(value);
                      }
                    },
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '关于',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const ListTile(
            title: Text('版本'),
            trailing: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}

class FundCard extends StatelessWidget {
  final FundEstimate fund;
  final bool noBottomMargin;

  const FundCard({super.key, required this.fund, this.noBottomMargin = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = fund.isUp ? Colors.redAccent : Colors.greenAccent;
    final prefix = fund.isUp ? '+' : '';

    return Card(
      margin: noBottomMargin ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fund.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '代码: ${fund.fundCode}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$prefix${fund.gszzl}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '估算净值',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      fund.gsz,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '更新时间',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      fund.gztime,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
