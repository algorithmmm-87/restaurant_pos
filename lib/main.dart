import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

// ─────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://pnpajphrizlarmgjjpti.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
        '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBucGFqcGhyaXpsYXJtZ2pqcHRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3ODA0MTMsImV4cCI6MjA5NDM1NjQxM30'
        '.v1DDLHNQU4-Yfee6Xssweq9Diwa6FWspLAP59E-Mz-0',
  );
  runApp(const TastyStationApp());
}

// ─────────────────────────────────────────────
// SUPABASE CLIENT
// ─────────────────────────────────────────────
final _supabase = Supabase.instance.client;

// Converts Uint8List image to base64 data URI for display
String? _bytesToDataUri(Uint8List? bytes) {
  if (bytes == null) return null;
  final b64 = base64Encode(bytes);
  return 'data:image/jpeg;base64,$b64';
}

// ─────────────────────────────────────────────
// EMAIL — Gmail SMTP via mailer
// ─────────────────────────────────────────────
const _gmailAddress = 'thesiscs4@gmail.com';
const _gmailAppPass = 'vfzfbmxrwyfuluvc';
const _senderName   = 'Tasty Station POS';

String _generate8DigitCode() {
  final rng = Random.secure();
  return (10000000 + rng.nextInt(90000000)).toString();
}

Future<bool> _sendCodeEmail(String toEmail, String code) async {
  final smtpServer = gmail(_gmailAddress, _gmailAppPass);
  final message = Message()
    ..from = Address(_gmailAddress, _senderName)
    ..recipients.add(toEmail)
    ..subject = 'Your $_senderName Login Code'
    ..html = '''
      <div style="font-family:sans-serif;max-width:480px;margin:auto;padding:32px;">
        <h2 style="color:#0D9B8A;">$_senderName</h2>
        <p style="font-size:15px;color:#333;">Your permanent login code is:</p>
        <div style="background:#f0faf9;border:2px solid #0D9B8A;border-radius:12px;
                    text-align:center;padding:24px;margin:20px 0;">
          <span style="font-size:36px;font-weight:700;letter-spacing:8px;color:#0D9B8A;">
            $code
          </span>
        </div>
        <p style="font-size:13px;color:#888;">
          This is your <strong>permanent</strong> password. Keep it safe —
          you will use this same code every time you log in.
        </p>
        <p style="font-size:11px;color:#bbb;">
          If you did not request this, please ignore this email.
        </p>
      </div>
    ''';
  try {
    await send(message, smtpServer);
    debugPrint('✅ Email sent to $toEmail');
    return true;
  } on MailerException catch (e) {
    debugPrint('❌ Mailer error: ${e.message}');
    for (final p in e.problems) {
      debugPrint('  Problem: ${p.code} — ${p.msg}');
    }
    return false;
  } catch (e) {
    debugPrint('❌ Unexpected email error: $e');
    return false;
  }
}

// ─────────────────────────────────────────────
// AUTH SERVICE
// ─────────────────────────────────────────────
class AuthService {
  static Future<Map<String, dynamic>> checkEmail(String email) async {
    try {
      final result = await _supabase
          .from('restaurant_users')
          .select('email, restaurant_name')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();
      if (result == null) return {'exists': false};
      return {'exists': true, 'restaurant_name': result['restaurant_name']};
    } catch (e) {
      debugPrint('checkEmail error: $e');
      return {'exists': false};
    }
  }

  static Future<String?> createUserAndSendCode(String email) async {
    final code = _generate8DigitCode();
    try {
      await _supabase.from('restaurant_users').insert({
        'email': email.trim().toLowerCase(),
        'code': code,
        'restaurant_name': 'My Restaurant',
      });
      final sent = await _sendCodeEmail(email, code);
      if (!sent) debugPrint('⚠️ Email send failed — code: $code');
      return code;
    } catch (e) {
      debugPrint('createUser error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> verifyCode(
      String email, String enteredCode) async {
    try {
      final result = await _supabase
          .from('restaurant_users')
          .select('*')
          .eq('email', email.trim().toLowerCase())
          .eq('code', enteredCode.trim())
          .maybeSingle();
      return result;
    } catch (e) {
      debugPrint('verifyCode error: $e');
      return null;
    }
  }

  // ── Employee auth ──────────────────────────
  static Future<Map<String, dynamic>?> verifyEmployee({
    required String ownerUserId,
    required String employeeId,
    required String passcode,
  }) async {
    try {
      final result = await _supabase
          .from('employees')
          .select('*')
          .eq('user_id', ownerUserId)
          .eq('employee_id', employeeId.trim())
          .eq('passcode', passcode.trim())
          .maybeSingle();
      return result;
    } catch (e) {
      debugPrint('verifyEmployee error: $e');
      return null;
    }
  }
}

// ─────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────
class AppColors {
  static const primary = Color(0xFF0D9B8A);
  static const primaryLight = Color(0xFFE6F7F5);
  static const accent = Color(0xFFFF6B35);
  static const warning = Color(0xFFFFC107);
  static const success = Color(0xFF4CAF50);
  static const purple = Color(0xFF9C27B0);

  static const bgLight = Color(0xFFF5F6FA);
  static const cardLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF1A1D23);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const borderLight = Color(0xFFE5E7EB);

  static const bgDark = Color(0xFF0F1117);
  static const cardDark = Color(0xFF1A1D27);
  static const textPrimaryDark = Color(0xFFF1F5F9);
  static const textSecondaryDark = Color(0xFF94A3B8);
  static const borderDark = Color(0xFF2D3148);
}

ThemeData buildTheme(bool isDark) {
  final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
  final card = isDark ? AppColors.cardDark : AppColors.cardLight;
  final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  final border = isDark ? AppColors.borderDark : AppColors.borderLight;

  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: bg,
    primaryColor: AppColors.primary,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: Colors.red,
      onError: Colors.white,
      background: bg,
      onBackground: textPrimary,
      surface: card,
      onSurface: textPrimary,
    ),
    cardColor: card,
    dividerColor: border,
    fontFamily: 'Roboto',
    extensions: [
      AppThemeExtension(
        bg: bg, card: card,
        textPrimary: textPrimary, textSecondary: textSecondary, border: border,
      ),
    ],
  );
}

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color bg, card, textPrimary, textSecondary, border;
  const AppThemeExtension({
    required this.bg, required this.card,
    required this.textPrimary, required this.textSecondary, required this.border,
  });

  @override
  AppThemeExtension copyWith({Color? bg, Color? card, Color? textPrimary, Color? textSecondary, Color? border}) =>
      AppThemeExtension(
        bg: bg ?? this.bg, card: card ?? this.card,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        border: border ?? this.border,
      );

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension ThemeX on BuildContext {
  AppThemeExtension get ext => Theme.of(this).extension<AppThemeExtension>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ─────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────
class RestaurantUser {
  final String id, name, email;
  final Uint8List? logoBytes;
  RestaurantUser({required this.id, required this.name, this.logoBytes, required this.email});
}

class EmployeeUser {
  final String id, name, employeeId;
  EmployeeUser({required this.id, required this.name, required this.employeeId});
}

class Employee {
  final String id, name, employeeId, passcode;
  Employee({required this.id, required this.name, required this.employeeId, required this.passcode});
}

class MenuItem {
  final String id, name, category;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final double price;
  MenuItem({required this.id, required this.name, required this.category,
    this.imageBytes, this.imageUrl, required this.price});
}

class OrderItem {
  final MenuItem item;
  int quantity;
  OrderItem({required this.item, required this.quantity});
  double get subtotal => item.price * quantity;
}

class Order {
  final String id;
  String tableNo;
  final int people;
  final List<OrderItem> items;
  String status;
  final DateTime createdAt;
  String orderType;
  double tax;
  String otherChargeName;
  double otherChargeAmount;
  double? manualTotal;

  Order({
    required this.id, required this.tableNo, required this.people,
    required this.items, required this.status, required this.createdAt,
    this.orderType = 'Dine In', this.tax = 0.0,
    this.otherChargeName = '', this.otherChargeAmount = 0.0,
    this.manualTotal,
  });

  double get subtotal => items.fold(0, (s, i) => s + i.subtotal);
  double get total {
    if (items.isNotEmpty) return subtotal + tax + otherChargeAmount;
    return manualTotal ?? 0.0;
  }
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);
}

class TableInfo {
  final String number;
  int seats;
  String status;
  TableInfo({required this.number, required this.seats, required this.status});
}

class Expense {
  final String id, name, description, category;
  final double amount;
  final DateTime date;
  Expense({
    required this.id, required this.name, required this.description,
    required this.category, required this.amount, required this.date,
  });
}

class DishImage extends StatelessWidget {
  final MenuItem item;
  final double height;
  final BorderRadius? borderRadius;
  const DishImage({super.key, required this.item, this.height = 80, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(0);
    if (item.imageBytes != null) {
      return ClipRRect(borderRadius: br, child: Image.memory(item.imageBytes!, width: double.infinity, height: height, fit: BoxFit.cover));
    }
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return ClipRRect(borderRadius: br, child: Image.network(item.imageUrl!, width: double.infinity, height: height, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.fastfood, size: 36, color: AppColors.primary))));
    }
    return const Center(child: Icon(Icons.fastfood, size: 36, color: AppColors.primary));
  }
}
// ─────────────────────────────────────────────
// APP STATE
// ─────────────────────────────────────────────
class AppState extends ChangeNotifier {
  bool isDark = false;
  String restaurantName = 'Tasty Station';
  RestaurantUser? currentUser;
  EmployeeUser? currentEmployee; // non-null when employee is logged in
  int selectedNav = 0;

  List<Order> orders = [];
  List<MenuItem> menu = [];
  List<TableInfo> tables = [];
  List<Expense> expenses = [];
  List<Employee> employees = [];
  Order? activeOrder;
  String selectedPayment = 'card';

  bool get isEmployee => currentEmployee != null;

  // Owner's user_id — works whether owner or employee is logged in
  String? get _ownerId => currentUser?.id;

