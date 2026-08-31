import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/work_log_provider.dart';
import '../services/api_service.dart';

/// 新しい駅ペア(往復交通費)を登録するダイアログ
/// Yahoo!路線情報へのリンクで運賃確認ができる
class StationRouteDialog extends StatefulWidget {
  const StationRouteDialog({super.key});

  @override
  State<StationRouteDialog> createState() => _StationRouteDialogState();
}

class _StationRouteDialogState extends State<StationRouteDialog> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _fareController = TextEditingController();
  bool _isSaving = false;
  bool _isOpeningYahoo = false;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _fareController.dispose();
    super.dispose();
  }

  Future<void> _openYahooTransit() async {
    if (_fromController.text.trim().isEmpty ||
        _toController.text.trim().isEmpty) {
      _showSnack('出発駅と到着駅を入力してください');
      return;
    }
    setState(() => _isOpeningYahoo = true);
    final result = await ApiService.call(
      'staff.getYahooTransitUrl',
      params: {
        'fromStation': _fromController.text.trim(),
        'toStation': _toController.text.trim(),
      },
    );
    setState(() => _isOpeningYahoo = false);

    if (result.ok && result.data != null) {
      final url = result.data!['url']?.toString();
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnack('リンクを開けませんでした');
        }
      }
    } else {
      _showSnack(result.error ?? 'エラーが発生しました');
    }
  }

  Future<void> _save() async {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    final fareText = _fareController.text.trim();

    if (from.isEmpty || to.isEmpty) {
      _showSnack('出発駅と到着駅を入力してください');
      return;
    }
    final fare = num.tryParse(fareText);
    if (fare == null || fare < 0) {
      _showSnack('往復金額を正しく入力してください');
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<WorkLogProvider>();
    final success = await provider.addStationRoute(from, to, fare);
    setState(() => _isSaving = false);

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      _showSnack(provider.errorMessage ?? '登録に失敗しました');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('往復交通費を登録'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'この駅ペアはあなただけが利用できます(他のスタッフには表示されません)。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fromController,
              decoration: const InputDecoration(
                labelText: '出発駅(自宅最寄り駅)',
                prefixIcon: Icon(Icons.train_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _toController,
              decoration: const InputDecoration(
                labelText: '到着駅(現場最寄り駅)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isOpeningYahoo ? null : _openYahooTransit,
              icon: _isOpeningYahoo
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_new, size: 18),
              label: const Text('Yahoo!路線情報で運賃を確認'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fareController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '往復金額(円)',
                prefixIcon: Icon(Icons.payments_outlined),
                suffixText: '円',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('登録'),
        ),
      ],
    );
  }
}
