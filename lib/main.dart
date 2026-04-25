import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/fund_provider.dart';
import 'models/fund_model.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    
    runApp(
      ChangeNotifierProvider(
        create: (_) => FundProvider(prefs: prefs),
        child: const FundApp(),
      ),
    );
  } catch (e) {
    debugPrint('Error during startup: $e');
    runApp(
      ChangeNotifierProvider(
        create: (_) => FundProvider(),
        child: const FundApp(),
      ),
    );
  }
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
          final codes = provider.codes;
          if (provider.isLoading && codes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (codes.isEmpty) {
            return const Center(child: Text('暂无基金，请点击下方添加'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: codes.length,
            itemBuilder: (context, index) {
              final code = codes[index];
              final estimate = provider.getEstimate(code);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Slidable(
                  key: Key(code),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio: 0.25,
                    children: [
                      SlidableAction(
                        onPressed: (context) {
                          provider.removeFund(code);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('代码 $code 已移除')),
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
                  child: FundCard(
                    fund: estimate, 
                    fundCode: code,
                    noBottomMargin: true
                  ),
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
                final code = controller.text;
                context.read<FundProvider>().addFund(code, onResult: (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '基金 $code 已成功保存到本地' : '基金 $code 添加成功，但本地存储失败'),
                      backgroundColor: success ? Colors.green : Colors.orange,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                });
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
              '系统状态',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
          ),
          Consumer<FundProvider>(
            builder: (context, provider, child) {
              return ListTile(
                title: const Text('本地存储状态'),
                subtitle: Text(provider.isStorageReady ? '已就绪 (数据将持久化保存)' : '未就绪 (点击尝试重新连接存储)'),
                trailing: Icon(
                  provider.isStorageReady ? Icons.check_circle : Icons.error,
                  color: provider.isStorageReady ? Colors.green : Colors.red,
                ),
                onTap: provider.isStorageReady ? null : () async {
                  await provider.reconnectStorage();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.isStorageReady 
                        ? '存储连接成功' 
                        : '连接失败: ${provider.lastStorageError ?? "原因未知"}'),
                      backgroundColor: provider.isStorageReady ? Colors.green : Colors.red,
                    ),
                  );
                },
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
  final FundEstimate? fund;
  final String fundCode;
  final bool noBottomMargin;

  const FundCard({
    super.key, 
    this.fund, 
    required this.fundCode,
    this.noBottomMargin = false
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (fund == null) {
      return Card(
        margin: noBottomMargin ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text('正在加载基金 $fundCode...', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final color = fund!.isUp ? Colors.redAccent : Colors.greenAccent;
    final prefix = fund!.isUp ? '+' : '';

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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              fund!.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (fund!.isOfficial)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.withOpacity(0.5)),
                              ),
                              child: const Text(
                                '官方净值',
                                style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '代码: ${fund!.fundCode}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$prefix${fund!.displayChangePercent}%',
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
                      fund!.isOfficial ? '官方净值' : '估算净值',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      fund!.dwjz,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fund!.isOfficial ? '净值日期' : '更新时间',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      fund!.isOfficial ? fund!.jzrq : fund!.gztime,
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