  Future<void> refreshData() async {
    if (_ownerId == null) return;
    final uid = _ownerId!;

    try {
      final menuRes = await _supabase.from('menu_items').select().eq('user_id', uid);
      menu = (menuRes as List).map((m) => MenuItem(
        id: m['id'].toString(), name: m['name'], category: m['category'],
        price: (m['price'] as num).toDouble(),
        imageUrl: m['image_url'] as String?,
      )).toList();

      final tableRes = await _supabase.from('restaurant_tables').select().eq('user_id', uid);
      tables = (tableRes as List).map((t) => TableInfo(
        number: t['number'], seats: t['seats'], status: t['status']
      )).toList();

      final expRes = await _supabase.from('expenses').select().eq('user_id', uid);
      expenses = (expRes as List).map((e) => Expense(
        id: e['id'].toString(), name: e['name'], category: e['category'],
        amount: (e['amount'] as num).toDouble(), description: e['description'] ?? '',
        date: DateTime.parse(e['date'])
      )).toList();

final orderRes = await _supabase.from('orders').select().eq('user_id', uid).order('created_at', ascending: false);
      orders = await Future.wait((orderRes as List).map((o) async {
        final itemsRes = await _supabase.from('order_items').select().eq('order_id', o['id'].toString());
        final items = (itemsRes as List).map((i) => OrderItem(
          item: MenuItem(id: '', name: i['item_name'], category: '', price: (i['price'] as num).toDouble()),
          quantity: i['quantity'] as int,
        )).toList();
        return Order(
          id: o['id'].toString(),
          tableNo: o['table_no'] ?? 'Walk-in',
          people: 1,
          items: items,
          status: o['status'],
          createdAt: DateTime.parse(o['created_at']),
          orderType: o['order_type'],
          tax: (o['tax'] as num).toDouble(),
          manualTotal: (o['total_amount'] as num).toDouble(),
        );
      }).toList());

      final empRes = await _supabase.from('employees').select().eq('user_id', uid);
      employees = (empRes as List).map((e) => Employee(
        id: e['id'].toString(),
        name: e['name'],
        employeeId: e['employee_id'].toString(),
        passcode: e['passcode'].toString(),
      )).toList();

    } catch (e) {
      debugPrint("Error refreshing data: $e");
    }
    notifyListeners();
  }

  double get grossSales => orders.where((o) => o.status == 'served').fold(0.0, (s, o) => s + o.total);
  double get totalExpenses => expenses.fold(0.0, (s, e) => s + e.amount);
  double get netPay => grossSales - totalExpenses;

  void login(RestaurantUser user) {
    currentUser = user;
    currentEmployee = null;
    restaurantName = user.name;
    selectedNav = 0;
    refreshData();
    notifyListeners();
  }

  // Employee login: we still need the owner's RestaurantUser to load data
  void loginAsEmployee(RestaurantUser owner, EmployeeUser employee) {
    currentUser = owner;
    currentEmployee = employee;
    restaurantName = owner.name;
    selectedNav = 0;
    refreshData();
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    currentEmployee = null;
    orders = []; menu = []; tables = []; expenses = []; employees = [];
    selectedNav = 0;
    notifyListeners();
  }

  // ── DB mutations ─────────────────────────
Future<String?> _uploadDishImage(Uint8List bytes, String filename) async {
    try {
      await _supabase.storage.from('dish-images').uploadBinary(
        filename, bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      return _supabase.storage.from('dish-images').getPublicUrl(filename);
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  Future<void> addMenuItem(MenuItem item) async {
    String? imageUrl;
    if (item.imageBytes != null) {
      final filename = '${_ownerId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      imageUrl = await _uploadDishImage(item.imageBytes!, filename);
    }
    await _supabase.from('menu_items').insert({
      'user_id': _ownerId, 'name': item.name,
      'category': item.category, 'price': item.price,
      if (imageUrl != null) 'image_url': imageUrl,
    });
    await refreshData();
  }

  Future<void> updateMenuItem(String id, String name, String category, double price, {Uint8List? newImageBytes}) async {
    String? imageUrl;
    if (newImageBytes != null) {
      final filename = '${_ownerId}_$id.jpg';
      imageUrl = await _uploadDishImage(newImageBytes, filename);
    }
    await _supabase.from('menu_items').update({
      'name': name, 'category': category, 'price': price,
      if (imageUrl != null) 'image_url': imageUrl,
    }).eq('id', id);
    await refreshData();
  }

  Future<void> deleteMenuItem(String id) async {
    await _supabase.from('menu_items').delete().eq('id', id);
    await refreshData();
  }

  Future<void> addExpense(Expense e) async {
    await _supabase.from('expenses').insert({
      'user_id': _ownerId, 'name': e.name, 'amount': e.amount,
      'category': e.category, 'description': e.description,
      'date': e.date.toIso8601String().split('T')[0],
    });
    await refreshData();
  }

  Future<void> addTable(TableInfo t) async {
    await _supabase.from('restaurant_tables').insert({
      'user_id': _ownerId, 'number': t.number, 'seats': t.seats, 'status': t.status,
    });
    await refreshData();
  }

Future<void> placeOrder() async {
    if (activeOrder == null || activeOrder!.items.isEmpty) return;
    try {
      final orderRes = await _supabase.from('orders').insert({
        'user_id': _ownerId,
        'table_no': activeOrder!.tableNo,
        'order_type': activeOrder!.orderType,
        'status': 'kitchen',
        'total_amount': activeOrder!.total,
        'tax': activeOrder!.tax,
      }).select().single();

      final orderId = orderRes['id'].toString();

      // Save each item
      for (final oi in activeOrder!.items) {
        await _supabase.from('order_items').insert({
          'order_id': orderId,
          'item_name': oi.item.name,
          'quantity': oi.quantity,
          'price': oi.item.price,
        });
      }

      activeOrder = null;
      await refreshData();
    } catch (e) {
      debugPrint("Error placing order: $e");
    }
  }

  Future<void> updateOrderStatus(Order order, String newStatus) async {
    await _supabase.from('orders').update({'status': newStatus}).eq('id', order.id);
    await refreshData();
  }

  Future<void> updateRestaurantInfo(String name) async {
    await _supabase.from('restaurant_users').update({'restaurant_name': name}).eq('id', _ownerId!);
    restaurantName = name;
    notifyListeners();
  }

  // ── Employee CRUD ────────────────────────
  Future<void> addEmployee(String name, String employeeId, String passcode) async {
    await _supabase.from('employees').insert({
      'user_id': _ownerId,
      'name': name,
      'employee_id': employeeId,
      'passcode': passcode,
    });
    await refreshData();
  }

  Future<void> editEmployee(String id, String name, String employeeId, String passcode) async {
    await _supabase.from('employees').update({
      'name': name,
      'employee_id': employeeId,
      'passcode': passcode,
    }).eq('id', id);
    await refreshData();
  }

  Future<void> deleteEmployee(String id) async {
    await _supabase.from('employees').delete().eq('id', id);
    await refreshData();
  }

  // ── UI helpers ───────────────────────────
  void toggleTheme() { isDark = !isDark; notifyListeners(); }
  void setNav(int i) { selectedNav = i; notifyListeners(); }
  void setPayment(String p) { selectedPayment = p; notifyListeners(); }
  void setActiveOrder(Order? o) { activeOrder = o; notifyListeners(); }
  void _ensureActiveOrder() {
    if (activeOrder == null) {
      activeOrder = Order(id: 'draft', tableNo: 'Walk-in', people: 1, items: [], status: 'draft', createdAt: DateTime.now());
    }
  }
  void addItemToOrder(MenuItem item) {
    _ensureActiveOrder();
    final idx = activeOrder!.items.indexWhere((i) => i.item.id == item.id);
    if (idx >= 0) { activeOrder!.items[idx].quantity++; }
    else { activeOrder!.items.add(OrderItem(item: item, quantity: 1)); }
    notifyListeners();
  }
  void removeItemFromOrder(MenuItem item) {
    if (activeOrder == null) return;
    final idx = activeOrder!.items.indexWhere((i) => i.item.id == item.id);
    if (idx >= 0) {
      if (activeOrder!.items[idx].quantity > 1) { activeOrder!.items[idx].quantity--; }
      else { activeOrder!.items.removeAt(idx); }
    }
    notifyListeners();
  }
  int getItemQty(String menuId) {
    if (activeOrder == null) return 0;
    final idx = activeOrder!.items.indexWhere((i) => i.item.id == menuId);
    return idx >= 0 ? activeOrder!.items[idx].quantity : 0;
  }
  void updateActiveOrderType(String type) { _ensureActiveOrder(); activeOrder!.orderType = type; notifyListeners(); }
  void updateActiveOrderTable(String tableNo) { _ensureActiveOrder(); activeOrder!.tableNo = tableNo; notifyListeners(); }
  void updateActiveOrderTax(double newTax) { _ensureActiveOrder(); activeOrder!.tax = newTax; notifyListeners(); }
  void updateActiveOrderOtherCharge(String name, double amount) {
    _ensureActiveOrder(); activeOrder!.otherChargeName = name; activeOrder!.otherChargeAmount = amount; notifyListeners();
  }
  List<String> get categories => ['All Menu', ...menu.map((m) => m.category).toSet().toList()];
  List<Order> get dineIn => orders.where((o) => o.status != 'draft' && o.status != 'served' && o.status != 'wait_list' && o.orderType == 'Dine In').toList();
  List<Order> get waitList => orders.where((o) => o.status == 'wait_list').toList();
  List<Order> get takeAway => orders.where((o) => o.status != 'draft' && o.status != 'served' && o.status != 'wait_list' && o.orderType == 'Take Out').toList();
  List<Order> get served => orders.where((o) => o.status == 'served').toList();
}

late AppState _appState;

// ─────────────────────────────────────────────
// ROOT APP
// ─────────────────────────────────────────────
class TastyStationApp extends StatefulWidget {
  const TastyStationApp({super.key});
  @override
  State<TastyStationApp> createState() => _TastyStationAppState();
}

class _TastyStationAppState extends State<TastyStationApp> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    _appState = _state;
    _state.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tasty Station POS',
      theme: buildTheme(_state.isDark),
      home: _state.currentUser == null
          ? LoginPage(state: _state)
          : MainShell(state: _state),
    );
  }
}

