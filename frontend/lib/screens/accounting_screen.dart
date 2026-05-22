import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/app_controller.dart';
import '../services/proactive_companion.dart';
import '../widgets/tap_scale.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({Key? key}) : super(key: key);

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  List<Map<String, dynamic>> _records = [];
  static const _key = 'warm_accounting';

  final _incomeCategories = ['生活费', '兼职', '奖学金', '红包', '其他'];
  final _expenseCategories = ['餐饮', '交通', '学习', '娱乐', '购物', '住宿', '其他'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      setState(() {
        _records = List<Map<String, dynamic>>.from(jsonDecode(raw));
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_records));
  }

  /// 让小暖根据新增的这笔账主动开口（频次保护交给 ProactiveCompanion）
  ///   - 默认走"accounting_added"，傲娇但克制；
  ///   - 若本月支出占总收入 > 85%，升级为"accounting_over_budget"。
  Future<void> _notifyCompanionOnAdd({required bool isExpense}) async {
    if (!Get.isRegistered<AppController>()) return;
    final ctrl = Get.find<AppController>();

    String eventKey = 'accounting_added';
    if (isExpense && _totalIncome > 0) {
      final ratio = _totalExpense / _totalIncome;
      if (ratio >= 0.85) {
        eventKey = 'accounting_over_budget';
      }
    }
    final text = await ProactiveCompanion.eventMessage(eventKey);
    if (text == null) return;
    ctrl.tellCompanion(text);
  }

  double get _totalIncome => _records
      .where((r) => r['type'] == 'income')
      .fold(0.0, (s, r) => s + (r['amount'] as num).toDouble());

  double get _totalExpense => _records
      .where((r) => r['type'] == 'expense')
      .fold(0.0, (s, r) => s + (r['amount'] as num).toDouble());

  double get _balance => _totalIncome - _totalExpense;

  void _showAddDialog() {
    bool isExpense = true;
    String selectedCategory = _expenseCategories.first;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r)),
            title: const Text('记一笔'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 收支切换
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() {
                            isExpense = true;
                            selectedCategory = _expenseCategories.first;
                          }),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                            decoration: BoxDecoration(
                              color: isExpense
                                  ? Colors.red.withOpacity(0.12)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Center(
                              child: Text(
                                '支出',
                                style: TextStyle(
                                  color: isExpense ? Colors.red : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() {
                            isExpense = false;
                            selectedCategory = _incomeCategories.first;
                          }),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                            decoration: BoxDecoration(
                              color: !isExpense
                                  ? Colors.green.withOpacity(0.12)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Center(
                              child: Text(
                                '收入',
                                style: TextStyle(
                                  color: !isExpense ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // 金额
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '金额（元）',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // 分类
                  Text('分类',
                      style: TextStyle(
                          fontSize: 13.sp, color: Colors.grey[600])),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: (isExpense
                            ? _expenseCategories
                            : _incomeCategories)
                        .map((c) => GestureDetector(
                              onTap: () =>
                                  setDialogState(() => selectedCategory = c),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: selectedCategory == c
                                      ? Theme.of(ctx).primaryColor
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: selectedCategory == c
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  SizedBox(height: 12.h),

                  // 备注
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: '备注（选填）',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('取消')),
              ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(amountCtrl.text.trim());
                  if (amt == null || amt <= 0) {
                    Get.snackbar('提示', '请输入有效金额',
                        snackPosition: SnackPosition.TOP);
                    return;
                  }
                  final now = DateTime.now();
                  setState(() {
                    _records.insert(0, {
                      'id': now.millisecondsSinceEpoch.toString(),
                      'type': isExpense ? 'expense' : 'income',
                      'amount': amt,
                      'category': selectedCategory,
                      'note': noteCtrl.text.trim(),
                      'date': now.toIso8601String(),
                    });
                  });
                  _save();
                  Get.back();
                  // 小暖观察：新增一笔 → 看是否触发"超预算"傲娇提醒
                  _notifyCompanionOnAdd(isExpense: isExpense);
                },
                child: const Text('记录'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _delete(int index) {
    setState(() => _records.removeAt(index));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(title: const Text('暖账')),
      body: Column(
        children: [
          // 统计卡片
          Container(
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                Text(
                  '结余',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 13.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  '¥ ${_balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('收入', _totalIncome, Colors.greenAccent),
                    Container(width: 1, height: 30.h, color: Colors.white24),
                    _buildStatItem('支出', _totalExpense, Colors.orangeAccent),
                  ],
                ),
              ],
            ),
          ),

          // 记录列表
          Expanded(
            child: _records.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    itemCount: _records.length,
                    itemBuilder: (ctx, i) => _buildRecord(_records[i], i),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  Widget _buildStatItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
        SizedBox(height: 4.h),
        Text(
          '¥ ${value.toStringAsFixed(2)}',
          style: TextStyle(
              color: color, fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 64.sp, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text('还没有记账记录',
              style: TextStyle(color: Colors.grey[500], fontSize: 15.sp)),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
            label: const Text('记一笔'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecord(Map<String, dynamic> r, int index) {
    final isIncome = r['type'] == 'income';
    final dt = DateTime.tryParse(r['date'] ?? '');
    final dateStr = dt != null ? '${dt.month}/${dt.day}' : '';
    final color = isIncome ? Colors.green : Colors.red;

    return TapScale(
      onTap: () {},
      child: Dismissible(
        key: Key(r['id'] as String),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.w),
          color: Colors.red.shade100,
          child: const Icon(Icons.delete_outline, color: Colors.red),
        ),
        onDismissed: (_) => _delete(index),
        child: Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: color,
                    size: 20.sp,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['category'] as String,
                        style: TextStyle(
                            fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    if ((r['note'] as String).isNotEmpty)
                      Text(r['note'] as String,
                          style: TextStyle(
                              fontSize: 12.sp, color: Colors.grey[500])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}¥${(r['amount'] as num).toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                  Text(dateStr,
                      style:
                          TextStyle(fontSize: 11.sp, color: Colors.grey[400])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
