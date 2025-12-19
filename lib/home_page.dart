import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'main.dart';

void main() {
  runApp(const HomeTest());
}

class HomeTest extends StatelessWidget {
  const HomeTest({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản Lý Điện Nước',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        primaryColor: const Color(0xFF0F3460),
        cardColor: const Color(0xFF16213E),
      ),
      home: const HomePage(),
    );
  }
}

class ApartmentData {
  String name;
  double electricValue;
  double waterValue;
  double electricThreshold;
  double waterThreshold;
  String ownerName;
  String customerId;

  ApartmentData({
    required this.name,
    this.electricValue = 0,
    this.waterValue = 0,
    this.electricThreshold = 50,
    this.waterThreshold = 50,
    this.ownerName = 'Duy',
    this.customerId = 'KH001',
  });

  bool get isElectricAlert => electricValue > electricThreshold;
  bool get isWaterAlert => waterValue > waterThreshold;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  Socket? _socket;
  bool _isConnected = false;
  String _statusMessage = 'Chưa kết nối ESP32';
  final TextEditingController _ipController = TextEditingController(
    text: '192.168.4.1',
  );
  final TextEditingController _portController = TextEditingController(
    text: '12345',
  );

  List<ApartmentData> apartments = [];

  @override
  void dispose() {
    _socket?.close();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connectToESP32() async {
    try {
      setState(() {
        _statusMessage = 'Đang kết nối...';
      });

      final ip = _ipController.text.trim();
      final port = int.tryParse(_portController.text) ?? 12345;

      if (ip.isEmpty) {
        setState(() {
          _statusMessage = '❌ Vui lòng nhập IP Address';
        });
        return;
      }

      print('🔌 Connecting to $ip:$port...');

      _socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 10),
      );

      print('✅ Connected successfully!');

      setState(() {
        _isConnected = true;
        _statusMessage = '✅ Đã kết nối với ESP32';
      });

      _socket!.listen(
        (data) {
          final message = utf8.decode(data).trim();
          _handleReceivedData(message);
        },
        onDone: () {
          print('⚠️ Connection closed');
          setState(() {
            _isConnected = false;
            _statusMessage = '⚠️ Mất kết nối';
          });
        },
        onError: (error) {
          print('❌ Socket error: $error');
          setState(() {
            _isConnected = false;
            _statusMessage = '❌ Lỗi: $error';
          });
        },
      );
    } on SocketException catch (e) {
      print('❌ SocketException: $e');
      String errorMsg = '❌ ';

      if (e.osError?.errorCode == 1) {
        errorMsg +=
            'Không có quyền kết nối. Kiểm tra:\n'
            '1. Quyền INTERNET trong AndroidManifest.xml\n'
            '2. usesCleartextTraffic="true"\n'
            '3. Cùng mạng WiFi với ESP32';
      } else if (e.osError?.errorCode == 111) {
        errorMsg +=
            'ESP32 từ chối kết nối. Kiểm tra:\n'
            '1. ESP32 đã chạy TCP Server?\n'
            '2. Port đúng chưa? (12345)';
      } else if (e.osError?.errorCode == 113) {
        errorMsg +=
            'Không thể kết nối đến.\n'
            'ESP32 có đang bật không?';
      } else {
        errorMsg += 'Lỗi kết nối: ${e.message}';
      }

      setState(() {
        _isConnected = false;
        _statusMessage = errorMsg;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF16213E),
                title: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Lỗi kết nối'),
                  ],
                ),
                content: SingleChildScrollView(child: Text(errorMsg)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      print('❌ Unknown error: $e');
      setState(() {
        _isConnected = false;
        _statusMessage = '❌ Lỗi không xác định: $e';
      });
    }
  }

  void _handleReceivedData(String data) {
    final lines = data.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      try {
        final json = jsonDecode(line);
        final id = json['id'];
        final electricity = json['electricity'].toDouble();
        final water = json['water'].toDouble();
        final ownerName = json['owner'] ?? 'Chưa có tên';

        setState(() {
          final index = apartments.indexWhere((a) => a.customerId == id);
          if (index != -1) {
            apartments[index].electricValue = electricity;
            apartments[index].waterValue = water;
            if (json['owner'] != null) {
              apartments[index].ownerName = ownerName;
            }
            print(
              '📊 Updated ${apartments[index].name}: $electricity w, $water L',
            );
          } else {
            print('⚠️ Received unknown apartment ID: $id. Adding to list.');
            apartments.add(
              ApartmentData(
                name: 'Căn hộ ${apartments.length + 1}',
                electricValue: electricity,
                waterValue: water,
                customerId: id,
                ownerName: ownerName,
              ),
            );
          }
        });
      } catch (e) {
        print('⚠️ Lỗi parse JSON: $e - Data: $line');
      }
    }
  }

  void _addApartment() {
    final TextEditingController idController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF16213E),
            title: const Text('Thêm Căn Hộ Mới'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isConnected)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        '⚠️ Chưa kết nối ESP32',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'Mã ID căn hộ',
                      hintText: 'Ví dụ: A001',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên chủ hộ',
                      hintText: 'Ví dụ: Nguyễn Văn A',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (idController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập ID căn hộ')),
                    );
                    return;
                  }

                  if (nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập họ tên chủ hộ'),
                      ),
                    );
                    return;
                  }

                  final existingIndex = apartments.indexWhere(
                    (a) => a.customerId == idController.text,
                  );
                  if (existingIndex != -1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('ID ${idController.text} đã tồn tại!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() {
                    apartments.add(
                      ApartmentData(
                        name: 'Căn hộ ${apartments.length + 1}',
                        electricValue: 0,
                        waterValue: 0,
                        customerId: idController.text,
                        ownerName: nameController.text,
                      ),
                    );
                  });

                  //  CHỈ GỬI MÃ KHÁCH HÀNG CHO ESP32
                  if (_isConnected) {
                    final command = 'ADD:${idController.text}\n';
                    _socket!.write(command);
                    print('📤 Sent ADD command: ${idController.text}');
                    setState(() {
                      _statusMessage = 'Đã gửi lệnh ADD: ${idController.text}';
                    });
                  }

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Đã thêm căn hộ ${idController.text}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                ),
                child: const Text('Thêm'),
              ),
            ],
          ),
    );
  }

  void _deleteApartment(String customerId) {
    final index = apartments.indexWhere((a) => a.customerId == customerId);

    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Không tìm thấy căn hộ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final apartmentToDelete = apartments[index];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF16213E),
            title: const Text('Xác nhận xóa'),
            content: Text(
              'Bạn có chắc muốn xóa:\n${apartmentToDelete.name}\nID: ${apartmentToDelete.customerId}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    apartments.removeWhere((a) => a.customerId == customerId);
                  });

                  if (_isConnected) {
                    final command = 'DEL:$customerId\n';
                    _socket!.write(command);
                    print('📤 Sent DEL command: $customerId');
                  }

                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Đã xóa ${apartmentToDelete.name}'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );
  }

  void _disconnect() {
    _socket?.close();
    setState(() {
      _isConnected = false;
      _statusMessage = 'Đã ngắt kết nối';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QUẢN LÝ ĐIỆN NƯỚC',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F3460),
        actions: const [
          Icon(Icons.home),
          SizedBox(width: 8),
          Icon(Icons.water_drop),
          SizedBox(width: 16),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: const Color(0xFF16213E),
        selectedItemColor: Colors.pinkAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Thêm'),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment),
            label: 'Khu phố',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Thống kê',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildAddPage();
      case 1:
        return _buildOverviewPage();
      case 2:
        return _buildStatisticsPage();
      case 3:
        return _buildAccountPage();
      default:
        return _buildOverviewPage();
    }
  }

  Widget _buildAddPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            color: const Color(0xFF16213E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kết nối ESP32',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            labelText: 'IP Address',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          enabled: !_isConnected,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          enabled: !_isConnected,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConnected ? _disconnect : _connectToESP32,
                      icon: Icon(_isConnected ? Icons.link_off : Icons.link),
                      label: Text(_isConnected ? 'Ngắt kết nối' : 'Kết nối'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isConnected ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.check_circle : Icons.cancel,
                        color: _isConnected ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Icon(Icons.add_home, size: 80, color: Colors.pinkAccent),
          const SizedBox(height: 24),
          const Text(
            'Thêm Căn Hộ Mới',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Hiện có ${apartments.length} căn hộ',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _addApartment,
            icon: const Icon(Icons.add),
            label: const Text('Thêm Căn Hộ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPage() {
    if (apartments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apartment, size: 80, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'Chưa có căn hộ nào',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Thêm căn hộ từ tab "Thêm"',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: apartments.length,
      itemBuilder: (context, index) {
        return _buildApartmentCard(apartments[index], index);
      },
    );
  }

  Widget _buildStatisticsPage() {
    int totalAlerts =
        apartments.where((a) => a.isElectricAlert || a.isWaterAlert).length;
    double totalElectric = apartments.fold(
      0,
      (sum, a) => sum + a.electricValue,
    );
    double totalWater = apartments.fold(0, (sum, a) => sum + a.waterValue);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCard(
          'Tổng số căn hộ',
          apartments.length.toString(),
          Icons.apartment,
          Colors.blue,
        ),
        _buildStatCard(
          'Cảnh báo',
          totalAlerts.toString(),
          Icons.warning,
          Colors.orange,
        ),
        _buildStatCard(
          'Tổng điện',
          '${totalElectric.toStringAsFixed(0)} w',
          Icons.bolt,
          Colors.yellow,
        ),
        _buildStatCard(
          'Tổng nước',
          '${totalWater.toStringAsFixed(0)} L',
          Icons.water_drop,
          Colors.cyan,
        ),

        const SizedBox(height: 16),
        Card(
          color: const Color(0xFF16213E),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trạng thái ESP32',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.wifi : Icons.wifi_off,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(_statusMessage),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (totalAlerts > 0) ...[
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF16213E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Căn hộ có cảnh báo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...apartments
                      .where((a) => a.isElectricAlert || a.isWaterAlert)
                      .map(
                        (apt) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('${apt.name} - ${apt.ownerName}'),
                              ),
                              if (apt.isElectricAlert)
                                const Icon(
                                  Icons.bolt,
                                  color: Colors.yellow,
                                  size: 20,
                                ),
                              if (apt.isWaterAlert)
                                const Icon(
                                  Icons.water_drop,
                                  color: Colors.cyan,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF16213E),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundColor: Colors.pinkAccent,
          child: Icon(Icons.person, size: 60, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          'Quản Trị Viên',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'admin@quanlydiennuoc.vn',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 32),
        _buildAccountOption(Icons.settings, 'Cài đặt'),
        _buildAccountOption(Icons.notifications, 'Thông báo'),
        _buildAccountOption(Icons.help, 'Trợ giúp'),
        _buildAccountOption(
          Icons.logout,
          'Đăng xuất',
          isRed: true,
          onTap: () {
            _socket?.close();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MyApp()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountOption(
    IconData icon,
    String title, {
    bool isRed = false,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF16213E),
      child: ListTile(
        leading: Icon(icon, color: isRed ? Colors.red : Colors.pinkAccent),
        title: Text(title, style: TextStyle(color: isRed ? Colors.red : null)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap ?? () {},
      ),
    );
  }

  Widget _buildApartmentCard(ApartmentData apt, int index) {
    return Stack(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => ApartmentDetailPage(
                      apartment: apt,
                      onDelete: () {
                        _deleteApartment(apt.customerId);
                      },
                    ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF9DB4C0).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    (apt.isElectricAlert || apt.isWaterAlert)
                        ? Colors.orange.withValues(alpha: 0.5)
                        : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.bolt,
                      color: Colors.yellowAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Số điện: ${apt.electricValue.toStringAsFixed(0)}w',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.water_drop,
                      color: Colors.lightBlueAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Số nước: ${apt.waterValue.toStringAsFixed(0)}L',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Alert 1', style: TextStyle(fontSize: 10)),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.lightbulb,
                          color:
                              apt.isElectricAlert ? Colors.yellow : Colors.grey,
                          size: 28,
                        ),
                        if (apt.isElectricAlert)
                          const Text(
                            'CẢNH BÁO',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.yellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Alert 2', style: TextStyle(fontSize: 10)),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.lightbulb,
                          color: apt.isWaterAlert ? Colors.yellow : Colors.grey,
                          size: 28,
                        ),
                        if (apt.isWaterAlert)
                          const Text(
                            'CẢNH BÁO',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.yellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A9D8F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.home, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          apt.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ✅ NÚT XÓA Ở GÓC TRÊN PHẢI
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _deleteApartment(apt.customerId),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.delete, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ApartmentDetailPage extends StatelessWidget {
  final ApartmentData apartment;
  final VoidCallback? onDelete;

  const ApartmentDetailPage({
    super.key,
    required this.apartment,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(apartment.name),
        backgroundColor: const Color(0xFF0F3460),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      backgroundColor: const Color(0xFF16213E),
                      title: const Text('Xác nhận xóa'),
                      content: Text(
                        'Bạn có chắc muốn xóa:\n${apartment.name}\nID: ${apartment.customerId}?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Hủy'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                            onDelete?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF9DB4C0).withValues(alpha: 0.3),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Color(0xFF7DB9DE)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          apartment.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          apartment.ownerName,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.refresh, color: Colors.black87),
                ],
              ),
            ),
            if (apartment.isElectricAlert || apartment.isWaterAlert)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.orange),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        apartment.isElectricAlert && apartment.isWaterAlert
                            ? 'CẢNH BÁO: Cả điện và nước đều vượt ngưỡng!'
                            : apartment.isElectricAlert
                            ? 'CẢNH BÁO: Điện vượt ngưỡng ${apartment.electricThreshold}w!'
                            : 'CẢNH BÁO: Nước vượt ngưỡng ${apartment.waterThreshold}L!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      apartment.name,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Mã khách hàng: ${apartment.customerId}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      'Họ và tên chủ hộ:',
                      apartment.ownerName,
                      false,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'Số Điện',
                      '${apartment.electricValue.toStringAsFixed(2)} w',
                      apartment.isElectricAlert,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'Số nước',
                      '${apartment.waterValue.toStringAsFixed(0)} L',
                      apartment.isWaterAlert,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'Alarm 1 (Điện)',
                      apartment.isElectricAlert ? 'ON' : 'OFF',
                      apartment.isElectricAlert,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'Alarm 2 (Nước)',
                      apartment.isWaterAlert ? 'ON' : 'OFF',
                      apartment.isWaterAlert,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isAlert) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (isAlert) ...[
                const SizedBox(width: 8),
                const Icon(Icons.warning, color: Colors.orange, size: 16),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