// ─────────────────────────────────────────────
// LOGIN PAGE  — with Owner / Employee split
// ─────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  final AppState state;
  const LoginPage({super.key, required this.state});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // stages: 'email' | 'role' | 'owner_code' | 'employee_id' | 'employee_pass'
  String _stage = 'email';
  final _emailCtrl      = TextEditingController();
  final _codeCtrl       = TextEditingController();
  final _empIdCtrl      = TextEditingController();
  final _empPassCtrl    = TextEditingController();
  bool   _loading        = false;
  String? _error;
  bool   _isExistingUser = false;
  String _enteredEmail   = '';

  // Owner row from DB (needed to resolve user_id for employee lookup)
  Map<String, dynamic>? _ownerRow;

  AppThemeExtension get _ext {
    final isDark = widget.state.isDark;
    return isDark
        ? const AppThemeExtension(
            bg: AppColors.bgDark, card: AppColors.cardDark,
            textPrimary: AppColors.textPrimaryDark,
            textSecondary: AppColors.textSecondaryDark,
            border: AppColors.borderDark)
        : const AppThemeExtension(
            bg: AppColors.bgLight, card: AppColors.cardLight,
            textPrimary: AppColors.textPrimaryLight,
            textSecondary: AppColors.textSecondaryLight,
            border: AppColors.borderLight);
  }

  // ── Stage 1: check email ─────────────────
  Future<void> _handleContinue() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final check = await AuthService.checkEmail(email);
    if (check['exists'] == true) {
      // Fetch full owner row so we have user_id for employee lookup later
      final row = await _supabase
          .from('restaurant_users')
          .select('*')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();
      _ownerRow = row;
      setState(() { _isExistingUser = true; _enteredEmail = email; _stage = 'role'; _loading = false; });
    } else {
      final code = await AuthService.createUserAndSendCode(email);
      if (code == null) {
        setState(() { _error = 'Something went wrong. Please try again.'; _loading = false; });
        return;
      }
      setState(() { _isExistingUser = false; _enteredEmail = email; _stage = 'owner_code'; _loading = false; });
    }
  }

  // ── Stage 2: role chosen ─────────────────
  void _chooseOwner() => setState(() { _stage = 'owner_code'; _error = null; });
  void _chooseEmployee() => setState(() { _stage = 'employee_id'; _error = null; });

  // ── Stage 3a: owner verifies code ────────
  Future<void> _handleVerifyOwner() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 8) {
      setState(() => _error = 'Please enter the 8-digit code.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final user = await AuthService.verifyCode(_enteredEmail, code);
    if (user == null) {
      setState(() { _error = 'Incorrect code. Please try again.'; _loading = false; });
      return;
    }
    final restaurantName = (user['restaurant_name'] as String?) ?? 'My Restaurant';
    widget.state.login(RestaurantUser(
      id: user['id'] as String,
      name: restaurantName,
      email: _enteredEmail,
    ));
  }

  // ── Stage 3b: employee enters ID then passcode ──
  Future<void> _handleVerifyEmployee() async {
    final empId   = _empIdCtrl.text.trim();
    final pass    = _empPassCtrl.text.trim();
    if (empId.isEmpty) { setState(() => _error = 'Please enter your Employee ID.'); return; }
    if (pass.isEmpty)  { setState(() => _error = 'Please enter your passcode.'); return; }

    setState(() { _loading = true; _error = null; });

    final ownerId = _ownerRow?['id'] as String?;
    if (ownerId == null) {
      setState(() { _error = 'Could not find restaurant. Please try again.'; _loading = false; });
      return;
    }

    final emp = await AuthService.verifyEmployee(
      ownerUserId: ownerId,
      employeeId: empId,
      passcode: pass,
    );

    if (emp == null) {
      setState(() { _error = 'Invalid Employee ID or passcode.'; _loading = false; });
      return;
    }

    final restaurantName = (_ownerRow?['restaurant_name'] as String?) ?? 'My Restaurant';
    final owner = RestaurantUser(id: ownerId, name: restaurantName, email: _enteredEmail);
    final employee = EmployeeUser(
      id: emp['id'] as String,
      name: emp['name'] as String,
      employeeId: emp['employee_id'].toString(),
    );
    widget.state.loginAsEmployee(owner, employee);
  }

  void _goBack() {
    setState(() {
      if (_stage == 'role') { _stage = 'email'; }
      else if (_stage == 'owner_code') { _stage = _isExistingUser ? 'role' : 'email'; }
      else if (_stage == 'employee_id') { _stage = 'role'; }
      _error = null;
      _codeCtrl.clear();
      _empIdCtrl.clear();
      _empPassCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = _ext;
    return Scaffold(
      backgroundColor: ext.bg,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: ext.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _buildStage(ext),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(AppThemeExtension ext) {
    switch (_stage) {
      case 'email':        return _emailStage(ext);
      case 'role':         return _roleStage(ext);
      case 'owner_code':   return _ownerCodeStage(ext);
      case 'employee_id':  return _employeeStage(ext);
      default:             return _emailStage(ext);
    }
  }

  // ── Email stage ──────────────────────────
  Widget _emailStage(AppThemeExtension ext) {
    return Column(
      key: const ValueKey('email'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _logo(ext),
        const SizedBox(height: 8),
        Text('Sign in to your POS', style: TextStyle(fontSize: 14, color: ext.textSecondary)),
        const SizedBox(height: 32),
        Align(alignment: Alignment.centerLeft, child: Text('Email address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ext.textSecondary))),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          onSubmitted: (_) => _handleContinue(),
          style: TextStyle(color: ext.textPrimary, fontSize: 14),
          decoration: _inputDeco('you@example.com', ext),
        ),
        if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))],
        const SizedBox(height: 24),
        _primaryBtn(_loading ? 'Checking...' : 'Continue', _loading ? null : _handleContinue),
        const SizedBox(height: 16),
        _themeToggle(ext),
      ],
    );
  }

  // ── Role selection stage ─────────────────
  Widget _roleStage(AppThemeExtension ext) {
    return Column(
      key: const ValueKey('role'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _logo(ext),
        const SizedBox(height: 12),
        Text('Who is logging in?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ext.textPrimary)),
        const SizedBox(height: 6),
        Text(_enteredEmail, style: TextStyle(fontSize: 13, color: ext.textSecondary)),
        const SizedBox(height: 32),
        // Owner button
        GestureDetector(
          onTap: _chooseOwner,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.store, color: Colors.white, size: 22)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Owner', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ext.textPrimary)),
                Text('Full access to all features', style: TextStyle(fontSize: 12, color: ext.textSecondary)),
              ])),
              Icon(Icons.arrow_forward_ios, size: 14, color: ext.textSecondary),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        // Employee button
        GestureDetector(
          onTap: _chooseEmployee,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.badge, color: Colors.white, size: 22)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Employee', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ext.textPrimary)),
                Text('Order Line & Tables only', style: TextStyle(fontSize: 12, color: ext.textSecondary)),
              ])),
              Icon(Icons.arrow_forward_ios, size: 14, color: ext.textSecondary),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back, size: 14, color: AppColors.primary),
          label: const Text('Back', style: TextStyle(color: AppColors.primary, fontSize: 13)),
        ),
        _themeToggle(ext),
      ],
    );
  }

  // ── Owner code stage ─────────────────────
  Widget _ownerCodeStage(AppThemeExtension ext) {
    return Column(
      key: const ValueKey('owner_code'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _logo(ext),
        const SizedBox(height: 8),
        Text(
          _isExistingUser ? 'Enter your code' : 'Check your inbox',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ext.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          _isExistingUser
              ? 'Enter the permanent 8-digit code for\n$_enteredEmail'
              : 'We sent an 8-digit code to\n$_enteredEmail\n\nThis code is your permanent password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: ext.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          maxLength: 8,
          autofocus: true,
          textAlign: TextAlign.center,
          onSubmitted: (_) => _handleVerifyOwner(),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ext.textPrimary, letterSpacing: 8),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            hintText: '--------',
            hintStyle: TextStyle(fontSize: 24, color: ext.border, letterSpacing: 8),
            filled: true, fillColor: ext.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ext.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ext.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))],
        const SizedBox(height: 24),
        _primaryBtn(_loading ? 'Verifying...' : 'Sign In as Owner', _loading ? null : _handleVerifyOwner),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back, size: 14, color: AppColors.primary),
          label: const Text('Back', style: TextStyle(color: AppColors.primary, fontSize: 13)),
        ),
        _themeToggle(ext),
      ],
    );
  }

  // ── Employee login stage ─────────────────
  Widget _employeeStage(AppThemeExtension ext) {
    return Column(
      key: const ValueKey('employee_id'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _logo(ext),
        const SizedBox(height: 8),
        Text('Employee Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ext.textPrimary)),
        const SizedBox(height: 6),
        Text('Enter your Employee ID and passcode', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ext.textSecondary)),
        const SizedBox(height: 24),
        Align(alignment: Alignment.centerLeft, child: Text('Employee ID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ext.textSecondary))),
        const SizedBox(height: 6),
        TextField(
          controller: _empIdCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: ext.textPrimary, fontSize: 14),
          decoration: _inputDeco('e.g. 1001', ext),
        ),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: Text('Passcode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ext.textSecondary))),
        const SizedBox(height: 6),
        TextField(
          controller: _empPassCtrl,
          obscureText: true,
          onSubmitted: (_) => _handleVerifyEmployee(),
          style: TextStyle(color: ext.textPrimary, fontSize: 14),
          decoration: _inputDeco('Enter passcode', ext),
        ),
        if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))],
        const SizedBox(height: 24),
        _primaryBtn(_loading ? 'Verifying...' : 'Sign In as Employee', _loading ? null : _handleVerifyEmployee),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back, size: 14, color: AppColors.primary),
          label: const Text('Back', style: TextStyle(color: AppColors.primary, fontSize: 13)),
        ),
        _themeToggle(ext),
      ],
    );
  }

  Widget _logo(AppThemeExtension ext) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
      child: const Center(child: Icon(Icons.restaurant, color: AppColors.primary)),
    ),
    const SizedBox(width: 12),
    Text(widget.state.restaurantName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ext.textPrimary)),
  ]);

  InputDecoration _inputDeco(String hint, AppThemeExtension ext) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: ext.textSecondary.withOpacity(0.5), fontSize: 14),
    filled: true, fillColor: ext.bg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ext.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ext.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _primaryBtn(String label, VoidCallback? onTap) => SizedBox(
    width: double.infinity, height: 48,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
    ),
  );

  Widget _themeToggle(AppThemeExtension ext) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Theme: ', style: TextStyle(fontSize: 12, color: ext.textSecondary)),
      GestureDetector(
        onTap: widget.state.toggleTheme,
        child: Icon(widget.state.isDark ? Icons.dark_mode : Icons.light_mode, size: 18, color: AppColors.primary),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────
// MAIN SHELL  — role-aware navigation
// ─────────────────────────────────────────────
class MainShell extends StatelessWidget {
  final AppState state;
  const MainShell({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return isWide ? _DesktopLayout(state: state) : _MobileLayout(state: state);
  }
}

// ── Nav items helper ─────────────────────────
// Returns nav items based on role.
// Each entry: (outlinedIcon, filledIcon, label, pageIndex)
// pageIndex matches the switch in _pageContent.
List<(IconData, IconData, String, int)> _navItems(bool isEmployee) {
  if (isEmployee) {
    return [
      (Icons.receipt_long_outlined,      Icons.receipt_long,      'Order Line', 1),
      (Icons.table_restaurant_outlined,  Icons.table_restaurant,  'Tables',     2),
    ];
  }
  return [
    (Icons.dashboard_outlined,           Icons.dashboard,          'Dashboard',    0),
    (Icons.receipt_long_outlined,        Icons.receipt_long,       'Order Line',   1),
    (Icons.table_restaurant_outlined,    Icons.table_restaurant,   'Tables',       2),
    (Icons.restaurant_menu_outlined,     Icons.restaurant_menu,    'Dishes',       3),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Expenses', 4),
    (Icons.people_outline,               Icons.people,             'Employees',    5),
    (Icons.settings_outlined,            Icons.settings,           'Settings',     6),
  ];
}

Widget _pageContent(AppState state) {
  switch (state.selectedNav) {
    case 0: return DashboardPage(state: state);
    case 1: return OrderLinePage(state: state);
    case 2: return ManageTablePage(state: state);
    case 3: return ManageDishesPage(state: state);
    case 4: return ExpensesPage(state: state);
    case 5: return ManageEmployeesPage(state: state);
    case 6: return SettingsPage(state: state);
    default: return DashboardPage(state: state);
  }
}

class _DesktopLayout extends StatelessWidget {
  final AppState state;
  const _DesktopLayout({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ext.bg,
      body: Row(children: [
        SideNavBar(state: state),
        Expanded(child: _pageContent(state)),
      ]),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final AppState state;
  const _MobileLayout({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ext.bg,
      appBar: AppBar(
        backgroundColor: context.ext.card,
        elevation: 0,
        title: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)), child: const Center(child: Icon(Icons.restaurant, size: 18, color: AppColors.primary))),
          const SizedBox(width: 8),
          Text(state.restaurantName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.ext.textPrimary)),
          if (state.isEmployee) ...[
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: const Text('Employee', style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600))),
          ],
        ]),
        actions: [
          IconButton(icon: Icon(state.isDark ? Icons.light_mode : Icons.dark_mode, color: AppColors.primary), onPressed: state.toggleTheme),
        ],
      ),
      body: _pageContent(state),
      bottomNavigationBar: _MobileNav(state: state),
    );
  }
}

