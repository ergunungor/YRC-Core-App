import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

// Bu dosya SADECE web derlemesinde kullanılır.
// Native (gerçek) bir <input type="file"> elementini görünmez şekilde
// ekrana yerleştirip, kullanıcının GERÇEK dokunuşunun doğrudan bu native
// elemente ulaşmasını sağlıyoruz — Safari'nin engellediği "JS'ten .click()
// ile tetikleme" adımını hiç kullanmıyoruz.
class WebFilePickerOverlay extends StatelessWidget {
  final void Function(Uint8List bytes, String fileName) onFileSelected;

  const WebFilePickerOverlay({super.key, required this.onFileSelected});

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'input',
      onElementCreated: (Object element) {
        final input = element as web.HTMLInputElement;
        input.type = 'file';
        input.accept = 'image/*';
        input.style
          ..width = '100%'
          ..height = '100%'
          ..opacity = '0'
          ..cursor = 'pointer'
          ..position = 'absolute'
          ..top = '0'
          ..left = '0';

        input.addEventListener(
          'change',
          (web.Event event) {
            _handleChange(input);
          }.toJS,
        );
      },
    );
  }

  Future<void> _handleChange(web.HTMLInputElement input) async {
    final files = input.files;
    if (files == null || files.length == 0) return;
    final file = files.item(0);
    if (file == null) return;

    final reader = web.FileReader();
    final completer = Completer<void>();

    reader.addEventListener(
      'loadend',
      (web.Event event) {
        completer.complete();
      }.toJS,
    );

    reader.readAsArrayBuffer(file);
    await completer.future;

    final result = reader.result;
    if (result == null) return;

    final buffer = (result as JSArrayBuffer).toDart;
    final bytes = buffer.asUint8List();

    onFileSelected(bytes, file.name);

    // Aynı dosyanın tekrar seçilebilmesi için input'u sıfırla
    input.value = '';
  }
}
