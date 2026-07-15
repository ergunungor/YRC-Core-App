import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/event_type.dart';
import '../services/event_repository.dart';
import '../theme/app_theme.dart';

class EventCreateScreen extends StatefulWidget {
  // Gerçek projede aktif kullanıcının strava_id'si buraya parametre veya state management üzerinden gelmeli.
  final int currentStravaId;

  const EventCreateScreen({super.key, required this.currentStravaId});

  @override
  State<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends State<EventCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final EventRepository _repository = EventRepository();

  bool _isLoading = false;
  File? _coverImage;

  String? _title;
  String? _location;
  String? _distance;
  String? _pace;

  EventType _selectedType = EventType.socialRun;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // --- Yardımcı Fonksiyonlar (Helpers) ---

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality:
          80, // Depolama tasarrufu ve hızlı yükleme için kaliteyi optimize ediyoruz
    );

    if (pickedFile != null) {
      setState(() => _coverImage = File(pickedFile.path));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.yrcAccent),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 30),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.yrcAccent,
              secondary: AppColors.yrcAccent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Ana Kayıt Akışı ---

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_coverImage == null) {
      _showError(
        'Lütfen etkinlik için motivasyon verici bir kapak fotoğrafı seçin.',
      );
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showError('Lütfen etkinliğin tarihini ve saatini belirleyin.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      _formKey.currentState!.save();

      // 1. Fotoğrafı Storage'a Yükle
      final fileExtension = _coverImage!.path.split('.').last;
      final String coverUrl = await _repository.uploadEventCoverImage(
        _coverImage!,
        fileExtension,
      );

      // 2. Tarih ve Saati Birleştir
      final DateTime eventDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // 3. Veritabanına Kaydet
      await _repository.createEvent(
        title: _title!,
        type: _selectedType,
        date: eventDateTime,
        location: _location!,
        distance: _distance,
        pace: _pace,
        coverImageUrl: coverUrl,
        stravaId: widget.currentStravaId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔥 Etkinlik başarıyla oluşturuldu!'),
          backgroundColor: Color(0xFF34C759),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context); // İşlem bitince listeye geri dön
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Builder Metodları ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.yrcBackground,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Yeni Koşu',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120), // Buton için boşluk
              children: [
                _buildImagePicker(),
                const SizedBox(height: 24),
                _buildSectionLabel('TEMEL BİLGİLER'),
                _buildTypeSelector(),
                _buildGlassGroup(
                  children: [
                    _buildTextField(
                      label: 'Etkinlik Adı',
                      hint: 'Örn: Bebek Sahil Antrenmanı',
                      onSaved: (val) => _title = val,
                      validator:
                          (val) =>
                              val == null || val.trim().isEmpty
                                  ? 'Başlık zorunludur'
                                  : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionLabel('ZAMAN VE MEKAN'),
                _buildGlassGroup(
                  children: [
                    _buildDateTimeRow(),
                    const Divider(color: Colors.white10, height: 1),
                    _buildTextField(
                      label: 'Buluşma Noktası',
                      hint: 'Örn: Bebek Starbucks Önü',
                      icon: Icons.location_on_rounded,
                      onSaved: (val) => _location = val,
                      validator:
                          (val) =>
                              val == null || val.trim().isEmpty
                                  ? 'Konum zorunludur'
                                  : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionLabel('HEDEFLER (OPSİYONEL)'),
                _buildGlassGroup(
                  children: [
                    _buildTextField(
                      label: 'Mesafe',
                      hint: 'Örn: 10K, 5-8K, 8x400m',
                      icon: Icons.route_rounded,
                      onSaved: (val) => _distance = val,
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    _buildTextField(
                      label: 'Hedef Tempo (Pace)',
                      hint: 'Örn: 5:30, 6:00 - 6:30',
                      icon: Icons.speed_rounded,
                      onSaved: (val) => _pace = val,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Alt kısımdaki sabit kaydet butonu ve loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.yrcAccent),
              ),
            )
          else
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.yrcBackground,
                          AppColors.yrcBackground.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yrcSoftBlue, // Neon Turuncu
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                        elevation: 8,
                        shadowColor: AppColors.yrcSoftBlue.withValues(
                          alpha: 0.8,
                        ),
                      ),
                      child: const Text(
                        'ETKİNLİĞİ YAYINLA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.4),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildGlassGroup({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 220,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                _coverImage != null
                    ? AppColors.yrcSoftBlue
                    : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
          image:
              _coverImage != null
                  ? DecorationImage(
                    image: FileImage(_coverImage!),
                    fit: BoxFit.cover,
                  )
                  : null,
        ),
        child:
            _coverImage == null
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kapak Fotoğrafı Seç',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
                : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Değiştirmek için dokun',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: EventType.values.length,
        itemBuilder: (context, index) {
          final type = EventType.values[index];
          final isSelected = _selectedType == type;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                type.uiLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      isSelected
                          ? Colors.white
                          : AppColors.yrcBackground.withValues(alpha: 0.6),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedType = type);
              },
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              selectedColor: AppColors.yrcSoftBlue, // Neon Turuncu
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
                side: BorderSide(
                  color:
                      isSelected ? AppColors.yrcSoftBlue : Colors.transparent,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    IconData? icon,
    required Function(String?) onSaved,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
          prefixIcon:
              icon != null
                  ? Icon(icon, color: Colors.white.withValues(alpha: 0.5))
                  : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorStyle: const TextStyle(color: Colors.redAccent),
        ),
        validator: validator,
        onSaved: onSaved,
      ),
    );
  }

  Widget _buildDateTimeRow() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _pickDate,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tarih',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedDate != null
                        ? DateFormat(
                          'd MMM yyyy',
                          'tr_TR',
                        ).format(_selectedDate!)
                        : 'Seçiniz',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(width: 1, height: 40, color: Colors.white10),
        Expanded(
          child: InkWell(
            onTap: _pickTime,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saat',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedTime != null
                        ? _selectedTime!.format(context)
                        : 'Seçiniz',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