class _MobileNav extends StatelessWidget {
  final AppState state;
  const _MobileNav({required this.state});

  @override
  Widget build(BuildContext context) {
    final items = _navItems(state.isEmployee);
    return Container(
      decoration: BoxDecoration(color: context.ext.card, border: Border(top: BorderSide(color: context.ext.border))),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: items.map((e) {
              final sel = state.selectedNav == e.$4;
              return Expanded(child: GestureDetector(
                onTap: () => state.setNav(e.$4),
                behavior: HitTestBehavior.opaque,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(sel ? e.$2 : e.$1, size: 22, color: sel ? AppColors.primary : context.ext.textSecondary),
                  Text(e.$3, style: TextStyle(fontSize: 9, color: sel ? AppColors.primary : context.ext.textSecondary)),
                ]),
              ));
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SIDE NAV BAR
// ─────────────────────────────────────────────
class SideNavBar extends StatelessWidget {
  final AppState state;
  const SideNavBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final ext = context.ext;
    final items = _navItems(state.isEmployee);
    return Container(
      width: 220,
      decoration: BoxDecoration(color: ext.card, border: Border(right: BorderSide(color: ext.border))),
      child: Column(children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)), child: const Center(child: Icon(Icons.restaurant, color: AppColors.primary))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(state.restaurantName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ext.textPrimary), overflow: TextOverflow.ellipsis),
              Text(state.isEmployee ? 'Employee: ${state.currentEmployee!.name}' : 'POS System', style: TextStyle(fontSize: 11, color: ext.textSecondary), overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),
        if (state.isEmployee)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.badge, size: 13, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('ID: ${state.currentEmployee!.employeeId}', style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final sel = state.selectedNav == item.$4;
              return GestureDetector(
                onTap: () => state.setNav(item.$4),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primaryLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(sel ? item.$2 : item.$1, size: 20, color: sel ? AppColors.primary : ext.textSecondary),
                    const SizedBox(width: 10),
                    Text(item.$3, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.normal, color: sel ? AppColors.primary : ext.textSecondary)),
                  ]),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (!state.isEmployee) _sideBtn(context, Icons.help_outline, 'Help Center', () {}),
            if (!state.isEmployee) const SizedBox(height: 4),
            _sideBtn(context, Icons.logout, 'Logout', () => state.logout(), color: Colors.red),
          ]),
        ),
      ]),
    );
  }

  Widget _sideBtn(BuildContext context, IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final c = color ?? context.ext.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: c)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MANAGE EMPLOYEES PAGE  (owner only)
// ─────────────────────────────────────────────
class ManageEmployeesPage extends StatefulWidget {
  final AppState state;
  const ManageEmployeesPage({super.key, required this.state});
  @override
  State<ManageEmployeesPage> createState() => _ManageEmployeesPageState();
}

class _ManageEmployeesPageState extends State<ManageEmployeesPage> {
  void _showAddEditDialog({Employee? existing}) {
    final nameCtrl   = TextEditingController(text: existing?.name ?? '');
    final idCtrl     = TextEditingController(text: existing?.employeeId ?? '');
    final passCtrl   = TextEditingController(text: existing?.passcode ?? '');
    final isEdit     = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.ext.card,
        title: Text(isEdit ? 'Edit Employee' : 'Add Employee',
            style: TextStyle(color: ctx.ext.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field('Full Name', nameCtrl, ctx),
            const SizedBox(height: 12),
            _field('Employee ID (e.g. 1001)', idCtrl, ctx, type: TextInputType.number),
            const SizedBox(height: 12),
            _field('Passcode', passCtrl, ctx, obscure: true),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name   = nameCtrl.text.trim();
              final empId  = idCtrl.text.trim();
              final pass   = passCtrl.text.trim();
              if (name.isEmpty || empId.isEmpty || pass.isEmpty) return;
              Navigator.pop(ctx);
              if (isEdit) {
                await widget.state.editEmployee(existing!.id, name, empId, pass);
              } else {
                await widget.state.addEmployee(name, empId, pass);
              }
            },
            child: Text(isEdit ? 'Save' : 'Add', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Employee emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.ext.card,
        title: Text('Delete Employee', style: TextStyle(color: ctx.ext.textPrimary)),
        content: Text('Remove ${emp.name} (ID: ${emp.employeeId})? This cannot be undone.',
            style: TextStyle(color: ctx.ext.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.state.deleteEmployee(emp.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, BuildContext ctx,
      {TextInputType? type, bool obscure = false}) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: obscure,
        style: TextStyle(color: ctx.ext.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ctx.ext.textSecondary, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ext  = context.ext;
    final emps = widget.state.employees;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Manage Employees', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ext.textPrimary)),
            Text('${emps.length} employee${emps.length == 1 ? '' : 's'} registered', style: TextStyle(fontSize: 12, color: ext.textSecondary)),
          ]),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.person_add, size: 16, color: Colors.white),
            label: const Text('Add Employee', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 20),
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            SizedBox(width: 60, child: Text('ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ext.textSecondary))),
            Expanded(child: Text('Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ext.textSecondary))),
            SizedBox(width: 90, child: Text('Passcode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ext.textSecondary))),
            const SizedBox(width: 80),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: emps.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.people_outline, size: 52, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text('No employees yet.\nTap "Add Employee" to get started.', textAlign: TextAlign.center, style: TextStyle(color: ext.textSecondary, fontSize: 13, height: 1.5)),
                ]))
              : ListView.builder(
                  itemCount: emps.length,
                  itemBuilder: (ctx, i) {
                    final emp = emps[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: ext.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ext.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
                      ),
                      child: Row(children: [
                        // ID badge
                        Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(emp.employeeId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary), textAlign: TextAlign.center),
                        ),
                        const SizedBox(width: 12),
                        // Name
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(emp.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ext.textPrimary)),
                          Text('Employee', style: TextStyle(fontSize: 11, color: ext.textSecondary)),
                        ])),
                        // Passcode (masked)
                        SizedBox(
                          width: 90,
                          child: Text('•' * emp.passcode.length.clamp(4, 8),
                              style: TextStyle(fontSize: 16, letterSpacing: 3, color: ext.textSecondary)),
                        ),
                        // Actions
                        Row(children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                            tooltip: 'Edit',
                            onPressed: () => _showAddEditDialog(existing: emp),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () => _confirmDelete(emp),
                          ),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// DASHBOARD PAGE
// ─────────────────────────────────────────────
class DashboardPage extends StatelessWidget {
  final AppState state;
  const DashboardPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final ext = context.ext;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ext.textPrimary)),
            Text('Welcome back, ${state.currentUser?.name ?? 'Admin'}', style: TextStyle(fontSize: 13, color: ext.textSecondary)),
          ]),
          IconButton(icon: Icon(state.isDark ? Icons.light_mode : Icons.dark_mode, color: AppColors.primary), onPressed: state.toggleTheme),
        ]),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 600 ? 3 : 1;
          return GridView.count(
            crossAxisCount: cols, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16, mainAxisSpacing: 16,
            childAspectRatio: cols == 1 ? 2.5 : 1.6,
            children: [
              _StatCard(title: 'Gross Sales', value: '₱${state.grossSales.toStringAsFixed(2)}', subtitle: 'Total before expenses', icon: Icons.trending_up, color: AppColors.primary, ext: ext),
              _StatCard(title: 'Total Expenses', value: '₱${state.totalExpenses.toStringAsFixed(2)}', subtitle: 'All recorded expenses', icon: Icons.receipt, color: AppColors.accent, ext: ext),
              _StatCard(title: 'Net Pay', value: '₱${state.netPay.toStringAsFixed(2)}', subtitle: 'Gross minus expenses', icon: Icons.account_balance_wallet, color: AppColors.success, ext: ext),
            ],
          );
        }),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          final isW = c.maxWidth > 600;
          if (isW) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _OrderSummary(state: state, ext: ext)),
              const SizedBox(width: 16),
              Expanded(child: _RecentExpenses(state: state, ext: ext)),
            ]);
          }
          return Column(children: [
            _OrderSummary(state: state, ext: ext),
            const SizedBox(height: 16),
            _RecentExpenses(state: state, ext: ext),
          ]);
        }),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final Color color;
  final AppThemeExtension ext;
  const _StatCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color, required this.ext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ext.card, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: TextStyle(fontSize: 13, color: ext.textSecondary, fontWeight: FontWeight.w500)),
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color)),
        ]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 11, color: ext.textSecondary)),
      ]),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final AppState state;
  final AppThemeExtension ext;
  const _OrderSummary({required this.state, required this.ext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ext.card, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Order Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ext.textPrimary)),
        const SizedBox(height: 16),
        _row('Dine In', state.dineIn.length.toString(), AppColors.primary),
        _row('Wait List', state.waitList.length.toString(), AppColors.warning),
        _row('Served', state.served.length.toString(), AppColors.success),
        _row('Total Valid Orders', state.orders.where((o) => o.status != 'draft').length.toString(), AppColors.accent),
      ]),
    );
  }

  Widget _row(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: ext.textSecondary)),
      ]),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ext.textPrimary)),
    ]),
  );
}

