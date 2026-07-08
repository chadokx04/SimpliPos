import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../providers/product_provider.dart';

/// Set [returnResult] to pop the scanner with the scanned barcode string as
/// soon as one is detected, instead of looking it up against products. Used
/// when a caller just wants a barcode value (e.g. to fill in a form field).
///
/// Set [onBarcodeDetected] to hand each detected barcode to a callback
/// (given this screen's own [BuildContext], e.g. to show a dialog or
/// navigate) whose returned message is shown in a SnackBar. If the callback
/// leaves this screen mounted, scanning resumes automatically so several
/// items can be scanned in one session; if it navigates away (as POS does
/// after a quantity is entered), this screen is simply gone and no SnackBar
/// or resume happens.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    this.returnResult = false,
    this.onBarcodeDetected,
  });

  final bool returnResult;
  final Future<String> Function(BuildContext context, String barcode)? onBarcodeDetected;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _isProcessing = true);
    await _controller.stop();
    if (!mounted) return;

    if (widget.returnResult) {
      Navigator.of(context).pop(barcode);
      return;
    }

    if (widget.onBarcodeDetected != null) {
      final message = await widget.onBarcodeDetected!(context, barcode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _isProcessing = false);
      await _controller.start();
      return;
    }

    final product = await context.read<ProductProvider>().findByBarcode(barcode);
    if (!mounted) return;

    if (product != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Product found'),
          content: Text('${product.name} (SKU: ${product.sku})'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/products/${product.id}');
              },
              child: const Text('View Product'),
            ),
          ],
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No product found'),
          content: Text('No product matches barcode "$barcode". Add it as a new product?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/products/add', extra: barcode);
              },
              child: const Text('Add Product'),
            ),
          ],
        ),
      );
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator()),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Point the camera at a product barcode',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
