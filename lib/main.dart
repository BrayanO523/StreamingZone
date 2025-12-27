import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es', null);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StreamZone Admin',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF6366f1),
        scaffoldBackgroundColor: const Color(0xFF0f172a),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1e293b),
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6366f1),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366f1),
          secondary: Color(0xFFa855f7),
          surface: Color(0xFF1e293b),
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class Product {
  String id;
  String name;
  String description;
  double price;
  String imageUrl;
  bool promo;
  String category;
  bool available;
  DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.promo = false,
    this.category = 'Video',
    this.available = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'promo': promo,
      'category': category,
      'available': available,
    };
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      promo: map['promo'] ?? false,
      category: map['category'] ?? 'Video',
      available: map['available'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const StatsView(),
    const FinancesView(),
    const InventoryView(),
    const OrdersView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StreamZone Admin'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign), // Megaphone for announcements
            onPressed: () => _showBannerConfig(context),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF6366f1),
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1e293b),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Resumen',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Finanzas',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Inventario'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Pedidos',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 2
          ? FloatingActionButton(
              onPressed: () => _showProductDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showProductDialog(BuildContext context, {Product? product}) {
    showDialog(
      context: context,
      builder: (context) => ProductDialog(product: product),
    );
  }

  void _showBannerConfig(BuildContext context) {
    showDialog(context: context, builder: (context) => const BannerDialog());
  }
}

class InventoryView extends StatelessWidget {
  const InventoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.requireData;
        if (data.size == 0) {
          return const Center(
            child: Text(
              'No hay productos.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: data.size,
          itemBuilder: (context, index) {
            final doc = data.docs[index];
            final product = Product.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            );
            return ProductCard(product: product);
          },
        );
      },
    );
  }
}