class _RecentExpenses extends StatelessWidget {
  final AppState state;
  final AppThemeExtension ext;
  const _RecentExpenses({required this.state, required this.ext});

  @override
  Widget build(BuildContext context) {
    final recent = state.expenses.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ext.card, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Expenses', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ext.textPrimary)),
        const SizedBox(height: 16),
        if (recent.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text('No expenses yet', style: TextStyle(color: ext.textSecondary, fontSize: 13))))
        else
          ...recent.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ext.textPrimary)),
                Text(e.category, style: TextStyle(fontSize: 11, color: ext.textSecondary)),
              ])),
              Text('₱${e.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
            ]),
          )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// ORDER LINE PAGE
// ─────────────────────────────────────────────
class OrderLinePage extends StatefulWidget {
  final AppState state;
  const OrderLinePage({super.key, required this.state});
  @override
  State<OrderLinePage> createState() => _OrderLinePageState();
}

class _OrderLinePageState extends State<OrderLinePage> {
  String _tab = 'New Order';
  String _menuCat = 'All Menu';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final ext = context.ext;
    final isWide = MediaQuery.of(context).size.width >= 700;
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        color: ext.bg,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Order Line', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ext.textPrimary)),
          if (!isWide) IconButton(icon: Icon(widget.state.isDark ? Icons.light_mode : Icons.dark_mode, color: AppColors.primary), onPressed: widget.state.toggleTheme),
        ]),
      ),
      _OrderTabs(state: widget.state, selectedTab: _tab, onTabChanged: (t) => setState(() => _tab = t)),
      Expanded(
        child: _tab == 'New Order'
            ? (isWide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _menuSection(ext)),
                    _OrderSidePanel(state: widget.state),
                  ])
                : SingleChildScrollView(child: Column(children: [
                    _menuSection(ext),
                    _OrderSidePanel(state: widget.state, mobile: true),
                  ])))
            : _OrderListSection(tab: _tab, state: widget.state, ext: ext),
      ),
    ]);
  }

  Widget _menuSection(AppThemeExtension ext) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 40,
            decoration: BoxDecoration(color: ext.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: ext.border)),
            child: Row(children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.search, size: 18, color: Colors.grey)),
              Expanded(child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(fontSize: 13, color: ext.textPrimary),
                decoration: const InputDecoration(hintText: 'Search menu, orders and more', border: InputBorder.none, isDense: true),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          Text('Foodies Menu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ext.textPrimary)),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              ...widget.state.categories.map((cat) {
                final sel = _menuCat == cat;
                return GestureDetector(
                  onTap: () => setState(() => _menuCat = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary.withOpacity(0.1) : ext.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? AppColors.primary : ext.border),
                    ),
                    child: Center(child: Text(cat, style: TextStyle(fontSize: 12, color: sel ? AppColors.primary : ext.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal))),
                  ),
                );
              }),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: Builder(builder: (context) {
          final filtered = widget.state.menu.where((m) {
            final catMatch = _menuCat == 'All Menu' || m.category == _menuCat;
            final searchMatch = _search.isEmpty || m.name.toLowerCase().contains(_search.toLowerCase());
            return catMatch && searchMatch;
          }).toList();
          if (filtered.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.restaurant_menu_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text('No menu items yet. Add some in Manage Dishes.', style: TextStyle(color: ext.textSecondary, fontSize: 13)),
            ]));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisExtent: 170, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _MenuCard(item: filtered[i], state: widget.state, ext: ext),
          );
        }),
      ),
    ]);
  }
}

class _OrderTabs extends StatelessWidget {
  final AppState state;
  final String selectedTab;
  final ValueChanged<String> onTabChanged;
  const _OrderTabs({required this.state, required this.selectedTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    final ext = context.ext;
    final tabs = [
      ('New Order', state.activeOrder?.items.length ?? 0, const Color(0xFF6366F1)),
      ('Dine In', state.dineIn.length, AppColors.primary),
      ('Wait List', state.waitList.length, AppColors.warning),
      ('Take Out', state.takeAway.length, AppColors.accent),
      ('Served', state.served.length, AppColors.success),
    ];
    return Container(
      color: ext.bg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: tabs.map((t) {
          final sel = selectedTab == t.$1;
          return GestureDetector(
            onTap: () => onTabChanged(t.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? t.$3.withOpacity(0.12) : ext.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? t.$3 : ext.border),
              ),
              child: Row(children: [
                Text(t.$1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: sel ? t.$3 : ext.textSecondary)),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: t.$3.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text('${t.$2}', style: TextStyle(fontSize: 10, color: t.$3, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          );
        }).toList()),
      ),
    );
  }
}

class _OrderListSection extends StatelessWidget {
  final String tab;
  final AppState state;
  final AppThemeExtension ext;
  const _OrderListSection({required this.tab, required this.state, required this.ext});

