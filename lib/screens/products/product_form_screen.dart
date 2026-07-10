import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/product_photo_store.dart';

/// Add/Edit form. Pass [productId] to edit an existing product; leave it
/// null to create a new one. [prefillBarcode] is used when arriving from
/// the barcode scanner with a code that didn't match any product.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.productId, this.prefillBarcode});

  final int? productId;
  final String? prefillBarcode;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _priceController = TextEditingController(text: '0.00');
  final _sellingPriceController = TextEditingController(text: '0.00');

  final _nameFocusNode = FocusNode();
  final _barcodeFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _sellingPriceFocusNode = FocusNode();

  Product? _existingProduct;
  int? _selectedCategoryId;
  String? _photoPath;
  File? _pickedPhotoFile;
  String? _barcodeError;
  String? _nameError;
  String _pendingSku = '';
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _barcodeController.text = widget.prefillBarcode ?? '';
    _selectAllOnFocus(_nameFocusNode, _nameController);
    _selectAllOnFocus(_barcodeFocusNode, _barcodeController);
    _selectAllOnFocus(_quantityFocusNode, _quantityController);
    _selectAllOnFocus(_priceFocusNode, _priceController);
    _selectAllOnFocus(_sellingPriceFocusNode, _sellingPriceController);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  /// Selects the field's whole current value as soon as it gains focus, so
  /// tapping in (e.g. to overwrite a default quantity/price) doesn't
  /// require manually clearing the old value first.
  void _selectAllOnFocus(FocusNode node, TextEditingController controller) {
    node.addListener(() {
      if (node.hasFocus) {
        controller.selection =
            TextSelection(baseOffset: 0, extentOffset: controller.text.length);
      }
    });
  }

  Future<void> _init() async {
    await context.read<CategoryProvider>().loadCategories();
    if (!mounted) return;

    if (_isEditing) {
      final product = await context.read<ProductProvider>().getProduct(widget.productId!);
      if (!mounted) return;
      if (product != null) {
        _existingProduct = product;
        _pendingSku = product.sku;
        _nameController.text = product.name;
        _skuController.text = product.sku;
        _barcodeController.text = product.barcode ?? '';
        _quantityController.text = product.quantity.toString();
        _priceController.text = product.unitPrice.toStringAsFixed(2);
        _sellingPriceController.text = product.sellingPrice.toStringAsFixed(2);
        _selectedCategoryId = product.categoryId;
        _photoPath = product.photoPath;
      }
    } else {
      _pendingSku = await context.read<ProductProvider>().getNextProductSku();
      if (!mounted) return;
      _skuController.text = _pendingSku;
    }

    final categories = context.read<CategoryProvider>().categories;
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _sellingPriceController.dispose();
    _nameFocusNode.dispose();
    _barcodeFocusNode.dispose();
    _quantityFocusNode.dispose();
    _priceFocusNode.dispose();
    _sellingPriceFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, maxWidth: 1024);
    if (image == null || !mounted) return;

    // Only staged for preview here — the old stored photo (if any) isn't
    // replaced/deleted until _save() actually commits, so backing out of
    // the form after picking leaves the existing photo untouched. Evict
    // first in case the picker reused a cached temp path from an earlier
    // capture this session (FileImage caches by path, not file contents).
    final newFile = File(image.path);
    await FileImage(newFile).evict();
    if (!mounted) return;
    setState(() => _pickedPhotoFile = newFile);
  }

  Future<void> _scanBarcode() async {
    final result = await context.push<String>('/scan/pick');
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _barcodeController.text = result);
    }
  }

  Future<void> _save() async {
    setState(() {
      _barcodeError = null;
      _nameError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final provider = context.read<ProductProvider>();

    final existingName = await provider.findByName(_nameController.text.trim());
    if (existingName != null && existingName.id != _existingProduct?.id) {
      setState(() => _nameError = 'A product with this name already exists');
      return;
    }
    if (!mounted) return;

    final barcode = _barcodeController.text.trim().isEmpty
        ? null
        : _barcodeController.text.trim();

    if (barcode != null) {
      final existing = await provider.findByBarcode(barcode);
      if (existing != null && existing.id != _existingProduct?.id) {
        setState(() => _barcodeError =
            'Already used by "${existing.name}"');
        return;
      }
    }
    if (!mounted) return;

    setState(() => _isSaving = true);

    // Only now — on an actual save — does a newly picked photo replace
    // (and delete) whatever was already stored for this SKU.
    var photoPath = _photoPath;
    if (_pickedPhotoFile != null) {
      photoPath = await ProductPhotoStore.save(
        source: _pickedPhotoFile!,
        sku: _pendingSku,
      );
      if (!mounted) return;
    }

    final product = Product(
      id: _existingProduct?.id,
      name: _nameController.text.trim(),
      // For a new product this is only a preview (see
      // DatabaseHelper.getNextProductSku) — the real insert re-derives and
      // overwrites it from the row's actual id, which is what's guaranteed
      // unique. When editing, it just carries the existing SKU back
      // unchanged.
      sku: _pendingSku,
      barcode: barcode,
      categoryId: _selectedCategoryId!,
      quantity: int.parse(_quantityController.text),
      unitPrice: double.parse(_priceController.text),
      sellingPrice: double.parse(_sellingPriceController.text),
      photoPath: photoPath,
      createdAt: _existingProduct?.createdAt ?? DateTime.now().toIso8601String(),
    );

    try {
      if (_isEditing) {
        await provider.updateProduct(product);
      } else {
        await provider.addProduct(product);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not save product: barcode may already be in use.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final categories = context.watch<CategoryProvider>().categories;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  backgroundImage: _pickedPhotoFile != null
                      ? FileImage(_pickedPhotoFile!)
                      : (_photoPath != null && File(_photoPath!).existsSync()
                          ? FileImage(File(_photoPath!))
                          : null),
                  child: _pickedPhotoFile == null && _photoPath == null
                      ? const Icon(Icons.add_a_photo_outlined, size: 32)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                labelText: 'Name',
                border: const OutlineInputBorder(),
                errorText: _nameError,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _skuController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'SKU',
                border: OutlineInputBorder(),
                helperText: 'Auto-generated, unique per product',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              onChanged: (_) {
                if (_barcodeError != null) setState(() => _barcodeError = null);
              },
              decoration: InputDecoration(
                labelText: 'Barcode (optional)',
                border: const OutlineInputBorder(),
                errorText: _barcodeError,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan barcode',
                  onPressed: _scanBarcode,
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: categories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategoryId = value),
              validator: (v) => v == null ? 'Category is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              focusNode: _quantityFocusNode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0) return 'Enter a valid quantity';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              focusNode: _priceFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Unit Price', border: OutlineInputBorder()),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sellingPriceController,
              focusNode: _sellingPriceFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Selling Price', border: OutlineInputBorder()),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Add Product'),
            ),
          ],
        ),
      ),
    );
  }
}
