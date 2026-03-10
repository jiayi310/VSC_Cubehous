import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A full-screen barcode/QR scanner.
/// Returns the scanned string via [Navigator.pop].
class ScannerPage extends StatefulWidget {
  final String title;
  const ScannerPage({super.key, this.title = 'Scan Barcode'});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw != null && raw.isNotEmpty) {
      _scanned = true;
      Navigator.of(context).pop(raw);
    }
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white),
            onPressed: _controller.switchCamera,
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Overlay frame
          CustomPaint(
            painter: _ScanFramePainter(),
            child: const SizedBox(width: 240, height: 240),
          ),
          Positioned(
            bottom: 60,
            child: Text(
              'Align barcode within the frame',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLen = 28.0;
    const r = 6.0;

    // Top-left
    canvas.drawLine(Offset(0, cornerLen), const Offset(0, r), paint);
    canvas.drawArc(const Rect.fromLTWH(0, 0, r * 2, r * 2), 3.14, -1.57, false, paint);
    canvas.drawLine(const Offset(r, 0), Offset(cornerLen, 0), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - cornerLen, 0), Offset(size.width - r, 0), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2), 4.71, -1.57, false, paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, cornerLen), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height - cornerLen), Offset(0, size.height - r), paint);
    canvas.drawArc(Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2), 1.57, -1.57, false, paint);
    canvas.drawLine(Offset(r, size.height), Offset(cornerLen, size.height), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - cornerLen, size.height), Offset(size.width - r, size.height), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2), 0, -1.57, false, paint);
    canvas.drawLine(Offset(size.width, size.height - r), Offset(size.width, size.height - cornerLen), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