  @override
  Widget build(BuildContext context) {
    List<Order> filtered;
    if (tab == 'Dine In') filtered = state.dineIn;
    else if (tab == 'Take Out') filtered = state.takeAway;
    else if (tab == 'Wait List') filtered = state.waitList;
    else if (tab == 'Served') filtered = state.served;
    else filtered = [];

    if (filtered.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 48, color: ext.textSecondary.withOpacity(0.5)),
        const SizedBox(height: 8),
        Text('No orders in $tab', style: TextStyle(color: ext.textSecondary, fontSize: 13)),
      ]));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 320, mainAxisExtent: 260, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final order = filtered[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: ext.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: ext.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Order #${order.id.substring(order.id.length - 4)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ext.textPrimary)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(order.orderType, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 6),
            if (order.orderType == 'Dine In') Text('Table: ${order.tableNo} • ${order.people} People', style: TextStyle(fontSize: 12, color: ext.textSecondary)),
            const SizedBox(height: 10),
Divider(color: ext.border),
            Expanded(
              child: order.items.isEmpty
                  ? Center(child: Text('No item details stored', style: TextStyle(fontSize: 11, color: ext.textSecondary.withOpacity(0.6))))
                  : Scrollbar(
                      child: ListView(
                        children: order.items.map((oi) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Text('${oi.quantity}x', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(oi.item.name, style: TextStyle(fontSize: 12, color: ext.textPrimary), overflow: TextOverflow.ellipsis)),
                          ]),
                        )).toList(),
                      ),
                    ),
            ),
            Divider(color: ext.border),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total', style: TextStyle(fontSize: 13, color: ext.textSecondary)),
              Text('₱${order.total.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ext.textPrimary)),
            ]),
            const SizedBox(height: 12),
            if (order.status != 'served') Row(children: [
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => state.updateOrderStatus(order, 'served'), child: const Text('Served', style: TextStyle(fontSize: 12, color: Colors.white)))),
              const SizedBox(width: 8),
              if (order.status == 'kitchen')
                Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning, side: const BorderSide(color: AppColors.warning), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => state.updateOrderStatus(order, 'wait_list'), child: const Text('Wait List', style: TextStyle(fontSize: 12))))
              else if (order.status == 'wait_list')
                Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => state.updateOrderStatus(order, 'kitchen'), child: const Text('To Kitchen', style: TextStyle(fontSize: 12)))),
            ]) else Center(child: Text('Completed', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600))),
          ]),
        );
      },
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItem item;
  final AppState state;
  final AppThemeExtension ext;
  const _MenuCard({required this.item, required this.state, required this.ext});

  @override
  Widget build(BuildContext context) {
    final qty = state.getItemQty(item.id);
    return Container(
      decoration: BoxDecoration(color: ext.card, borderRadius: BorderRadius.circular(14), border: qty > 0 ? Border.all(color: AppColors.primary, width: 1.5) : Border.all(color: ext.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 80,
          decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.5), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: DishImage(
            item: item, height: 80,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.category, style: TextStyle(fontSize: 9, color: ext.textSecondary)),
            Text(item.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ext.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('₱${item.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              Row(children: [
                _QtyBtn(icon: Icons.remove, onTap: () => state.removeItemFromOrder(item), enabled: qty > 0),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('$qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ext.textPrimary))),
                _QtyBtn(icon: Icons.add, onTap: () => state.addItemToOrder(item), enabled: true),
              ]),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  const _QtyBtn({required this.icon, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 22, height: 22,
        decoration: BoxDecoration(color: enabled ? AppColors.primary : Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 14, color: enabled ? Colors.white : Colors.grey),
      ),
    );
  }
}

class _OrderSidePanel extends StatelessWidget {
  final AppState state;
  final bool mobile;
  const _OrderSidePanel({required this.state, this.mobile = false});

  void _showTaxEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: (state.activeOrder?.tax ?? 0.0).toString());
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Tax Amount'),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tax Amount (₱)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { state.updateActiveOrderTax(double.tryParse(ctrl.text) ?? 0.0); Navigator.pop(ctx); }, child: const Text('Save')),
      ],
    ));
  }

  void _showOtherChargeDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: state.activeOrder?.otherChargeName ?? '');
    final amtCtrl  = TextEditingController(text: (state.activeOrder?.otherChargeAmount ?? 0.0).toString());
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Other Charge'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Charge Name (e.g. Delivery)')),
        const SizedBox(height: 10),
        TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₱)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { state.updateActiveOrderOtherCharge(nameCtrl.text, double.tryParse(amtCtrl.text) ?? 0.0); Navigator.pop(ctx); }, child: const Text('Save')),
      ],
    ));
  }

  void _showPaymentDialog(BuildContext context, Order order, AppState state) {
    final amtCtrl = TextEditingController();
    final ext = context.ext;
    double? change;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        backgroundColor: ctx.ext.card,
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Collect Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ctx.ext.textPrimary)),
        ]),
        content: SizedBox(
          width: 300,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Order total display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Order Total', style: TextStyle(fontSize: 13, color: ctx.ext.textSecondary)),
                Text('₱${order.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),
            ),
            const SizedBox(height: 16),
            // Amount input
            TextField(
              controller: amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ctx.ext.textPrimary),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Amount Received (₱)',
                labelStyle: TextStyle(fontSize: 13, color: ctx.ext.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                prefixText: '₱ ',
                prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ctx.ext.textSecondary),
              ),
              onChanged: (v) {
                final entered = double.tryParse(v);
                setSt(() {
                  if (entered == null) {
                    change = null;
                    errorMsg = null;
                  } else if (entered < order.total) {
                    change = null;
                    errorMsg = 'Amount is less than the total (₱${order.total.toStringAsFixed(2)})';
                  } else {
                    change = entered - order.total;
                    errorMsg = null;
                  }
                });
              },
            ),
            // Error message
            if (errorMsg != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(errorMsg!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                ]),
              ),
            ],
            // Change display
            if (change != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.success.withOpacity(0.3))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Change', style: TextStyle(fontSize: 13, color: ctx.ext.textSecondary)),
                  Text('₱${change!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.success)),
                ]),
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ctx.ext.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: change != null ? AppColors.primary : Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: change != null ? () async {
              Navigator.pop(ctx);
              final capturedChange = change!;
              final capturedAmount = double.parse(amtCtrl.text);
              await state.placeOrder();
              if (context.mounted) _showReceiptDialog(context, order, state, amountPaid: capturedAmount, change: capturedChange);
            } : null,
            child: const Text('Confirm & Place Order', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      )),
    );
  }

  void _showReceiptDialog(BuildContext context, Order order, AppState state, {double amountPaid = 0, double change = 0}) {    final now = DateTime.now();
    final ext = context.ext;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.ext.card,
        contentPadding: const EdgeInsets.all(0),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                // Header
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 26),
                ),
                const SizedBox(height: 10),
                Text(state.restaurantName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ext.textPrimary)),
                const SizedBox(height: 2),
                Text('Order Receipt', style: TextStyle(fontSize: 12, color: ext.textSecondary)),
                const SizedBox(height: 16),
                Divider(color: ext.border),
                // Order info
                _receiptRow('Order Type', order.orderType, ext),
                if (order.orderType == 'Dine In') _receiptRow('Table', order.tableNo, ext),
                _receiptRow('Date', '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}', ext),
                _receiptRow('Time', '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}', ext),
                _receiptRow('Payment', 'Cash', ext),
                Divider(color: ext.border),
                // Items
                Align(alignment: Alignment.centerLeft, child: Text('Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ext.textSecondary))),
                const SizedBox(height: 8),
                ...order.items.map((oi) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Center(child: Text('${oi.quantity}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(oi.item.name, style: TextStyle(fontSize: 13, color: ext.textPrimary))),
                    Text('₱${oi.subtotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ext.textPrimary)),
                  ]),
                )),
                const SizedBox(height: 8),
                Divider(color: ext.border),
                // Totals
                _receiptRow('Subtotal', '₱${order.subtotal.toStringAsFixed(2)}', ext),
                if (order.tax > 0) _receiptRow('Tax', '₱${order.tax.toStringAsFixed(2)}', ext),
                if (order.otherChargeAmount > 0) _receiptRow(
                  order.otherChargeName.isEmpty ? 'Other' : order.otherChargeName,
                  '₱${order.otherChargeAmount.toStringAsFixed(2)}', ext),
                const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('TOTAL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ext.textPrimary)),
                    Text('₱${order.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ]),
                const SizedBox(height: 6),
                Divider(color: ext.border),
                _receiptRow('Amount Paid', '₱${amountPaid.toStringAsFixed(2)}', ext),
                _receiptRow('Change', '₱${change.toStringAsFixed(2)}', ext),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 16),
                    SizedBox(width: 6),
                    Text('Order sent to kitchen!', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, AppThemeExtension ext) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: ext.textSecondary)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ext.textPrimary)),
    ]),
  );

  void _showEditTableDialog(BuildContext context) {
    final ctrl = TextEditingController(text: state.activeOrder?.tableNo ?? 'Walk-in');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Enter Table Number'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Table No')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { state.updateActiveOrderTable(ctrl.text.trim()); Navigator.pop(ctx); }, child: const Text('Save')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ext   = context.ext;
    final order = state.activeOrder;
    final subtotal    = order?.subtotal ?? 0;
    final tax         = order?.tax ?? 0.0;
    final otherCharge = order?.otherChargeAmount ?? 0.0;
    final otherChargeName = order?.otherChargeName ?? '';
    final total       = subtotal + tax + otherCharge;

    Widget panel = Container(
      width: mobile ? double.infinity : 300,
      constraints: mobile ? null : const BoxConstraints(minHeight: double.infinity),
      decoration: BoxDecoration(color: ext.card, border: Border(left: BorderSide(color: ext.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (order != null) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: GestureDetector(
                onTap: () => _showEditTableDialog(context),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Table No #${order.tableNo}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ext.textPrimary, decoration: TextDecoration.underline)),
                  Text('Order #${order.id.substring(order.id.length - 4)}', style: TextStyle(fontSize: 12, color: ext.textSecondary)),
                ]),
              )),
              Text('${order.people} People', style: TextStyle(fontSize: 12, color: ext.textSecondary)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: _OrderTypeBtn('Dine In', order.orderType == 'Dine In', () => state.updateActiveOrderType('Dine In'))),
              const SizedBox(width: 8),
              Expanded(child: _OrderTypeBtn('Take Out', order.orderType == 'Take Out', () => state.updateActiveOrderType('Take Out'))),
            ]),
          ),
          const SizedBox(height: 10),
          Divider(color: ext.border, height: 1),
        ] else ...[
          Padding(padding: const EdgeInsets.all(16), child: Text('No active order', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ext.textSecondary))),
          Divider(color: ext.border, height: 1),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Ordered Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ext.textPrimary)),
            Text('${order?.items.length ?? 0}', style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ]),
        ),
        if (order != null && order.items.isNotEmpty)
          ...order.items.map((oi) => _OrderItemRow(oi: oi, ext: ext, state: state))
        else
          Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No items in order', style: TextStyle(color: ext.textSecondary, fontSize: 13)))),
        Divider(color: ext.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            _sumRow('Subtotal', '₱${subtotal.toStringAsFixed(2)}', ext),
            GestureDetector(onTap: () => _showTaxEditDialog(context), child: _sumRow('Tax (Tap to edit)', '₱${tax.toStringAsFixed(2)}', ext, isInteractive: true)),
            GestureDetector(onTap: () => _showOtherChargeDialog(context), child: _sumRow(otherChargeName.isEmpty ? 'Other Charge (Tap to add)' : otherChargeName, '₱${otherCharge.toStringAsFixed(2)}', ext, isInteractive: true)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total Payable', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ext.textPrimary)),
              Text('₱${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ]),
          ]),
        ),
        Divider(color: ext.border),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ext.textPrimary)),
            const SizedBox(height: 10),
            Row(children: [
              _PayBtn('Cash', Icons.money, state.selectedPayment == 'cash', () => state.setPayment('cash')),
              // Card and Scan payments not yet implemented
              // const SizedBox(width: 8),
              // _PayBtn('Card', Icons.credit_card, state.selectedPayment == 'card', () => state.setPayment('card')),
              // const SizedBox(width: 8),
              // _PayBtn('Scan', Icons.qr_code_scanner, state.selectedPayment == 'scan', () => state.setPayment('scan')),
            ]),
          ]),
        ),
Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            // Print button — not yet implemented (save to device coming soon)
            // Expanded(child: OutlinedButton.icon(
            //   onPressed: () {},
            //   icon: const Icon(Icons.print, size: 16),
            //   label: const Text('Print', style: TextStyle(fontSize: 13)),
            //   style: OutlinedButton.styleFrom(foregroundColor: ext.textPrimary, side: BorderSide(color: ext.border), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            // )),
            // const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
            onPressed: order != null && order.items.isNotEmpty ? () async {
                final receiptOrder = order;
                if (context.mounted) _showPaymentDialog(context, receiptOrder, state);
              } : null,
              icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
              label: const Text('Place Order', style: TextStyle(fontSize: 13, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )),
          ]),
        ),
      ]),
    );

    if (mobile) return panel;
    return SizedBox(width: 300, child: panel);
  }

  Widget _sumRow(String label, String value, AppThemeExtension ext, {bool isInteractive = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: isInteractive ? AppColors.primary : ext.textSecondary, decoration: isInteractive ? TextDecoration.underline : null)),
      Text(value, style: TextStyle(fontSize: 12, color: ext.textPrimary, fontWeight: isInteractive ? FontWeight.w600 : FontWeight.normal)),
    ]),
  );
}

