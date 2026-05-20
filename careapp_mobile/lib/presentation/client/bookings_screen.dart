import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../services/client_api_service.dart';
import 'payment_screen.dart';
import 'tracking_screen.dart';

enum BookingStatus { confirmed, pending, completed, cancelled }

class Booking {
  final String id;
  final String serviceType;
  final String providerName;
  final String providerAvatar;
  final String date;
  final String time;
  final String location;
  final double price;
  final BookingStatus status;
  final String dependantName;
  final String notes;
  bool halfPaid;
  final double remainingAmount;

  Booking({
    required this.id,
    required this.serviceType,
    required this.providerName,
    required this.providerAvatar,
    required this.date,
    required this.time,
    required this.location,
    required this.price,
    required this.status,
    required this.dependantName,
    required this.notes,
    this.halfPaid = false,
    this.remainingAmount = 0,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    BookingStatus parseStatus(String status) {
      switch (status.toLowerCase()) {
        case 'confirmed':
          return BookingStatus.confirmed;
        case 'pending':
          return BookingStatus.pending;
        case 'completed':
          return BookingStatus.completed;
        case 'cancelled':
          return BookingStatus.cancelled;
        default:
          return BookingStatus.pending;
      }
    }

    return Booking(
      id: json['_id'] ?? json['id'] ?? '',
      serviceType: json['service'] ?? json['serviceType'] ?? '',
      providerName: json['provider'] ?? json['providerName'] ?? '',
      providerAvatar: json['providerAvatar'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      location: json['location'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      status: parseStatus(json['status'] ?? 'pending'),
      dependantName: json['dependantName'] ?? '',
      notes: json['notes'] ?? '',
      halfPaid: json['halfPaid'] == true,
      remainingAmount: (json['remainingAmount'] ?? 0).toDouble(),
    );
  }
}

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  
  final ClientApiService _api = ClientApiService();
  
  String _selectedFilter = 'All';
  bool _isLoading = true;
  List<Booking> _bookings = [];
  bool _isProcessing = false;
  
  final List<String> _filters = ['All', 'Confirmed', 'Pending', 'Completed', 'Cancelled'];

  final Map<String, dynamic> _serviceTypes = {
    'Super Nanny': {
      'icon': Icons.child_care_rounded,
      'color': const Color(0xFF8B5CF6),
    },
    'Babysitter': {
      'icon': Icons.baby_changing_station_rounded,
      'color': const Color(0xFFF59E0B),
    },
    'Pickup': {
      'icon': Icons.directions_car_rounded,
      'color': const Color(0xFF3B82F6),
    },
    'Elderly Care': {
      'icon': Icons.elderly_rounded,
      'color': const Color(0xFF0D6E6E),
    },
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadBookings();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
  
  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final bookingsData = await _api.getBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookingsData.map((b) => Booking.fromJson(b)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load bookings: $e', AppTheme.error);
    }
  }

  Future<void> _payRemaining(Booking booking) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final result = await _api.payRemaining(booking.id);
      if (result['success'] == true) {
        _showSnackBar('Payment successful!', Colors.green);
        await _loadBookings(); // تحديث القائمة
        _showRatingDialog(booking);
      } else {
        _showSnackBar(result['message'] ?? 'Payment failed', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _payHalfForBooking(Booking booking) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(initialBookingId: booking.id),
        ),
      );
      await _loadBookings();
      setState(() => _isProcessing = false);
    } else {
      setState(() => _isProcessing = false);
    }
  }

  void _showRatingDialog(Booking booking) {
    int rating = 0;
    String comment = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Rate the Provider"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How was your experience?"),
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Skip"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _submitRating(booking.id, rating, comment);
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
      if (result['success'] == true) {
        _showSnackBar('Thank you for your feedback!', Colors.green);
        await _loadBookings();
      } else {
        _showSnackBar(result['message'] ?? 'Failed to submit rating', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  List<Booking> get _filteredBookings {
    if (_selectedFilter == 'All') return _bookings;
    return _bookings.where((b) {
      switch (_selectedFilter) {
        case 'Confirmed':
          return b.status == BookingStatus.confirmed;
        case 'Pending':
          return b.status == BookingStatus.pending;
        case 'Completed':
          return b.status == BookingStatus.completed;
        case 'Cancelled':
          return b.status == BookingStatus.cancelled;
        default:
          return true;
      }
    }).toList();
  }

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
        return AppTheme.success;
      case BookingStatus.pending:
        return AppTheme.warning;
      case BookingStatus.completed:
        return AppTheme.primary;
      case BookingStatus.cancelled:
        return AppTheme.error;
    }
  }

