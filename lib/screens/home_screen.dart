import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/station_route.dart';
import '../models/work_log.dart';
import '../providers/auth_provider.dart';
import '../providers/work_log_provider.dart';
import '../widgets/station_route_dialog.dart';
import 'history_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  /// 修正・再送信の場合、対象のWorkLogを渡す。nullの場合は新規登録画面として動作する。
  final WorkLog? editLog;

  const HomeScreen({super.key, this.editLog});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _workDate = DateTime.now();
  Customer? _selectedCustomer;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  double _breakHours = 0;
  double _extraHours = 0;
  StationRoute? _selectedRoute;
  final _noteController = TextEditingController();

  bool _isSubmitting = false;

  bool get _isEditing => widget.editLog != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  TimeOfDay? _parseTimeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  void _prefillFromEditLog() {
    final log = widget.editLog;
    if (log == null) return;
    setState(() {
      _workDate = DateTime.tryParse(log.workDate) ?? DateTime.now();
      _startTime = _parseTimeOfDay(log.startTime);
      _endTime = _parseTimeOfDay(log.endTime);
      _breakHours = log.breakHours.toDouble();
      _extraHours = log.extraHours.toDouble();
      _noteController.text = log.note;
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final provider = context.read<WorkLogProvider>();
    await Future.wait([
      provider.loadCustomers(),
      provider.loadStationRoutes(),
    ]);
    if (!mounted) return;
    if (_isEditing) {
      _prefillFromEditLog();
      final log = widget.editLog!;
      // 顧客・駅ペアの選択状態を、読み込んだ一覧の中から一致するものに設定する
      Customer? matchedCustomer;
      for (final c in provider.customers) {
        if (c.customerId == log.customerId) {
          matchedCustomer = c;
          break;
        }
      }
      StationRoute? matchedRoute;
      if (log.fromStation.isNotEmpty && log.toStation.isNotEmpty) {
        for (final r in provider.stationRoutes) {
          if (r.fromStation == log.fromStation && r.toStation == log.toStation) {
            matchedRoute = r;
            break;
          }
        }
      }
      setState(() {
        _selectedCustomer = matchedCustomer;
        _selectedRoute = matchedRoute;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _workDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) setState(() => _workDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ??
          TimeOfDay(hour: isStart ? 9 : 17, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // 実作業時間は「開始時刻・終了時刻・休憩時間」の3要素のみから計算する。
  // 終了時刻は延長時間も含めて実際に終了した時刻を入力してもらう運用のため、
  // 延長時間(_extraHours)は記録用の参考値であり、この計算には含めない。
  double? get _estimatedWorkHours {
    if (_startTime == null || _endTime == null) return null;
    final startMin = _startTime!.hour * 60 + _startTime!.minute;
    var endMin = _endTime!.hour * 60 + _endTime!.minute;
    if (endMin < startMin) endMin += 24 * 60;
    final total = (endMin - startMin) / 60.0 - _breakHours;
    return double.parse(total.toStringAsFixed(2));
  }

  Future<void> _addStationRoute() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const StationRouteDialog(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('駅ペアを登録しました')),
      );
    }
  }

  Future<void> _submit() async {
    if (_selectedCustomer == null) {
      _showSnack('お客様を選択してください');
      return;
    }
    if (_startTime == null || _endTime == null) {
      _showSnack('開始時刻・終了時刻を入力してください');
      return;
    }
    final workHours = _estimatedWorkHours;
    if (workHours == null || workHours <= 0) {
      _showSnack('実作業時間が0以下になっています。時刻・休憩・延長時間を確認してください');
      return;
    }

    setState(() => _isSubmitting = true);
    final provider = context.read<WorkLogProvider>();
    final dateStr = DateFormat('yyyy-MM-dd').format(_workDate);

    bool success;
    if (_isEditing) {
      success = await provider.updateWorkLog(
        workId: widget.editLog!.workId,
        customerId: _selectedCustomer!.customerId,
        startTime: _formatTime(_startTime!),
        endTime: _formatTime(_endTime!),
        breakHours: _breakHours,
        extraHours: _extraHours,
        roundTripFare: _selectedRoute?.roundTripFare ?? 0,
        fromStation: _selectedRoute?.fromStation ?? '',
        toStation: _selectedRoute?.toStation ?? '',
        note: _noteController.text.trim(),
      );
    } else {
      final result = await provider.addWorkLog(
        workDate: dateStr,
        customerId: _selectedCustomer!.customerId,
        startTime: _formatTime(_startTime!),
        endTime: _formatTime(_endTime!),
        breakHours: _breakHours,
        extraHours: _extraHours,
        roundTripFare: _selectedRoute?.roundTripFare ?? 0,
        fromStation: _selectedRoute?.fromStation ?? '',
        toStation: _selectedRoute?.toStation ?? '',
        note: _noteController.text.trim(),
      );
      success = result != null;
    }

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (success) {
      _showSnack(
        _isEditing ? '業務報告を修正して再送信しました' : '業務報告を送信しました!お疲れ様でした',
        success: true,
      );
      // 送信後は自動的に入力履歴画面へ戻る(本画面は常に入力履歴画面から開くため)
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      _showSnack(provider.errorMessage ?? '送信に失敗しました');
    }
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade600 : Colors.red.shade600,
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('ログアウト')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final workLogProvider = context.watch<WorkLogProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '業務報告の修正' : '本日の業務報告'),
        actions: _isEditing
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: '過去の履歴',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'ログアウト',
                  onPressed: _logout,
                ),
              ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF4A86E8).withValues(alpha: 0.15),
                      child: const Icon(Icons.person, color: Color(0xFF4A86E8)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auth.staffName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('お疲れ様です', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _sectionCard(
              title: '作業日',
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(DateFormat('yyyy年M月d日 (E)', 'ja_JP').format(_workDate)),
                ),
              ),
            ),
            _sectionCard(
              title: 'お客様',
              child: workLogProvider.isLoadingCustomers
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<Customer>(
                      initialValue: _selectedCustomer,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.storefront_outlined),
                        hintText: 'お客様を選択',
                      ),
                      items: workLogProvider.customers
                          .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCustomer = v),
                    ),
            ),
            _sectionCard(
              title: 'サービス時間',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(true),
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: '開始時刻', prefixIcon: Icon(Icons.play_arrow_rounded)),
                            child: Text(_startTime != null ? _formatTime(_startTime!) : '--:--'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(false),
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: '終了時刻', prefixIcon: Icon(Icons.stop_rounded)),
                            child: Text(_endTime != null ? _formatTime(_endTime!) : '--:--'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '※終了時刻は、延長時間も含めて実際に終了した時刻を入力してください',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _numberStepperField(
                          label: '休憩時間(H)',
                          value: _breakHours,
                          icon: Icons.free_breakfast_outlined,
                          onChanged: (v) => setState(() => _breakHours = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _numberStepperField(
                          label: '延長時間(H・記録用)',
                          value: _extraHours,
                          icon: Icons.more_time_rounded,
                          onChanged: (v) => setState(() => _extraHours = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '※延長時間は記録用の参考値です(総労働時間の計算には含まれません。終了時刻に反映してください)',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                  if (_estimatedWorkHours != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A86E8).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '総労働時間(開始・休憩・終了から算出): ${_estimatedWorkHours!.toStringAsFixed(2)} 時間',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A86E8)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _sectionCard(
              title: '往復交通費',
              trailing: TextButton.icon(
                onPressed: _addStationRoute,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新規登録'),
              ),
              child: workLogProvider.isLoadingRoutes
                  ? const LinearProgressIndicator()
                  : workLogProvider.stationRoutes.isEmpty
                      ? Text('登録済みの駅ペアがありません。「新規登録」から追加してください',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
                      : DropdownButtonFormField<StationRoute>(
                          initialValue: _selectedRoute,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.train_outlined),
                            hintText: '駅ペアを選択(交通費が無い場合は未選択)',
                          ),
                          isExpanded: true,
                          items: workLogProvider.stationRoutes
                              .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r.label, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedRoute = v),
                        ),
            ),
            _sectionCard(
              title: '備考(任意)',
              child: TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: '特記事項があれば入力してください'),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(_isEditing ? '修正して再送信する' : '送信する'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child, Widget? trailing}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _numberStepperField({
    required String label,
    required double value,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => onChanged((value - 0.5).clamp(0, 24)),
            child: const Icon(Icons.remove_circle_outline, size: 20),
          ),
          Text(value.toStringAsFixed(1)),
          InkWell(
            onTap: () => onChanged((value + 0.5).clamp(0, 24)),
            child: const Icon(Icons.add_circle_outline, size: 20),
          ),
        ],
      ),
    );
  }
}