class _OrderTypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OrderTypeBtn(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: selected ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: selected ? AppColors.primary : context.ext.border)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : context.ext.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItem oi;
  final AppThemeExtension ext;
  final AppState state;
  const _OrderItemRow({required this.oi, required this.ext, required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(children: [
        Text('${oi.quantity}x', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(child: Text(oi.item.name, style: TextStyle(fontSize: 12, color: ext.textPrimary), overflow: TextOverflow.ellipsis)),
        Text('₱${oi.subtotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ext.textPrimary)),
      ]),
    );
  }
}

class _PayBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PayBtn(this.label, this.icon, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: selected ? AppColors.primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: selected ? AppColors.primary : context.ext.border)),
        child: Column(children: [
          Icon(icon, size: 16, color: selected ? AppColors.primary : context.ext.textSecondary),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: selected ? AppColors.primary : context.ext.textSecondary)),
        ]),
      ),
    ));
  }
}

// ─────────────────────────────────────────────
// MANAGE TABLE PAGE
// ─────────────────────────────────────────────
class ManageTablePage extends StatefulWidget {
  final AppState state;
  const ManageTablePage({super.key, required this.state});
  @override
  State<ManageTablePage> createState() => _ManageTablePageState();
}

class _ManageTablePageState extends State<ManageTablePage> {
  void _showAddTable() {
    final seatsCtrl = TextEditingController(text: '4');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: ctx.ext.card,
      title: Text('Add Table', style: TextStyle(color: ctx.ext.textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Seats', style: TextStyle(color: ctx.ext.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: seatsCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            final seats = int.tryParse(seatsCtrl.text) ?? 4;
            widget.state.addTable(TableInfo(
              number: (widget.state.tables.length + 1).toString().padLeft(2, '0'),
              seats: seats,
              status: 'available'
            ));
            Navigator.pop(ctx);
          },
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.ext;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Manage Tables', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ext.textPrimary)),
          // Only owner can add tables
          if (!widget.state.isEmployee)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _showAddTable,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Add Table', style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _legend('Available', AppColors.success),
          const SizedBox(width: 16),
          _legend('Occupied', AppColors.accent),
          const SizedBox(width: 16),
          _legend('Reserved', AppColors.warning),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: widget.state.tables.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.table_restaurant_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text('No tables yet. Tap "Add Table" to get started.', style: TextStyle(color: ext.textSecondary, fontSize: 13)),
                ]))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, mainAxisExtent: 140, crossAxisSpacing: 14, mainAxisSpacing: 14),
                  itemCount: widget.state.tables.length,
                  itemBuilder: (ctx, i) {
                    final t = widget.state.tables[i];
                    final color = t.status == 'available' ? AppColors.success : t.status == 'occupied' ? AppColors.accent : AppColors.warning;
                    return GestureDetector(
                      onTap: () {
                        final statuses = ['available', 'occupied', 'reserved'];
                        final next = statuses[(statuses.indexOf(t.status) + 1) % 3];
                        setState(() => t.status = next);
                      },
                      child: Container(
                        decoration: BoxDecoration(color: ext.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.4), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.table_restaurant, size: 36, color: color),
                          const SizedBox(height: 8),
                          Text('Table ${t.number}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ext.textPrimary)),
                          Text('${t.seats} seats', style: TextStyle(fontSize: 11, color: ext.textSecondary)),
                          const SizedBox(height: 6),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Text(t.status[0].toUpperCase() + t.status.substring(1), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _legend(String label, Color color) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 12, color: context.ext.textSecondary)),
  ]);
}

// ─────────────────────────────────────────────
// MANAGE DISHES PAGE
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// MANAGE DISHES PAGE
// ─────────────────────────────────────────────
class ManageDishesPage extends StatefulWidget {
  final AppState state;
  const ManageDishesPage({super.key, required this.state});
  @override
  State<ManageDishesPage> createState() => _ManageDishesPageState();
}

class _ManageDishesPageState extends State<ManageDishesPage> {
  String _cat = 'All Menu';

  void _showAddDish() {
    final nameCtrl  = TextEditingController();
    final priceCtrl = TextEditingController();
    final catCtrl   = TextEditingController();
    Uint8List? selectedImage;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      backgroundColor: ctx.ext.card,
      title: Text('Add Dish', style: TextStyle(color: ctx.ext.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(width: 320, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _dlgField('Name', nameCtrl, ctx),
        const SizedBox(height: 12),
        _dlgField('Price (₱)', priceCtrl, ctx, type: TextInputType.number),
        const SizedBox(height: 12),
        _dlgField('Category', catCtrl, ctx),
        const SizedBox(height: 12),
        _imagePickerBox(ctx, selectedImage, (bytes) => setSt(() => selectedImage = bytes)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () async {
            final name = nameCtrl.text.trim();
            final price = double.tryParse(priceCtrl.text) ?? 0;
            final category = catCtrl.text.trim().isEmpty ? 'Uncategorized' : catCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            await widget.state.addMenuItem(MenuItem(
              id: '', name: name, category: category,
              price: price, imageBytes: selectedImage,
            ));
            setState(() {});
          },
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    )));
  }

  void _showEditDish(MenuItem m) {
    final nameCtrl  = TextEditingController(text: m.name);
    final priceCtrl = TextEditingController(text: m.price.toString());
    final catCtrl   = TextEditingController(text: m.category);
    Uint8List? selectedImage = m.imageBytes;
    String? currentImageUrl = m.imageUrl;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      backgroundColor: ctx.ext.card,
      title: Text('Edit Dish', style: TextStyle(color: ctx.ext.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(width: 320, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _dlgField('Name', nameCtrl, ctx),
        const SizedBox(height: 12),
        _dlgField('Price (₱)', priceCtrl, ctx, type: TextInputType.number),
        const SizedBox(height: 12),
        _dlgField('Category', catCtrl, ctx),
        const SizedBox(height: 12),
        _imagePickerBoxWithUrl(ctx, selectedImage, currentImageUrl, (bytes) => setSt(() {
          selectedImage = bytes;
          currentImageUrl = null; // new image picked, clear url
        })),
      ]))),
actions: [
  Row(
    children: [
      TextButton(
        onPressed: () {
          Navigator.pop(ctx);
          _confirmDelete(m);
        },
        child: const Text('Delete', style: TextStyle(color: Colors.red)),
      ),
      const Spacer(),
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      const SizedBox(width: 8),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: () async {
          final name = nameCtrl.text.trim();
          final price = double.tryParse(priceCtrl.text) ?? m.price;
          final category = catCtrl.text.trim().isEmpty ? m.category : catCtrl.text.trim();
          if (name.isEmpty) return;
          Navigator.pop(ctx);
          await widget.state.updateMenuItem(m.id, name, category, price, newImageBytes: selectedImage != m.imageBytes ? selectedImage : null);
                    if (mounted) setState(() {});
        },
        child: const Text('Save', style: TextStyle(color: Colors.white)),
      ),
    ],
  ),
],
    )));
  }

  void _confirmDelete(MenuItem m) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: ctx.ext.card,
      title: Text('Delete Dish', style: TextStyle(color: ctx.ext.textPrimary)),
      content: Text('Remove "${m.name}"? This cannot be undone.', style: TextStyle(color: ctx.ext.textSecondary, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(ctx);
            await widget.state.deleteMenuItem(m.id);
                        if (mounted) setState(() {});
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Widget _imagePickerBox(BuildContext ctx, Uint8List? image, ValueChanged<Uint8List> onPicked) {
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (file != null) {
          final bytes = await file.readAsBytes();
          onPicked(bytes);
        }
      },
      child: Container(
        height: 110, width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
          color: AppColors.primaryLight.withOpacity(0.3),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(image, fit: BoxFit.cover))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28),
                const SizedBox(height: 6),
                Text('Tap to select image', style: TextStyle(fontSize: 12, color: AppColors.primary.withOpacity(0.8))),
              ]),
      ),
    );
  }

  Widget _imagePickerBoxWithUrl(BuildContext ctx, Uint8List? image, String? imageUrl, ValueChanged<Uint8List> onPicked) {
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (file != null) {
          final bytes = await file.readAsBytes();
          onPicked(bytes);
        }
      },
      child: Container(
        height: 110, width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
          color: AppColors.primaryLight.withOpacity(0.3),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(image, fit: BoxFit.cover))
            : (imageUrl != null && imageUrl.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder()))
                : _imagePlaceholder(),
      ),
    );
  }

  Widget _imagePlaceholder() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28),
    const SizedBox(height: 6),
    Text('Tap to change image', style: TextStyle(fontSize: 12, color: AppColors.primary.withOpacity(0.8))),
  ]);

  Widget _dlgField(String label, TextEditingController ctrl, BuildContext ctx, {TextInputType? type}) =>
      TextField(
        controller: ctrl, keyboardType: type,
        style: TextStyle(color: ctx.ext.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ctx.ext.textSecondary, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ext      = context.ext;
    final cats     = widget.state.categories;
    final filtered = widget.state.menu.where((m) => _cat == 'All Menu' || m.category == _cat).toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Manage Dishes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ext.textPrimary)),
            Text('${filtered.length} dish${filtered.length == 1 ? '' : 'es'}', style: TextStyle(fontSize: 12, color: ext.textSecondary)),
          ]),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _showAddDish,
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text('Add Dish', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(scrollDirection: Axis.horizontal, children: cats.map((c) {
            final sel = _cat == c;
            return GestureDetector(
              onTap: () => setState(() => _cat = c),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : ext.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: sel ? AppColors.primary : ext.border),
                ),
                child: Center(child: Text(c, style: TextStyle(fontSize: 12, color: sel ? Colors.white : ext.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal))),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.restaurant_menu_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text('No dishes yet. Tap "Add Dish" to get started.', style: TextStyle(color: ext.textSecondary, fontSize: 13)),
                ]))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200, mainAxisExtent: 200,
                    crossAxisSpacing: 14, mainAxisSpacing: 14,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final m = filtered[i];
                    return GestureDetector(
                      onTap: () => _showEditDish(m),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ext.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ext.border),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // Image area
                          Stack(children: [
                            Container(
                              height: 110,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withOpacity(0.5),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              ),
                              child: DishImage(
                                item: m,
                                height: 110,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              ),
                            ),
                            // Edit badge
                            Positioned(top: 8, right: 8, child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.edit, size: 13, color: Colors.white),
                            )),
                          ]),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m.category, style: TextStyle(fontSize: 9, color: ext.textSecondary)),
                              Text(m.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ext.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text('₱${m.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                Icon(Icons.touch_app_outlined, size: 14, color: ext.textSecondary.withOpacity(0.5)),
                              ]),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// EXPENSES PAGE
