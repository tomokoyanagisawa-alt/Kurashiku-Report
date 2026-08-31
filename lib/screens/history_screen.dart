import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/work_log.dart';
import '../providers/work_log_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final ym = DateFormat('yyyy-MM').format(_selectedMonth);
    await context.read<WorkLogProvider>().loadMyWorkLogs(yearMonth: ym);
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset, 1);
    });
    _load();
  }

  Future<void> _confirmDelete(WorkLog log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('${log.workDate} ${log.customerName}様 の記録を削除しますか?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final provider = context.read<WorkLogProvider>();
      final success = await provider.deleteWorkLog(log.workId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '削除しました' : (provider.errorMessage ?? '削除に失敗しました'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkLogProvider>();
    final logs = provider.myWorkLogs;

    double totalHours = 0;
    double totalFare = 0;
    for (final l in logs) {
      totalHours += l.workHours.toDouble();
      totalFare += l.roundTripFare.toDouble();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('入力履歴')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                Text(
                  DateFormat('yyyy年M月', 'ja_JP').format(_selectedMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFF4A86E8).withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('稼働日数', '${logs.length}日'),
                _summaryItem('合計時間', '${totalHours.toStringAsFixed(1)}h'),
                _summaryItem('交通費計', '${totalFare.toStringAsFixed(0)}円'),
              ],
            ),
          ),
          Expanded(
            child: provider.isLoadingLogs
                ? const Center(child: CircularProgressIndicator())
                : logs.isEmpty
                    ? Center(
                        child: Text('この月の記録はまだありません',
                            style: TextStyle(color: Colors.grey.shade500)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF4A86E8).withValues(alpha: 0.12),
                                  child: Text(
                                    log.workDate.split('-').last,
                                    style: const TextStyle(color: Color(0xFF4A86E8), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                title: Text('${log.customerName}様', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${log.startTime} 〜 ${log.endTime}(休憩${log.breakHours}h・延長${log.extraHours}h)'),
                                    Text('実作業 ${log.workHours}h ・ 交通費 ${log.roundTripFare.toStringAsFixed(0)}円',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _confirmDelete(log),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A86E8))),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
