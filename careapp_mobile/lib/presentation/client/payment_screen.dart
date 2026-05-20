import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../services/client_api_service.dart';
import 'tracking_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String? initialBookingId;
  const PaymentScreen({super.key, this.initialBookingId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  
  final ClientApiService _api = ClientApiService();
  
  int _selectedTab = 0;
  bool _isLoading = true;
  bool _isProcessing = false;
  
  List<Map<String, dynamic>> _pendingPayments = [];
  List<Map<String, dynamic>> _completedPayments = [];
  List<Map<String, dynamic>> _remainingPayments = [];
  double _totalPending = 0;
  
  final _formKey = GlobalKey<FormState>();
  String _selectedMethod = 'Edahabia';
  
  // Edahabia fields
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();
  final _cardHolderCtrl = TextEditingController();
  
  // Bank Transfer fields
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ribCtrl = TextEditingController();
  
  // CCP fields
  final _ccpNumberCtrl = TextEditingController();
  final _ccpKeyCtrl = TextEditingController();
  final _ccpHolderCtrl = TextEditingController();
  
  String _selectedBookingId = '';
  double _selectedAmount = 0;
  bool _isRemaining = false;
  
  // Provider bank info
  String _providerCcp = '';
  String _providerBankName = '';
  String _providerAccountNumber = '';
  String _providerAccountHolder = '';
  String _providerRib = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvcCtrl.dispose();
    _cardHolderCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ribCtrl.dispose();
    _ccpNumberCtrl.dispose();
    _ccpKeyCtrl.dispose();
    _ccpHolderCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final pending = await _api.getPendingPayments();
      print('Pending payments raw: $pending');
      
      final bookings = await _api.getBookings(status: 'Completed');
      final remaining = bookings.where((b) => 
        b['paymentStatus'] != 'Completed' && 
        (b['remainingAmount'] ?? 0) > 0
      ).toList();
      
      setState(() {
        _pendingPayments = pending.map((p) {
          double amount = 0;
          if (p['amount'] is int) amount = (p['amount'] as int).toDouble();
          else if (p['amount'] is double) amount = p['amount'] as double;
          else if (p['amount'] is String) amount = double.tryParse(p['amount']) ?? 0;
          else if (p['amount'] is num) amount = (p['amount'] as num).toDouble();
          
          return {
            'id': p['_id'],
            'bookingId': p['bookingId'],
            'service': p['service'],
            'provider': p['provider'],
            'amount': amount,
            'dueDate': p['dueDate'],
            'providerBank': p['providerBank'] ?? {},
            'type': 'half',
          };
        }).toList();
        
        _remainingPayments = remaining.map((b) {
          double amount = (b['remainingAmount'] ?? 0).toDouble();
          return {
            'id': b['_id'],
            'bookingId': b['_id'],
            'service': b['service'],
            'provider': b['provider'],
            'amount': amount,
            'dueDate': b['date'],
            'providerBank': b['providerBank'] ?? {},
            'type': 'remaining',
          };
        }).toList();
        
        _totalPending = _pendingPayments.fold(0, (sum, p) => sum + (p['amount'] as double));
        
        _selectDefaultPayment();
      });
      
      final history = await _api.getPaymentHistory();
      if (mounted) {
        setState(() {
          _completedPayments = history.map((p) {
            double amount = 0;
            if (p['amount'] is int) amount = (p['amount'] as int).toDouble();
            else if (p['amount'] is double) amount = p['amount'] as double;
            else if (p['amount'] is String) amount = double.tryParse(p['amount']) ?? 0;
            else if (p['amount'] is num) amount = (p['amount'] as num).toDouble();
            return {
              'id': p['_id'],
              'service': p['service'],
              'provider': p['provider'],
              'amount': amount,
              'date': p['date'],
              'status': p['status'],
              'method': p['paymentMethod'],
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load payment data: $e');
      }
    }
  }

  void _selectDefaultPayment() {
    // تحديد التبويب المناسب
    if (_pendingPayments.isNotEmpty) {
      _selectedTab = 0;
      _selectedBookingId = _pendingPayments[0]['bookingId'].toString();
      _selectedAmount = _pendingPayments[0]['amount'];
      _isRemaining = false;
      _updateProviderBankFromSelected();
    } else if (_remainingPayments.isNotEmpty) {
      _selectedTab = 2;
      _selectedBookingId = _remainingPayments[0]['bookingId'].toString();
      _selectedAmount = _remainingPayments[0]['amount'];
      _isRemaining = true;
      _updateProviderBankFromSelected();
    } else {
      _selectedBookingId = '';
      _selectedAmount = 0;
    }
  }

  void _updateProviderBankFromSelected() {
    final allPayments = [..._pendingPayments, ..._remainingPayments];
    final selected = allPayments.firstWhere(
      (p) => p['bookingId'].toString() == _selectedBookingId,
      orElse: () => {},
    );
    final bank = selected['providerBank'] ?? {};
    setState(() {
      _providerCcp = bank['ccp'] ?? '';
      _providerBankName = bank['bankName'] ?? '';
      _providerAccountNumber = bank['accountNumber'] ?? '';
      _providerAccountHolder = bank['accountHolder'] ?? '';
      _providerRib = bank['rib'] ?? '';
    });
  }

  void _formatCardNumber(String text) {
    String cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted = '';
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) formatted += ' ';
      formatted += cleaned[i];
    }
    _cardNumberCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _formatExpiry(String text) {
    String cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length >= 3) {
      _expiryCtrl.value = TextEditingValue(
        text: '${cleaned.substring(0, 2)}/${cleaned.substring(2, cleaned.length > 4 ? 4 : cleaned.length)}',
        selection: TextSelection.collapsed(offset: cleaned.length > 2 ? cleaned.length + 1 : cleaned.length),
      );
    } else {
      _expiryCtrl.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }
  }

  Future<void> _processPayment() async {
    if (_selectedBookingId.isEmpty) {
      _showError('Please select a booking');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isProcessing = true);
    try {
      Map<String, dynamic> paymentDetails = {};
      switch (_selectedMethod) {
        case 'Edahabia':
          paymentDetails = {
            'cardNumber': _cardNumberCtrl.text.replaceAll(' ', ''),
            'expiry': _expiryCtrl.text,
            'cvc': _cvcCtrl.text,
            'cardHolder': _cardHolderCtrl.text,
          };
          break;
        case 'Bank Transfer':
          paymentDetails = {
            'bankName': _bankNameCtrl.text,
            'accountNumber': _accountNumberCtrl.text,
            'rib': _ribCtrl.text,
          };
          break;
        case 'CCP':
          paymentDetails = {
            'ccpNumber': _ccpNumberCtrl.text,
            'ccpKey': _ccpKeyCtrl.text,
            'ccpHolder': _ccpHolderCtrl.text,
          };
          break;
        case 'Cash':
          paymentDetails = {'note': 'Cash payment on delivery'};
          break;
      }
      
      if (_isRemaining) {
        // دفع الرصيد المتبقي
        final result = await _api.payRemaining(_selectedBookingId);
        if (mounted) {
          _showSnackBar('✅ Remaining payment successful! Amount: ${result['remainingAmount']} DZD', Colors.green);
          // بعد دفع المتبقي، عرض نافذة تقييم المزود
          _showRatingDialog(_selectedBookingId);
        }
      } else {
        // نصف الدفع
        final result = await _api.payHalf(_selectedBookingId, _selectedMethod, paymentDetails);
        if (mounted) {
          _showSnackBar('✅ Half payment successful! Tracking started. Remaining: ${result['remainingAmount']} DZD', Colors.green);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TrackingScreen(bookingId: _selectedBookingId),
            ),
          );
        }
      }
    } catch (e) {
      _showError('Payment failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRatingDialog(String bookingId) {
    int rating = 0;
    String comment = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Rate Your Experience"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How was your experience with the provider?"),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                  onPressed: () => setDialogState(() => rating = i + 1),
                )),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Leave a comment...",
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => comment = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // العودة إلى شاشة الحجوزات
                Navigator.pop(context);
              },
              child: const Text("Skip"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _submitRating(bookingId, rating, comment);
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(String bookingId, int rating, String comment) async {
    setState(() => _isProcessing = true);
    try {
      final result = await _api.rateProvider(bookingId, rating, comment);
      if (mounted) {
        if (result['success'] == true) {
          _showSnackBar('Thank you for your feedback!', Colors.green);
          Navigator.pop(context); // العودة من PaymentScreen إلى BookingsScreen
        } else {
          _showError(result['message'] ?? 'Failed to submit rating');
        }
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Payments'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _tabButton('Pending (${_pendingPayments.length})', 0),
                if (_remainingPayments.isNotEmpty) ...[
                  const SizedBox(width: 20),
                  _tabButton('Remaining (${_remainingPayments.length})', 2),
                ],
                const SizedBox(width: 20),
                _tabButton('History (${_completedPayments.length})', 1),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _selectedTab == 0
                ? _buildPendingTab()
                : _selectedTab == 2 && _remainingPayments.isNotEmpty
                    ? _buildRemainingTab()
                    : _buildHistoryTab(),
      ),
    );
  }

  Widget _tabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
          // عند تغيير التبويب، حدد أول عنصر في القائمة الجديدة
          if (index == 0 && _pendingPayments.isNotEmpty) {
            _selectedBookingId = _pendingPayments[0]['bookingId'].toString();
            _selectedAmount = _pendingPayments[0]['amount'];
            _isRemaining = false;
            _updateProviderBankFromSelected();
          } else if (index == 2 && _remainingPayments.isNotEmpty) {
            _selectedBookingId = _remainingPayments[0]['bookingId'].toString();
            _selectedAmount = _remainingPayments[0]['amount'];
            _isRemaining = true;
            _updateProviderBankFromSelected();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_pendingPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payment_rounded, color: AppTheme.primary, size: 40),
            ),
            const SizedBox(height: 16),
            Text('No Pending Payments', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('You have no outstanding half payments.', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return _buildPaymentForm(isDark, halfMode: true);
  }

  Widget _buildRemainingTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_remainingPayments.isEmpty) {
      return const SizedBox.shrink();
    }
    return _buildPaymentForm(isDark, halfMode: false);
  }

  Widget _buildPaymentForm(bool isDark, {required bool halfMode}) {
    final amountToPay = halfMode ? _selectedAmount / 2 : _selectedAmount;
    final paymentsList = halfMode ? _pendingPayments : _remainingPayments;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: halfMode 
                ? const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF0284C7)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(halfMode ? 'Half Payment' : 'Remaining Payment', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text('${amountToPay.toStringAsFixed(0)} DZD', style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text('${paymentsList.length} payment${paymentsList.length != 1 ? 's' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Payment', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedBookingId.isNotEmpty ? _selectedBookingId : null,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Select Booking',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : AppTheme.surfaceVariant,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: paymentsList.map<DropdownMenuItem<String>>((p) {
                      return DropdownMenuItem<String>(
                        value: p['bookingId'].toString(),
                        child: Text('${p['service']} - ${p['amount']} DZD'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedBookingId = v;
                          final selected = paymentsList.firstWhere((p) => p['bookingId'].toString() == v);
                          _selectedAmount = selected['amount'];
                          _isRemaining = !halfMode;
                          _updateProviderBankFromSelected();
                        });
                      }
                    },
                  ),
                  
                  // Provider's bank details
                  if (_providerCcp.isNotEmpty || _providerBankName.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.account_balance, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text("Provider's Payment Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_providerCcp.isNotEmpty) Text("CCP: $_providerCcp", style: const TextStyle(fontSize: 13)),
                          if (_providerBankName.isNotEmpty) Text("Bank: $_providerBankName", style: const TextStyle(fontSize: 13)),
                          if (_providerAccountNumber.isNotEmpty) Text("Account: $_providerAccountNumber", style: const TextStyle(fontSize: 13)),
                          if (_providerAccountHolder.isNotEmpty) Text("Holder: $_providerAccountHolder", style: const TextStyle(fontSize: 13)),
                          if (_providerRib.isNotEmpty) Text("RIB: $_providerRib", style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 8),
                          Text(
                            halfMode 
                              ? "Please transfer the half amount to the above account."
                              : "Please transfer the remaining amount to the above account.",
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  Text('Payment Method', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _methodChip('Edahabia', Icons.credit_card, isDark),
                      _methodChip('Bank Transfer', Icons.account_balance, isDark),
                      _methodChip('CCP', Icons.receipt, isDark),
                      if (halfMode) _methodChip('Cash', Icons.money, isDark),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // باقي الحقول (نفس الكود الأصلي)
                  if (_selectedMethod == 'Edahabia') ...[
                    TextFormField(
                      controller: _cardHolderCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
                      decoration: _inputDecoration('Your Card Holder Name', Icons.person_outline, isDark),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cardNumberCtrl,
                      onChanged: (_) => _formatCardNumber(_cardNumberCtrl.text),
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
                      decoration: _inputDecoration('Your Card Number', Icons.credit_card, isDark),
                      validator: (v) => (v == null || v.replaceAll(' ', '').length < 16) ? 'Invalid card number' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryCtrl,
                            onChanged: _formatExpiry,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
                            decoration: _inputDecoration('MM/YY', Icons.calendar_today, isDark),
                            validator: (v) => (v == null || v.length < 5) ? 'Invalid expiry' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cvcCtrl,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
                            decoration: _inputDecoration('CVC', Icons.lock_outline, isDark),
                            validator: (v) => (v == null || v.length < 3) ? 'Invalid CVC' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_selectedMethod == 'Bank Transfer') ...[
                    TextFormField(
                      controller: _bankNameCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
                      decoration: _inputDecoration('Your Bank Name', Icons.business, isDark),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accountNumberCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
                      decoration: _inputDecoration('Your Account Number', Icons.numbers, isDark),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ribCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
                      decoration: _inputDecoration('Your RIB', Icons.receipt, isDark),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ],
                  if (_selectedMethod == 'CCP') ...[
                    TextFormField(
                      controller: _ccpHolderCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
                      decoration: _inputDecoration('Your CCP Account Holder', Icons.person, isDark),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ccpNumberCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
                      decoration: _inputDecoration('Your CCP Number', Icons.credit_card, isDark),
                      validator: (v) => (v == null || v.length < 10) ? 'Invalid CCP number' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ccpKeyCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
                      decoration: _inputDecoration('Your CCP Key (Clé)', Icons.lock_outline, isDark),
                      validator: (v) => (v == null || v.length < 2) ? 'Required' : null,
                    ),
                  ],
                  if (_selectedMethod == 'Cash' && halfMode) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You will pay ${amountToPay.toStringAsFixed(0)} DZD in cash to the provider when the service starts.',
                              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              halfMode 
                                ? 'Pay Half (${amountToPay.toStringAsFixed(0)} DZD)'
                                : 'Pay Remaining (${amountToPay.toStringAsFixed(0)} DZD)',
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_completedPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: AppTheme.primary.withAlpha(30), shape: BoxShape.circle),
              child: const Icon(Icons.history_rounded, color: AppTheme.primary, size: 40),
            ),
            const SizedBox(height: 16),
            Text('No Payment History', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('Your payment history will appear here.', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedPayments.length,
      itemBuilder: (context, index) {
        final payment = _completedPayments[index];
        return _buildHistoryCard(payment);
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> payment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = payment['status'] == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCompleted ? AppTheme.success.withAlpha(25) : AppTheme.warning.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isCompleted ? Icons.check_circle : Icons.pending, color: isCompleted ? AppTheme.success : AppTheme.warning, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment['service'], style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimary)),
                Text(payment['provider'], style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary)),
                Text('${payment['date']} • ${payment['method']}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${payment['amount']} DZD', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCompleted ? AppTheme.success.withAlpha(25) : AppTheme.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(payment['status'].toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: isCompleted ? AppTheme.success : AppTheme.warning)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _methodChip(String label, IconData icon, bool isDark) {
    final isSelected = _selectedMethod == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : (isDark ? const Color(0xFF0F172A) : AppTheme.surfaceVariant),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppTheme.textSecondary, size: 18),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary),
      prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : AppTheme.surfaceVariant,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}