  String _statusLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Booking', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to cancel this booking?', style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep', style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text('Cancel Booking', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _api.cancelBooking(booking.id);
        await _loadBookings();
        _showSnackBar('Booking cancelled', AppTheme.success);
      } catch (e) {
        _showSnackBar('Failed to cancel booking', AppTheme.error);
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showNewBookingDialog({String? preselectedService, String? providerId, String? providerName}) {
    String selectedService = preselectedService ?? 'Super Nanny';
    String? selectedProviderId = providerId;
    String? selectedProviderName = providerName;
    
    final locationCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: _formatDate(DateTime.now().add(const Duration(days: 1))));
    final timeCtrl = TextEditingController(text: '10:00 AM');
    final formKey = GlobalKey<FormState>();

    final bool isFromAd = providerId != null && providerId.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('New Booking', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (isFromAd) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.store, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Provider', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
                                Text(selectedProviderName ?? 'Provider', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('Service Type', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _serviceTypes.keys.map((type) {
                      final isSelected = selectedService == type;
                      final info = _serviceTypes[type] as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedService = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? (info['color'] as Color).withAlpha(25) : AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? info['color'] as Color : AppTheme.divider, width: isSelected ? 2 : 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(info['icon'] as IconData, color: isSelected ? info['color'] as Color : AppTheme.textMuted, size: 18),
                              const SizedBox(width: 6),
                              Text(type, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? info['color'] as Color : AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _sheetField('Date', dateCtrl, Icons.calendar_today_rounded),
                  const SizedBox(height: 14),
                  _sheetField('Time', timeCtrl, Icons.access_time_rounded),
                  const SizedBox(height: 14),
                  _sheetField('Location / Address', locationCtrl, Icons.location_on_outlined),
                  const SizedBox(height: 14),
                  _sheetField('Notes (optional)', notesCtrl, Icons.note_outlined, required: false),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);
                        try {
                          final bookingData = {
                            'service': selectedService,
                            'date': dateCtrl.text,
                            'time': timeCtrl.text,
                            'location': locationCtrl.text,
                            'notes': notesCtrl.text,
                          };
                          if (selectedProviderId != null && selectedProviderId.isNotEmpty) {
                            bookingData['providerId'] = selectedProviderId;
                          }
                          await _api.createBooking(bookingData);
                          await _loadBookings();
                          if (mounted) {
                            _showSnackBar('Booking created successfully!', AppTheme.success);
                          }
                        } catch (e) {
                          if (mounted) setState(() => _isLoading = false);
                          _showSnackBar('Failed to create booking: $e', AppTheme.error);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Confirm Booking', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    color: AppTheme.primary,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: _filters.map((f) {
                          final isSelected = _selectedFilter == f;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedFilter = f),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.white.withAlpha(30),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                f,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? AppTheme.primary : Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _filteredBookings.isEmpty
                        ? _buildEmpty(isDark)
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _filteredBookings.length,
                            itemBuilder: (context, i) => _buildBookingCard(_filteredBookings[i], isDark),
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewBookingDialog(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Booking', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, bool isDark) {
    final serviceInfo = _serviceTypes[booking.serviceType] as Map<String, dynamic>?;
    final color = serviceInfo?['color'] as Color? ?? AppTheme.primary;
    final icon = serviceInfo?['icon'] as IconData? ?? Icons.miscellaneous_services_rounded;
    final statusColor = _statusColor(booking.status);
    final bool needsHalfPayment = (booking.status == BookingStatus.confirmed && !booking.halfPaid);
    final bool needsRemainingPayment = (booking.status == BookingStatus.completed && booking.remainingAmount > 0);
    final bool showTrackButton = (booking.status == BookingStatus.confirmed) ||
                                 (booking.status == BookingStatus.completed && booking.remainingAmount > 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.serviceType, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimary)),
                      Text(booking.id, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(20)),
                  child: Text(_statusLabel(booking.status), style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                ClipOval(
                  child: booking.providerAvatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: booking.providerAvatar,
                          width: 32, height: 32, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 32, height: 32,
                            color: color.withAlpha(30),
                            child: Icon(Icons.person_rounded, color: color, size: 16),
                          ),
                        )
                      : Container(
                          width: 32, height: 32,
                          color: AppTheme.primaryContainer,
                          child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 16),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(booking.providerName, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _infoChip(Icons.calendar_today_rounded, booking.date),
                const SizedBox(width: 8),
                _infoChip(Icons.access_time_rounded, booking.time),
              ],
            ),
            const SizedBox(height: 6),
            _infoChip(Icons.location_on_outlined, booking.location),
            
            // زر دفع نصف المبلغ
            if (needsHalfPayment) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _payHalfForBooking(booking),
                  icon: const Icon(Icons.payment, size: 18),
                  label: Text('Pay Half (${(booking.price / 2).toStringAsFixed(0)} DZD) to Start Tracking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            
            // زر دفع الرصيد المتبقي
            if (needsRemainingPayment) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _payRemaining(booking),
                  icon: const Icon(Icons.payment, size: 18),
                  label: Text("Pay Remaining (${booking.remainingAmount.toStringAsFixed(0)} DZD)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            
            // أزرار Cancel و Track (للحجوزات غير الملغاة)
            if (booking.status != BookingStatus.cancelled) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (booking.status != BookingStatus.completed)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelBooking(booking),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  if (showTrackButton)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.clientTracking,
                            arguments: {'bookingId': booking.id},
                          );
                        },
                        icon: const Icon(Icons.location_on_outlined, size: 16),
                        label: Text('Track', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppTheme.primaryContainer.withAlpha(80), shape: BoxShape.circle),
            child: const Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text('No Bookings Found', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Tap the button below to make\nyour first booking.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _sheetField(String label, TextEditingController ctrl, IconData icon, {TextInputType keyboardType = TextInputType.text, bool required = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : AppTheme.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    );
  }
}