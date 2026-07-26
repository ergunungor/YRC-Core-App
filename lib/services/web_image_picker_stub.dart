import 'dart:typed_data';
import 'package:flutter/widgets.dart';

// Bu dosya SADECE mobil (iOS/Android) derlemesinde kullanılır.
// package:web mobilde derlenemediği için, mobil tarafta hiçbir işlevi
// olmayan boş bir "yer tutucu" widget sağlıyoruz.
class WebFilePickerOverlay extends StatelessWidget {
  final void Function(Uint8List bytes, String fileName) onFileSelected;

  const WebFilePickerOverlay({super.key, required this.onFileSelected});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
