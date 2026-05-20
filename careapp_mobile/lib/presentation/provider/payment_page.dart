import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../core/api_config.dart';
import 'provider_dashboard.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  int _selectedTab = 0;

  Map<String, dynamic> _earnings = {
    'total': 0,
    'monthly': 0,
    'weekly': 0,
    'today': 0,
    'pending': 0,
  };

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _halfPayments = []; // ✅ قائمة مدفوعات نصف المبلغ
  List<Map<String, dynamic>> _withdrawalHistory = [];
  bool _isLoading = true;

  final String baseUrl = ApiConfig.baseUrl;

  // حقول السحب كما هي...
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  String _cardType = '';

  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ribController = TextEditingController();

  String _selectedMethod = "Edahabia";

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
    _fetchPaymentHistory();
    _fetchHalfPayments(); // ✅ جلب مدفوعات نصف المبلغ
    _fetchWithdrawalHistory();
  }

  Future<void> _fetchEarnings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/earnings'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _earnings = {
            'total': data['total'] ?? 0,
            'monthly': data['monthly'] ?? 0,
            'weekly': data['weekly'] ?? 0,
            'today': data['today'] ?? 0,
            'pending': data['pending'] ?? 0,
          };
        });
      }
    } catch (error) {
      print('Error fetching earnings: $error');
    }
  }

  Future<void> _fetchPaymentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/payments'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _transactions = data.map((item) => {
            'id': item['id'],
            'client': item['client'],
            'service': item['service'],
            'amount': item['amount'],
            'date': item['date'],
            'status': item['status'],
            'paymentMethod': item['paymentMethod'],
          }).toList();
        });
      }
    } catch (error) {
      print('Error fetching payment history: $error');
    }
  }

  // ✅ جلب مدفوعات نصف المبلغ
  Future<void> _fetchHalfPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/half-payments'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _halfPayments = data.map((item) => {
            'id': item['id'],
            'clientId': item['clientId'],
            'clientName': item['clientName'] ?? item['client'],
            'clientPhone': item['clientPhone'],
            'bookingId': item['bookingId'],
            'service': item['service'],
            'amount': item['amount'],
            'date': item['date'],
            'paymentMethod': item['paymentMethod'],
            'status': item['status'],
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      print('Error fetching half payments: $error');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchWithdrawalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/provider/withdrawals'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _withdrawalHistory = data.map((item) => {
            'id': item['id'],
            'amount': item['amount'],
            'date': item['requestedAt']?.split('T')[0] ?? '',
            'status': item['status'],
            'method': item['method'],
          }).toList();
        });
      }
    } catch (error) {
      print('Error fetching withdrawal history: $error');
    }
  }

  // باقي دوال السحب (لم تتغير)...
  Future<void> _requestWithdrawal(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    if (!_validateMethodDetails()) return;

    String accountDetails = _getAccountDetails();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/provider/withdraw'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'method': _selectedMethod,
          'accountDetails': accountDetails,
        }),
      );
      if (response.statusCode == 201) {
        await _fetchWithdrawalHistory();
        _clearMethodFields();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Withdrawal request submitted!"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to submit withdrawal"), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection error"), backgroundColor: Colors.red),
      );
    }
  }

  String _getAccountDetails() {
    switch (_selectedMethod) {
      case 'Edahabia':
        return 'Card: ${_maskCardNumber(_cardNumberController.text)} | Exp: ${_expiryController.text}';
      case 'Bank Transfer':
        return 'Bank: ${_bankNameController.text} | Account: ${_accountNameController.text} | Number: ${_accountNumberController.text} | RIB: ${_ribController.text}';
      default:
        return '';
    }
  }

  bool _validateMethodDetails() {
    switch (_selectedMethod) {
      case 'Edahabia':
        String cardNumber = _cardNumberController.text.replaceAll(' ', '');
        String expiry = _expiryController.text;
        String cvc = _cvcController.text;
        if (cardNumber.length < 13 || cardNumber.length > 19) {
          _showError("Invalid card number");
          return false;
        }
        if (expiry.length != 5 || !expiry.contains('/')) {
          _showError("Invalid expiry date (MM/YY)");
          return false;
        }
        if (cvc.length < 3) {
          _showError("Invalid CVC");
          return false;
        }
        return true;

      case 'Bank Transfer':
        if (_bankNameController.text.trim().isEmpty) {
          _showError("Bank name is required");
          return false;
        }
        if (_accountNameController.text.trim().isEmpty) {
          _showError("Account holder name is required");
          return false;
        }
        if (_accountNumberController.text.trim().isEmpty) {
          _showError("Account number is required");
          return false;
        }
        if (_ribController.text.trim().isEmpty) {
          _showError("RIB is required");
          return false;
        }
        return true;

      default:
        return false;
    }
  }

  void _clearMethodFields() {
    _cardNumberController.clear();
    _expiryController.clear();
    _cvcController.clear();
    _bankNameController.clear();
    _accountNameController.clear();
    _accountNumberController.clear();
    _ribController.clear();
  }

  String _maskCardNumber(String number) {
    if (number.length < 4) return '****';
    return '**** ${number.substring(number.length - 4)}';
  }

  void _detectCardType(String number) {
    String cleaned = number.replaceAll(' ', '');
    if (cleaned.startsWith('4')) {
      _cardType = 'Visa';
    } else if (cleaned.startsWith('5')) {
      _cardType = 'Mastercard';
    } else if (cleaned.startsWith('3')) {
      _cardType = 'Amex';
    } else {
      _cardType = 'Card';
    }
    setState(() {});
  }

  void _formatExpiry(String text) {
    String cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length >= 3) {
      _expiryController.value = TextEditingValue(
        text: '${cleaned.substring(0, 2)}/${cleaned.substring(2, cleaned.length > 4 ? 4 : cleaned.length)}',
        selection: TextSelection.collapsed(offset: cleaned.length > 2 ? cleaned.length + 1 : cleaned.length),
      );
    } else {
      _expiryController.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }
  }

  void _formatCardNumber(String text) {
    String cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted = '';
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) formatted += ' ';
      formatted += cleaned[i];
    }
    _cardNumberController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _detectCardType(cleaned);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProviderDashboard(providerName: "Amina")),
            );
          },
        ),
        title: Text("Payments", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _tabButton("Earnings", 0, isDark),
                const SizedBox(width: 20),
                _tabButton("History", 1, isDark),
                const SizedBox(width: 20),
                _tabButton("Half Payments", 2, isDark), // ✅ علامة تبويب جديدة
                const SizedBox(width: 20),
                _tabButton("Withdraw", 3, isDark),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedTab == 0
              ? _buildEarningsTab(isDark)
              : _selectedTab == 1
                  ? _buildHistoryTab(isDark)
                  : _selectedTab == 2
                      ? _buildHalfPaymentsTab(isDark)
                      : _buildWithdrawTab(isDark),
    );
  }

  Widget _tabButton(String title, int index, bool isDark) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: isSelected ? Colors.white : Colors.transparent, width: 2),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTotalCard(isDark),
          const SizedBox(height: 20),
          _buildEarningsGrid(isDark),
          const SizedBox(height: 20),
          _buildPendingCard(isDark),
        ],
      ),
    );
  }

  Widget _buildTotalCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF0284C7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          const Text("Total Earnings", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text("${_earnings['total']} DZD", style: GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.trending_up, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text("+12% from last month", style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsGrid(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _earningCard(isDark, "Monthly", "${_earnings['monthly']} DZD", Icons.calendar_month, Colors.blue),
        _earningCard(isDark, "Weekly", "${_earnings['weekly']} DZD", Icons.calendar_view_week, Colors.green),
        _earningCard(isDark, "Today", "${_earnings['today']} DZD", Icons.today, Colors.orange),
        _earningCard(isDark, "Pending", "${_earnings['pending']} DZD", Icons.pending, Colors.red),
      ],
    );
  }

  Widget _earningCard(bool isDark, String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPendingCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.pending, color: Colors.orange, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Pending Clearance", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  Text("${_earnings['pending']} DZD", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
            ],
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    return _transactions.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text("No transactions yet", style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _transactions.length,
            itemBuilder: (context, index) => _transactionTile(_transactions[index], isDark),
          );
  }

  Widget _transactionTile(Map<String, dynamic> tx, bool isDark) {
    final isCompleted = tx['status'] == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Icon(isCompleted ? Icons.check_circle : Icons.pending, color: isCompleted ? Colors.green : Colors.orange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['client'], style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                Text(tx['service'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                Text("${tx['date']} • ${tx['paymentMethod']}", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${tx['amount']} DZD", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(tx['status'].toUpperCase(), style: TextStyle(color: isCompleted ? Colors.green : Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ علامة تبويب مدفوعات نصف المبلغ
  Widget _buildHalfPaymentsTab(bool isDark) {
    if (_halfPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("No half payments received yet", style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _halfPayments.length,
      itemBuilder: (context, index) => _halfPaymentTile(_halfPayments[index], isDark),
    );
  }

  Widget _halfPaymentTile(Map<String, dynamic> payment, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.currency_franc, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment['clientName'],
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                    ),
                    Text(
                      payment['service'],
                      style: TextStyle(color: AppTheme.primary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(payment['status'] == 'half_paid' ? 'Half Paid' : 'Completed'),
                backgroundColor: Colors.green.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.green, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip(Icons.attach_money, "${payment['amount']} DZD", isDark),
              const SizedBox(width: 8),
              _infoChip(Icons.calendar_today, payment['date'], isDark),
              const SizedBox(width: 8),
              _infoChip(Icons.credit_card, payment['paymentMethod'], isDark),
            ],
          ),
          const SizedBox(height: 8),
          _infoChip(Icons.receipt, "Booking ID: ${payment['bookingId']}", isDark),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              // يمكن الانتقال إلى تفاصيل الحجز
              Navigator.pushNamed(
                context,
                '/provider/booking-details',
                arguments: {'bookingId': payment['bookingId']},
              );
            },
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text("View Booking"),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // باقي دوال السحب (كما هي)
  Widget _buildWithdrawTab(bool isDark) {
    TextEditingController amountController = TextEditingController();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildWithdrawCard(isDark, amountController),
          const SizedBox(height: 20),
          if (_withdrawalHistory.isNotEmpty) _buildWithdrawalHistory(isDark),
        ],
      ),
    );
  }

  Widget _buildWithdrawCard(bool isDark, TextEditingController amountController) {
    int available = _earnings['total'] - _earnings['pending'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Request Withdrawal", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 20),
          Text("Payment Method", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              _methodChip("Edahabia", _selectedMethod == "Edahabia", isDark, () => setState(() => _selectedMethod = "Edahabia")),
              const SizedBox(width: 12),
              _methodChip("Bank Transfer", _selectedMethod == "Bank Transfer", isDark, () => setState(() => _selectedMethod = "Bank Transfer")),
            ],
          ),
          const SizedBox(height: 20),
          _buildMethodFields(isDark),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Available Balance", style: TextStyle(color: Colors.grey)),
                Text("$available DZD", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Amount to Withdraw",
              prefixText: "DZD ",
              prefixStyle: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                int amount = int.tryParse(amountController.text) ?? 0;
                if (amount > 0 && amount <= available) {
                  _requestWithdrawal(amount);
                } else {
                  _showError("Invalid amount or insufficient balance");
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text("Request Withdrawal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodFields(bool isDark) {
    switch (_selectedMethod) {
      case 'Edahabia':
        return _buildEdahabiaFields(isDark);
      case 'Bank Transfer':
        return _buildBankTransferFields(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEdahabiaFields(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text("Edahabia Card Details", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const Spacer(),
              if (_cardType.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(_cardType, style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cardNumberController,
            onChanged: _formatCardNumber,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "1234 5678 9012 3456",
              prefixIcon: Icon(Icons.credit_card, color: AppTheme.primary, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiryController,
                  onChanged: _formatExpiry,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "MM/YY",
                    prefixIcon: Icon(Icons.calendar_today, color: AppTheme.primary, size: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cvcController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "CVC",
                    prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primary, size: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankTransferFields(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text("Bank Account Details", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bankNameController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Bank Name",
              prefixIcon: Icon(Icons.business, color: AppTheme.primary, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNameController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Account Holder Name",
              prefixIcon: Icon(Icons.person, color: AppTheme.primary, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Account Number",
              prefixIcon: Icon(Icons.numbers, color: AppTheme.primary, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ribController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "RIB",
              prefixIcon: Icon(Icons.receipt, color: AppTheme.primary, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodChip(String label, bool isSelected, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : (isDark ? const Color(0xFF0F172A) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey[400]!, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawalHistory(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Withdrawal History", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          ..._withdrawalHistory.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${w['amount']} DZD", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      Text("${w['date']} • ${w['method']}", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(w['status'].toUpperCase(), style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}