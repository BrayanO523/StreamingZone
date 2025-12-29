import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:typed_data';

class ImageSelectorDialog extends StatefulWidget {
  final String initialUrl;

  const ImageSelectorDialog({super.key, this.initialUrl = ''});

  @override
  State<ImageSelectorDialog> createState() => _ImageSelectorDialogState();
}

class _ImageSelectorDialogState extends State<ImageSelectorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  // Gallery Logic
  List<String> _galleryImages = [];
  bool _isLoadingGallery = true;
  String? _selectedGalleryUrl;

  // Upload Logic
  Uint8List? _uploadedBytes;
  String? _uploadedFileName;
  bool _isCompressing = false;
  String? _compressionStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialUrl.isNotEmpty) {
      _selectedGalleryUrl = widget.initialUrl;
    }
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    try {
      // List images from both 'products' and 'combos' folders
      // Better approach for "Gallery": Query Firestore for all unique imageUrls used in products/combos.
      final productDocs = await FirebaseFirestore.instance
          .collection('products')
          .get();
      final comboDocs = await FirebaseFirestore.instance
          .collection('combos')
          .get();

      final Set<String> uniqueUrls = {};

      for (var doc in productDocs.docs) {
        final url = doc.data()['imageUrl'] as String?;
        if (url != null && url.isNotEmpty) uniqueUrls.add(url);
      }
      for (var doc in comboDocs.docs) {
        final url = doc.data()['imageUrl'] as String?;
        if (url != null && url.isNotEmpty) uniqueUrls.add(url);
      }

      setState(() {
        _galleryImages = uniqueUrls.toList();
        _isLoadingGallery = false;
      });
    } catch (e) {
      print('Error loading gallery: $e');
      setState(() => _isLoadingGallery = false);
    }
  }

  Future<void> _pickAndCompressImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null) return;

      setState(() {
        _isCompressing = true;
        _compressionStatus = "Comprimiendo...";
      });

      final Uint8List rawBytes = await pickedFile.readAsBytes();
      final int sizeInBytes = rawBytes.lengthInBytes;
      final double sizeInMb = sizeInBytes / (1024 * 1024);

      print("Original Size: ${sizeInMb.toStringAsFixed(2)} MB");

      Uint8List? compressedBytes = rawBytes;

      if (sizeInMb > 2.0) {
        // Compress if larger than 2MB
        int quality = 85;
        if (sizeInMb > 5) quality = 70;
        if (sizeInMb > 10) quality = 50;

        _compressionStatus = "Comprimiendo (Calidad $quality%)...";

        compressedBytes = await FlutterImageCompress.compressWithList(
          rawBytes,
          minHeight: 1080,
          minWidth: 1080,
          quality: quality,
        );
      }

      final double newSizeInMb = compressedBytes.lengthInBytes / (1024 * 1024);
      print("New Size: ${newSizeInMb.toStringAsFixed(2)} MB");

      setState(() {
        _uploadedBytes = compressedBytes;
        _uploadedFileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        _isCompressing = false;
        _compressionStatus = null;
        // Clear gallery selection if upload is chosen
        _selectedGalleryUrl = null;
      });
    } catch (e) {
      print("Error compressing: $e");
      setState(() {
        _isCompressing = false;
        _compressionStatus = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen size to avoid overflow
    final size = MediaQuery.of(context).size;
    final dialogHeight = size.height * 0.7; // Use 70% of screen height
    final dialogWidth = size.width > 600 ? 600.0 : size.width * 0.9;

    return AlertDialog(
      backgroundColor: const Color(0xFF1e293b),
      title: const Text(
        'Seleccionar Imagen',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight, // Dynamic height
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF6366f1),
              labelColor: const Color(0xFF6366f1),
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: "Galería Usada"),
                Tab(text: "Subir Nueva"),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildGalleryTab(), _buildUploadTab()],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366f1),
          ),
          onPressed: () {
            if (_tabController.index == 0) {
              // Gallery
              Navigator.pop(context, {
                'type': 'url',
                'data': _selectedGalleryUrl,
              });
            } else {
              // Upload
              if (_uploadedBytes != null) {
                Navigator.pop(context, {
                  'type': 'bytes',
                  'data': _uploadedBytes,
                  'name': _uploadedFileName,
                });
              }
            }
          },
          child: const Text(
            'Seleccionar',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryTab() {
    if (_isLoadingGallery) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_galleryImages.isEmpty) {
      return const Center(
        child: Text(
          "No hay imágenes en la galería",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _galleryImages.length,
      itemBuilder: (context, index) {
        final url = _galleryImages[index];
        final isSelected = _selectedGalleryUrl == url;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedGalleryUrl = url;
            // Clear upload selection
            _uploadedBytes = null;
          }),
          child: Container(
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(color: const Color(0xFF6366f1), width: 3)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _pickAndCompressImage,
            child: Container(
              height: 250,
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: _uploadedBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_uploadedBytes!, fit: BoxFit.contain),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_upload,
                          size: 50,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isCompressing
                              ? (_compressionStatus ?? "Procesando...")
                              : "Tocar para subir imagen",
                          style: const TextStyle(color: Colors.white54),
                        ),
                        if (_isCompressing) ...[
                          const SizedBox(height: 10),
                          const CircularProgressIndicator(),
                        ],
                      ],
                    ),
            ),
          ),
          if (_uploadedBytes != null)
            Text(
              "Imagen lista para usar (${(_uploadedBytes!.lengthInBytes / (1024 * 1024)).toStringAsFixed(2)} MB)",
              style: const TextStyle(color: Colors.greenAccent),
            ),
        ],
      ),
    );
  }
}
