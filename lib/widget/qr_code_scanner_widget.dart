import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrCodeScannerWidget extends StatefulWidget {
  final void Function(String data) onScanned;

  const QrCodeScannerWidget({super.key, required this.onScanned});

  @override
  State<QrCodeScannerWidget> createState() => _QrCodeScannerWidgetState();
}

class _QrCodeScannerWidgetState extends State<QrCodeScannerWidget> {
  bool _isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {
          if (!_isScanning) return;

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? code = barcodes.first.rawValue;
            if (code != null) {
              setState(() {
                _isScanning = false;
              });
              widget.onScanned(code);
              Navigator.pop(context);
            }
          }
        },
      ),
    );
  }
}
