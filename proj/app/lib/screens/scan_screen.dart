import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../db/local_db.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 250,
  );
  bool _hasScanned = false;
  bool _isTorchOn = false;
  List<String> _codeOptions = [];
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _loadCodeOptions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null && barcode.trim().isNotEmpty) {
      setState(() {
        _hasScanned = true;
      });
      // 触感反馈
      HapticFeedback.vibrate();
      Navigator.pop(context, barcode.trim());
    }
  }

  Future<void> _loadCodeOptions() async {
    final tools = await LocalDatabase.instance.getTools();
    final accessories = await LocalDatabase.instance.getAccessories();
    final codes = <String>{
      ...tools.map((item) => '${item['code']}'),
      ...accessories.map((item) => '${item['barcode']}'),
    }.where((code) => code.trim().isNotEmpty).toList()
      ..sort();

    if (mounted) {
      setState(() {
        _codeOptions = codes;
      });
    }
  }

  void _showManualInput(BuildContext context) {
    TextEditingController? inputController;
    String selectedCode = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF0088CC), width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF0088CC)),
            SizedBox(width: 8),
            Text('手动输入工具编码', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '如因刻码磨损无法识别，请输入或点选本地已同步编码：',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                final keyword = textEditingValue.text.trim().toLowerCase();
                final source = keyword.isEmpty
                    ? _codeOptions
                    : _codeOptions.where((code) => code.toLowerCase().contains(keyword)).toList();
                return source.take(12);
              },
              onSelected: (value) {
                selectedCode = value;
              },
              fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                inputController = textController;
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: '例如: TL-MT-056-K 或 ACC-RING-001',
                    hintStyle: TextStyle(color: Colors.white30),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF0088CC)),
                    ),
                  ),
                  autofocus: true,
                  onChanged: (value) {
                    selectedCode = value;
                  },
                  onSubmitted: (_) => onFieldSubmitted(),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: const Color(0xFF182030),
                    elevation: 8,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            title: Text(option, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_codeOptions.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '本地暂无同步编码候选，可直接手工录入。',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final code = (inputController?.text ?? selectedCode).trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx); // 关闭 Dialog
                if (!_hasScanned) {
                  _hasScanned = true;
                  Navigator.pop(context, code); // 返回编码值
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0088CC),
              foregroundColor: Colors.white,
            ),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A43),
        title: const Text('智能识别扫码', style: TextStyle(fontSize: 16, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.amber : Colors.white54,
            ),
            onPressed: () {
              controller.toggleTorch();
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 摄像头预览层
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          // 覆盖框及雷达扫描特效 Overlay
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                painter: ScanOverlayPainter(scanPosition: _animation.value),
                child: Container(),
              );
            },
          ),
          // 顶部指引文字
          const Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Text(
              '请将物理刻码或配件条形码放入框内',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      // 底部操作区：手动输入编码
      bottomNavigationBar: Container(
        color: const Color(0xFF102A43),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '无法识别？',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              ElevatedButton.icon(
                onPressed: () => _showManualInput(context),
                icon: const Icon(Icons.keyboard, size: 16),
                label: const Text('手动录入编码'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF243B53),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScanOverlayPainter extends CustomPainter {
  final double scanPosition;

  ScanOverlayPainter({required this.scanPosition});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 扫描框的边长
    final boxSize = width * 0.7;
    final left = (width - boxSize) / 2;
    final top = (height - boxSize) / 2 - 40; // 稍微偏上一些以视觉平衡
    final right = left + boxSize;
    final bottom = top + boxSize;

    final rect = Rect.fromLTRB(left, top, right, bottom);

    // 绘制半透明蒙版
    final paintMask = Paint()..color = Colors.black.withValues(alpha: 0.65);
    // 扣除扫描框区域
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, width, height)),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12))),
      ),
      paintMask,
    );

    // 绘制框的四个角 (三防工业质感蓝色边角)
    final paintCorner = Paint()
      ..color = const Color(0xFF0088CC)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;
    const radius = 12.0;

    // 左上角
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top + radius)
        ..quadraticBezierTo(left, top, left + radius, top)
        ..lineTo(left + cornerLength, top),
      paintCorner,
    );

    // 右上角
    canvas.drawPath(
      Path()
        ..moveTo(right - cornerLength, top)
        ..lineTo(right - radius, top)
        ..quadraticBezierTo(right, top, right, top + radius)
        ..lineTo(right, top + cornerLength),
      paintCorner,
    );

    // 左下角
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - cornerLength)
        ..lineTo(left, bottom - radius)
        ..quadraticBezierTo(left, bottom, left + radius, bottom)
        ..lineTo(left + cornerLength, bottom),
      paintCorner,
    );

    // 右下角
    canvas.drawPath(
      Path()
        ..moveTo(right - cornerLength, bottom)
        ..lineTo(right - radius, bottom)
        ..quadraticBezierTo(right, bottom, right, bottom - radius)
        ..lineTo(right, bottom - cornerLength),
      paintCorner,
    );

    // 绘制内部呼吸网状细框
    final paintBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), paintBorder);

    // 绘制扫描激光线 (动态上下移动)
    final scanY = top + (boxSize * scanPosition);
    final paintLine = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0088CC).withValues(alpha: 0.0),
          const Color(0xFF0088CC),
          const Color(0xFF0088CC).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(left, scanY - 2, right, scanY + 2))
      ..strokeWidth = 3;

    canvas.drawLine(Offset(left + 8, scanY), Offset(right - 8, scanY), paintLine);
  }

  @override
  bool shouldRepaint(covariant ScanOverlayPainter oldDelegate) {
    return oldDelegate.scanPosition != scanPosition;
  }
}