class StatsView extends StatelessWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Resumen del Negocio',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Products Count
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final docs = snapshot.data!.docs;
              final total = docs.length;
              final unavailable = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return (data['available'] ?? true) == false;
              }).length;

              return Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Productos Totales',
                      value: total.toString(),
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Agotados',
                      value: unavailable.toString(),
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Orders Count
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final totalOrders = snapshot.data!.size;
              return _StatCard(
                title: 'Pedidos Recibidos',
                value: totalOrders.toString(),
                color: Colors.green,
              );
            },
          ),
          const SizedBox(height: 30),
          const Text(
            'Accesos Directos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.white10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: const Icon(Icons.star, color: Colors.yellow),
            title: const Text('Ver Opiniones (Web)'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap:
                () {}, // Could link to webview or internal opinion view later
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class OrdersView extends StatefulWidget {
  const OrdersView({super.key});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  int _currentPage = 0;
  static const int _perPage = 30;
  final List<DocumentSnapshot> _checkpoints = [];

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(_perPage);

    // Apply cursor if not on first page
    if (_currentPage > 0 && _checkpoints.length >= _currentPage) {
      query = query.startAfterDocument(_checkpoints[_currentPage - 1]);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (_currentPage == 0) {
            return const Center(
              child: Text(
                'No hay pedidos registrados',
                style: TextStyle(color: Colors.grey),
              ),
            );
          } else {
            // Handle case where next page is empty (shouldn't happen with disabled button, but safe fallback)
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No hay más pedidos.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  TextButton(onPressed: _prevPage, child: const Text("Volver")),
                ],
              ),
            );
          }
        }

        final docs = snapshot.data!.docs;
        final isLastPage = docs.length < _perPage;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final items = (data['items'] as List<dynamic>?) ?? [];
                  final total = data['total'] ?? 0.0;
                  final date = (data['createdAt'] as Timestamp?)?.toDate();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.white10,
                    child: ExpansionTile(
                      title: Text(
                        data['customerName'] ?? 'Cliente',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Total: HNL ${total.toStringAsFixed(2)} - ${date != null ? "${date.day}/${date.month} ${date.hour}:${date.minute}" : ""}',
                      ),
                      trailing: Chip(
                        label: Text(
                          (data['status'] ?? 'pending')
                              .toString()
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: _getStatusColor(data['status']),
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          color: Colors.black12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Teléfono: ${data['phone'] ?? 'N/A'}'),
                              const SizedBox(height: 8),
                              const Text(
                                'Productos:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ...items
                                  .map(
                                    (i) => Text(
                                      '- ${i['name']} (HNL ${i['price']})',
                                    ),
                                  )
                                  .toList(),
                              const SizedBox(height: 16),
                              const Text(
                                'Cambiar Estado:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _StatusButton(
                                    label: 'PENDIENTE',
                                    color: Colors.orange,
                                    isSelected:
                                        data['status'] == 'pending' ||
                                        data['status'] == null,
                                    onTap: () =>
                                        _updateStatus(doc.id, 'pending'),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusButton(
                                    label: 'COMPLETO',
                                    color: Colors.green,
                                    isSelected: data['status'] == 'completed',
                                    onTap: () =>
                                        _updateStatus(doc.id, 'completed'),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusButton(
                                    label: 'CANCELADO',
                                    color: Colors.red,
                                    isSelected: data['status'] == 'cancelled',
                                    onTap: () =>
                                        _updateStatus(doc.id, 'cancelled'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Pagination Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black26,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _currentPage > 0 ? _prevPage : null,
                  ),
                  Text('Página ${_currentPage + 1}'),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    // If we have less than _perPage, we are at the end.
                    // IMPORTANT: We need snapshot data here to know if we can go next.
                    // But we are inside the builder, so we have 'docs'.
                    onPressed: !isLastPage ? () => _nextPage(docs.last) : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _nextPage(DocumentSnapshot lastDoc) {
    if (_checkpoints.length == _currentPage) {
      _checkpoints.add(lastDoc);
    } else {
      // Should match
      _checkpoints[_currentPage] = lastDoc;
    }
    setState(() {
      _currentPage++;
    });
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'status': newStatus,
    });
  }
}

class FinancesView extends StatelessWidget {
  const FinancesView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // Calculate Total Revenue (only completed orders)
        double totalRevenue = 0;
        final now = DateTime.now();
        final List<double> weeklyData = List.filled(7, 0.0);

        // Map weekdays: (DateTime.weekday) 1=Mon .. 7=Sun
        // We want today to be the last bar.

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'completed') {
            final price = (data['total'] ?? 0.0).toDouble();
            totalRevenue += price;

            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            if (createdAt != null) {
              final diff = now.difference(createdAt).inDays;
              if (diff < 7 && diff >= 0) {
                // diff 0 = today (index 6)
                // diff 6 = 7 days ago (index 0)
                final index = 6 - diff;
                if (index >= 0 && index < 7) {
                  weeklyData[index] += price;
                }
              }
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatCard(
                title: 'Ingresos Totales (Completados)',
                value: 'HNL ${NumberFormat("#,##0.00").format(totalRevenue)}',
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 30),
              const Text(
                "Ingresos: Últimos 7 Días",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= 7)
                              return const SizedBox.shrink();
                            // Calculate label day
                            // index 6 is today, index 0 is 6 days ago
                            final day = now.subtract(Duration(days: 6 - index));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('E', 'es').format(
                                  day,
                                ), // Needs intl initialization or simple switch
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: weeklyData.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value,
                            color: const Color(0xFF6366f1),
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class BannerDialog extends StatefulWidget {
  const BannerDialog({super.key});

  @override
  State<BannerDialog> createState() => _BannerDialogState();
}

class _BannerDialogState extends State<BannerDialog> {
  final _textController = TextEditingController();
  bool _isActive = false;
  String _selectedColor = '#6366f1'; // Default Indigo

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('banner')
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _textController.text = data['text'] ?? '';
        _isActive = data['isActive'] ?? false;
        _selectedColor = data['color'] ?? '#6366f1';
      });
    }
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance.collection('config').doc('banner').set({
      'text': _textController.text,
      'isActive': _isActive,
      'color': _selectedColor,
    });
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Banner actualizado')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar Anuncio Web'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Mostrar Banner'),
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
          ),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(labelText: 'Texto del Anuncio'),
          ),
          const SizedBox(height: 20),
          const Text('Color de Fondo'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _colorBtn('#6366f1'), // Indigo
              _colorBtn('#ef4444'), // Red
              _colorBtn('#22c55e'), // Green
              _colorBtn('#eab308'), // Yellow
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  Widget _colorBtn(String color) {
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Color(int.parse(color.substring(1), radix: 16) + 0xFF000000),
          shape: BoxShape.circle,
          border: _selectedColor == color
              ? Border.all(color: Colors.white, width: 2)
              : null,
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: product.available ? null : Colors.white.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black26,
                image: product.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(product.imageUrl),
                        fit: BoxFit.cover,
                        colorFilter: product.available
                            ? null
                            : const ColorFilter.mode(
                                Colors.grey,
                                BlendMode.saturation,
                              ),
                      )
                    : null,
              ),
              child: product.imageUrl.isEmpty
                  ? const Icon(Icons.image_not_supported, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!product.available)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AGOTADO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            decoration: product.available
                                ? null
                                : TextDecoration.lineThrough,
                            color: product.available ? null : Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.promo) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.pink,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'OFERTA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'HNL ${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFa855f7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (product.createdAt != null)
                    Text(
                      'Ingreso: ${product.createdAt!.day}/${product.createdAt!.month}/${product.createdAt!.year}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ProductDialog(product: product),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(context, product),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Servicio'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${product.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(product.id)
                  .delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ProductDialog extends StatefulWidget {
  final Product? product;

  const ProductDialog({super.key, this.product});

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  // late TextEditingController _imageController; // Removed in favor of file picker
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String? _currentImageUrl;
  bool _isUploading = false;

  bool _isPromo = false;
  bool _isAvailable = true;
  String _selectedCategory = 'Video';

  final List<String> _categories = ['Video', 'Música', 'Juegos', 'VPN', 'Otro'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
    _currentImageUrl = widget.product?.imageUrl;
    _isPromo = widget.product?.promo ?? false;
    _isAvailable = widget.product?.available ?? true;
    _selectedCategory = widget.product?.category ?? 'Video';
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _currentImageUrl;
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child(
        'products/$fileName',
      );
      final UploadTask uploadTask = ref.putFile(_imageFile!);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.product == null ? 'Nuevo Servicio' : 'Editar Servicio',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Servicio',
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v!) == null ? 'Inválido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[600]!),
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : (_currentImageUrl != null &&
                              _currentImageUrl!.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(_currentImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child:
                      (_imageFile == null &&
                          (_currentImageUrl == null ||
                              _currentImageUrl!.isEmpty))
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Colors.grey,
                            ),
                            Text(
                              'Tocar para seleccionar imagen',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Disponible (Stock)'),
                value: _isAvailable,
                subtitle: Text(
                  _isAvailable
                      ? 'Visible para clientes'
                      : 'Marcado como AGOTADO',
                ),
                activeColor: Colors.green,
                onChanged: (v) => setState(() => _isAvailable = v),
              ),
              SwitchListTile(
                title: const Text('En Oferta'),
                value: _isPromo,
                onChanged: (v) => setState(() => _isPromo = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _saveProduct,
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);
    final String? imageUrl = await _uploadImage();

    if (imageUrl == null && _imageFile != null) {
      // Failed upload
      setState(() => _isUploading = false);
      return;
    }

    final data = {
      'name': _nameController.text,
      'description': _descController.text,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'imageUrl': imageUrl ?? '',
      'promo': _isPromo,
      'category': _selectedCategory,
      'available': _isAvailable,
      if (widget.product == null) 'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.product == null) {
        await FirebaseFirestore.instance.collection('products').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!.id)
            .update(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