// ─────────────────────────────────────────────
class ExpensesPage extends StatefulWidget {
  final AppState state;
  const ExpensesPage({super.key, required this.state});
  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  static const _tabs = ['Utilities', 'Ingredients', 'Personal', 'Employee'];

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: _tabs.length, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  void _showAddExpense(String defaultCat) {
    final nameCtrl = TextEditingController();
    final amtCtrl  = TextEditingController();
    final descCtrl = TextEditingController();
    String cat = defaultCat;
    DateTime date = DateTime.now();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      backgroundColor: ctx.ext.card,
      title: Text('Add Expense', style: TextStyle(color: ctx.ext.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(width: 340, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _dlgField('Name', nameCtrl, ctx),
        const SizedBox(height: 12),
        _dlgField('Amount (₱)', amtCtrl, ctx, type: TextInputType.number),
        const SizedBox(height: 12),
        _dlgField('Description', descCtrl, ctx),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: cat, decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), items: _tabs.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setSt(() => cat = v!)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async { final picked = await showDatePicker(ctx: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2030)); if (picked != null) setSt(() => date = picked); },
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(border: Border.all(color: ctx.ext.border), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: AppColors.primary), const SizedBox(width: 8), Text('${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}', style: TextStyle(fontSize: 13, color: ctx.ext.textPrimary))])),
        ),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            final name = nameCtrl.text.trim();
            final amt  = double.tryParse(amtCtrl.text) ?? 0;
            if (name.isEmpty || amt <= 0) return;
            widget.state.addExpense(Expense(id: '', name: name, amount: amt, description: descCtrl.text.trim(), category: cat, date: date));
            setState(() {});
            Navigator.pop(ctx);
          },
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    )));
  }

  Widget _dlgField(String label, TextEditingController ctrl, BuildContext ctx, {TextInputType? type}) =>
      TextField(controller: ctrl, keyboardType: type, decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))));

  @override
  Widget build(BuildContext context) {
    final ext = context.ext;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Expenses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ext.textPrimary)),
          ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _showAddExpense(_tabs[_tabCtrl.index]), icon: const Icon(Icons.add, size: 16, color: Colors.white), label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontSize: 13))),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
          child: Row(children: [const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 20), const SizedBox(width: 10), Text('Total Expenses: ', style: TextStyle(color: ext.textSecondary, fontSize: 13)), Text('₱${widget.state.totalExpenses.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16))]),
        ),
        const SizedBox(height: 16),
        TabBar(controller: _tabCtrl, isScrollable: true, labelColor: AppColors.primary, unselectedLabelColor: ext.textSecondary, indicatorColor: AppColors.primary, tabs: const [Tab(text: 'Utilities'), Tab(text: 'Ingredients'), Tab(text: 'Personal'), Tab(text: 'Employee')]),
        Expanded(
          child: TabBarView(controller: _tabCtrl, children: _tabs.map((cat) {
            final list = widget.state.expenses.where((e) => e.category == cat).toList();
            if (list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey), const SizedBox(height: 8), Text('No $cat expenses yet', style: TextStyle(color: ext.textSecondary))]));
            return ListView.builder(
              padding: const EdgeInsets.only(top: 12),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final e = list[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: ext.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: ext.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
                  child: Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Center(child: Icon(_expenseIcon(cat), size: 20, color: AppColors.primary))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ext.textPrimary)),
                      if (e.description.isNotEmpty) Text(e.description, style: TextStyle(fontSize: 11, color: ext.textSecondary)),
                      Text('${e.date.year}-${e.date.month.toString().padLeft(2,'0')}-${e.date.day.toString().padLeft(2,'0')}', style: TextStyle(fontSize: 11, color: ext.textSecondary)),
                    ])),
                    Text('₱${e.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent)),
                  ]),
                );
              },
            );
          }).toList()),
        ),
      ]),
    );
  }

  IconData _expenseIcon(String cat) {
    switch (cat) {
      case 'Utilities': return Icons.bolt;
      case 'Ingredients': return Icons.shopping_basket;
      case 'Personal': return Icons.person;
      case 'Employee': return Icons.badge;
      default: return Icons.receipt;
    }
  }
}

// ─────────────────────────────────────────────
// SETTINGS PAGE
// ─────────────────────────────────────────────
class SettingsPage extends StatefulWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _nameCtrl;

  @override
  void initState() { super.initState(); _nameCtrl = TextEditingController(text: widget.state.restaurantName); }

  @override
  Widget build(BuildContext context) {
    final ext = context.ext;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ext.textPrimary)),
        const SizedBox(height: 24),
        _Section(title: 'Restaurant Identity', ext: ext, child: Column(children: [
          _SettingRow(label: 'Restaurant Name', ext: ext, child: SizedBox(width: 220, child: TextField(controller: _nameCtrl, style: TextStyle(fontSize: 13, color: ext.textPrimary), decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ext.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ext.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10))))),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { widget.state.updateRestaurantInfo(_nameCtrl.text.trim()); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restaurant info updated!'), backgroundColor: AppColors.primary)); },
            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ])),
        const SizedBox(height: 20),
        _Section(title: 'Appearance', ext: ext, child: _SettingRow(label: 'Theme Mode', ext: ext, child: Row(children: [
          Text(widget.state.isDark ? 'Dark Mode' : 'Light Mode', style: TextStyle(fontSize: 13, color: ext.textSecondary)),
          const SizedBox(width: 12),
          Switch(value: widget.state.isDark, onChanged: (_) => widget.state.toggleTheme(), activeColor: AppColors.primary),
          Icon(widget.state.isDark ? Icons.dark_mode : Icons.light_mode, color: AppColors.primary, size: 20),
        ]))),
        const SizedBox(height: 20),
        _Section(title: 'Account', ext: ext, child: Column(children: [
          _SettingRow(label: 'Logged in as', ext: ext, child: Text(widget.state.currentUser?.email ?? '', style: TextStyle(fontSize: 13, color: ext.textSecondary))),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => widget.state.logout(),
            icon: const Icon(Icons.logout, size: 16, color: Colors.red),
            label: const Text('Logout', style: TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ])),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final AppThemeExtension ext;
  const _Section({required this.title, required this.child, required this.ext});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ext.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: ext.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ext.textPrimary)),
        Divider(color: ext.border, height: 20),
        child,
      ]),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;
  final AppThemeExtension ext;
  const _SettingRow({required this.label, required this.child, required this.ext});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: ext.textSecondary, fontWeight: FontWeight.w500)),
      child,
    ]);
  }
}

// ─────────────────────────────────────────────
// SIMPLE DATE PICKER
// ─────────────────────────────────────────────
Future<DateTime?> showDatePicker({
  required BuildContext ctx,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTime>(context: ctx, builder: (_) => _SimpleDatePicker(initial: initialDate, first: firstDate, last: lastDate));
}

class _SimpleDatePicker extends StatefulWidget {
  final DateTime initial, first, last;
  const _SimpleDatePicker({required this.initial, required this.first, required this.last});
  @override
  State<_SimpleDatePicker> createState() => _SimpleDatePickerState();
}

class _SimpleDatePickerState extends State<_SimpleDatePicker> {
  late int _year, _month, _day;

  @override
  void initState() { super.initState(); _year = widget.initial.year; _month = widget.initial.month; _day = widget.initial.day; }

  @override
  Widget build(BuildContext context) {
    final ext = context.ext;
    return AlertDialog(
      backgroundColor: ext.card,
      title: Text('Select Date', style: TextStyle(color: ext.textPrimary, fontSize: 15)),
      content: Row(mainAxisSize: MainAxisSize.min, children: [
        _Spinner('Year', _year, widget.first.year, widget.last.year, (v) => setState(() => _year = v)),
        const SizedBox(width: 12),
        _Spinner('Month', _month, 1, 12, (v) => setState(() => _month = v)),
        const SizedBox(width: 12),
        _Spinner('Day', _day, 1, 31, (v) => setState(() => _day = v)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), onPressed: () => Navigator.pop(context, DateTime(_year, _month, _day)), child: const Text('OK', style: TextStyle(color: Colors.white))),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _Spinner(this.label, this.value, this.min, this.max, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 11, color: context.ext.textSecondary)),
      const SizedBox(height: 4),
      IconButton(icon: const Icon(Icons.keyboard_arrow_up, size: 18), onPressed: value < max ? () => onChanged(value + 1) : null),
      Text('$value', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.ext.textPrimary)),
      IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 18), onPressed: value > min ? () => onChanged(value - 1) : null),
    ]);
  }
}