import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RpsCcuTool extends StatefulWidget {
  const RpsCcuTool({super.key});

  @override
  State<RpsCcuTool> createState() => _RpsCcuToolState();
}

class _RpsCcuToolState extends State<RpsCcuTool> {
  // Input Controllers
  final TextEditingController _totalUsersController =
      TextEditingController(text: "3000000");
  final TextEditingController _requestsPerUserController =
      TextEditingController(text: "10");
  final TextEditingController _safetyMultiplierController =
      TextEditingController(text: "2");
  final TextEditingController _avgResponseTimeController =
      TextEditingController(text: "10");

  // Sliders State
  double _activeUserPct = 10.0;
  double _trafficPct = 80.0;
  double _timePct = 20.0;

  // Output variables
  double _dau = 0.0;
  double _dailyReq = 0.0;
  double _avgRPS = 0.0;
  double _peakRPS = 0.0;
  double _designRPS = 0.0;
  double _avgCCU = 0.0;
  double _peakCCU = 0.0;
  double _designCCU = 0.0;

  // Formula strings
  String _expDAU = "";
  String _expTotalReq = "";
  String _expAvgRPS = "";
  String _expPeakRPS = "";
  String _expCCU = "";

  // Generated K6 script
  String _k6Code = "";

  @override
  void initState() {
    super.initState();
    _calculate();

    // Listeners for controllers
    _totalUsersController.addListener(_calculate);
    _requestsPerUserController.addListener(_calculate);
    _safetyMultiplierController.addListener(_calculate);
    _avgResponseTimeController.addListener(_calculate);
  }

  @override
  void dispose() {
    _totalUsersController.dispose();
    _requestsPerUserController.dispose();
    _safetyMultiplierController.dispose();
    _avgResponseTimeController.dispose();
    super.dispose();
  }

  String _formatNumber(double num) {
    int val = num.round();
    bool isNegative = val < 0;
    String str = val.abs().toString();

    StringBuffer sb = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        sb.write('.');
      }
      sb.write(str[i]);
      count++;
    }
    String formatted = sb.toString().split('').reversed.join('');
    return isNegative ? '-$formatted' : formatted;
  }

  void _calculate() {
    final double totalUsers =
        double.tryParse(_totalUsersController.text.trim()) ?? 0.0;
    final double requestsPerUser =
        double.tryParse(_requestsPerUserController.text.trim()) ?? 0.0;
    final double safetyMult =
        double.tryParse(_safetyMultiplierController.text.trim()) ?? 0.0;
    final double avgTime =
        double.tryParse(_avgResponseTimeController.text.trim()) ?? 0.0;

    // Calculations
    final double dau = totalUsers * (_activeUserPct / 100.0);
    final double dailyReq = dau * requestsPerUser;
    const double secondsInDay = 86400.0;

    final double avgRPS = dailyReq / secondsInDay;
    final double peakRPS = (dailyReq * (_trafficPct / 100.0)) /
        (secondsInDay * (_timePct / 100.0));
    final double designRPS = peakRPS * safetyMult;

    final double avgCCU = avgRPS * avgTime;
    final double peakCCU = peakRPS * avgTime;
    final double designCCU = designRPS * avgTime;

    // Generate formula texts
    final String activeUserPctStr = _activeUserPct.round().toString();
    final String trafficPctStr = _trafficPct.round().toString();
    final String timePctStr = _timePct.round().toString();

    setState(() {
      _dau = dau;
      _dailyReq = dailyReq;
      _avgRPS = avgRPS;
      _peakRPS = peakRPS;
      _designRPS = designRPS;
      _avgCCU = avgCCU;
      _peakCCU = peakCCU;
      _designCCU = designCCU;

      _expDAU =
          "DAU = ${_formatNumber(totalUsers)} × $activeUserPctStr% = ${_formatNumber(dau)} users";
      _expTotalReq =
          "Tổng Req = ${_formatNumber(dau)} × ${requestsPerUser.round()} = ${_formatNumber(dailyReq)} requests/ngày";
      _expAvgRPS =
          "Avg RPS = ${_formatNumber(dailyReq)} / 86.400 = ${_formatNumber(avgRPS)} req/s";
      _expPeakRPS =
          "Peak RPS = (${_formatNumber(dailyReq)} × $trafficPctStr%) / (86.400 × $timePctStr%) = ${_formatNumber(peakRPS)} req/s";
      _expCCU =
          "Peak CCU = ${_formatNumber(peakRPS)} (Peak RPS) × ${avgTime.round()}s = ${_formatNumber(peakCCU)} kết nối";

      // K6 Script Generation
      final int avgInt = avgRPS.round();
      final int peakInt = peakRPS.round();
      final int designInt = designRPS.round();
      final int spikeInt = (designRPS * 1.5).round();

      _k6Code =
          "// Gán các stages tương ứng vào config executor 'ramping-arrival-rate'\n\n"
          "const testScenarios = {\n"
          "  // ==================================================================================\n"
          "  // 1. LOAD TEST: Mục tiêu $peakInt RPS (Peak RPS)\n"
          "  // - Mục tiêu: Kiểm tra khả năng xử lý của hệ thống ở mức tải dự kiến trong thực tế (Expected Production Load).\n"
          "  //   Đánh giá Response Time, Throughput, Error Rate và mức sử dụng CPU, RAM, Database, Network khi hệ thống hoạt động bình thường.\n"
          "  // - Cách thức thực hiện: Mô phỏng số lượng người dùng hoặc số lượng request tương đương với tải thực tế\n"
          "  //   và duy trì ổn định trong một khoảng thời gian để hệ thống đạt trạng thái ổn định (Steady State).\n"
          "  // - Thời gian thực hiện: Ngắn - Trung bình: Thường từ 15 phút đến 2 giờ. Thời gian chạy cần đủ để các\n"
          "  //   chỉ số hiệu năng ổn định và phản ánh đúng khả năng xử lý của hệ thống.\n"
          "  // ==================================================================================\n"
          "  load: {\n"
          "    executor: 'ramping-arrival-rate',\n"
          "    startRate: ${avgInt ~/ 2 > 0 ? avgInt ~/ 2 : 1},\n"
          "    timeUnit: '1s',\n"
          "    preAllocatedVUs: 50,\n"
          "    maxVUs: ${peakCCU.round() + 100},\n"
          "    stages: [\n"
          "      { target: $peakInt, duration: '2m' },   // Ramp-up\n"
          "      { target: $peakInt, duration: '15m' },  // Hold: Phản ánh khả năng xử lý thực tế\n"
          "      { target: 0, duration: '2m' },            // Ramp-down\n"
          "    ],\n"
          "  },\n\n"
          "  // ==================================================================================\n"
          "  // 2. STRESS TEST: Mục tiêu $designInt RPS (Design RPS)\n"
          "  // - Mục tiêu: Xác định giới hạn chịu tải (Breaking Point) của hệ thống khi tải vượt quá mức thiết kế.\n"
          "  //   Đánh giá khả năng suy giảm hiệu năng, xử lý lỗi và khả năng phục hồi (Recovery) sau khi giảm tải.\n"
          "  // - Cách thức thực hiện: Tăng tải dần từng bước vượt mức tải dự kiến cho đến khi hệ thống bắt đầu\n"
          "  //   xuất hiện lỗi hoặc không thể phục vụ thêm request. Sau đó giảm tải để đánh giá khả năng phục hồi.\n"
          "  // - Thời gian thực hiện: Trung bình: Phụ thuộc vào tốc độ tăng tải. Thường từ 30 phút đến vài giờ.\n"
          "  //   Quan trọng là tăng tải đủ chậm để xác định chính xác thời điểm hệ thống bắt đầu suy giảm hiệu năng.\n"
          "  // ==================================================================================\n"
          "  stress: {\n"
          "    executor: 'ramping-arrival-rate',\n"
          "    startRate: ${avgInt > 0 ? avgInt : 1},\n"
          "    timeUnit: '1s',\n"
          "    preAllocatedVUs: 100,\n"
          "    maxVUs: ${designCCU.round() + 200},\n"
          "    stages: [\n"
          "      { target: $peakInt, duration: '2m' },   // Lên mức tải thiết kế\n"
          "      { target: $peakInt, duration: '3m' },   // Giữ ổn định lấy mốc\n"
          "      { target: $designInt, duration: '10m' }, // Tăng dần vượt mức thiết kế tìm giới hạn\n"
          "      { target: $designInt, duration: '5m' }, // Ép tải tối đa để quan sát lỗi\n"
          "      { target: 0, duration: '2m' },            // Giảm tải đánh giá khả năng phục hồi\n"
          "    ],\n"
          "  },\n\n"
          "  // ==================================================================================\n"
          "  // 3. SPIKE TEST: Mục tiêu $spikeInt RPS (1.5x Design RPS)\n"
          "  // - Mục tiêu: Kiểm tra khả năng phản ứng của hệ thống khi lưu lượng truy cập tăng hoặc giảm\n"
          "  //   đột ngột trong thời gian rất ngắn, mô phỏng các sự kiện như Flash Sale, Black Friday,\n"
          "  //   Push Notification hoặc Viral Traffic.\n"
          "  // - Cách thức thực hiện: Tăng tải gần như tức thời lên mức rất cao, giữ trong thời gian ngắn\n"
          "  //   rồi giảm nhanh về mức bình thường. Quan sát khả năng xử lý, Auto Scaling, Queue, Cache,\n"
          "  //   Connection Pool và Recovery của hệ thống.\n"
          "  // - Thời gian thực hiện: Rất ngắn: Thường chỉ vài phút với nhiều đợt tăng giảm tải đột ngột.\n"
          "  // ==================================================================================\n"
          "  spike: {\n"
          "    executor: 'ramping-arrival-rate',\n"
          "    startRate: ${avgInt > 0 ? avgInt : 1},\n"
          "    timeUnit: '1s',\n"
          "    preAllocatedVUs: 200,\n"
          "    maxVUs: ${(designCCU * 1.5).round() + 300},\n"
          "    stages: [\n"
          "      { target: ${avgInt > 0 ? avgInt : 1}, duration: '1m' },\n"
          "      { target: $spikeInt, duration: '10s' }, // Tăng gần như tức thời\n"
          "      { target: $spikeInt, duration: '1m' },  // Giữ trong thời gian ngắn\n"
          "      { target: ${avgInt > 0 ? avgInt : 1}, duration: '10s' },    // Giảm nhanh về mức bình thường\n"
          "      { target: 0, duration: '30s' },\n"
          "    ],\n"
          "  }\n"
          "};";
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _k6Code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Đã copy kịch bản k6 vào Clipboard!"),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2C3E50),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? prefixText,
    String? suffixText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefixText,
          suffixText: suffixText,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String suffix = "%",
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              "${value.round()}$suffix",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: (val) {
            onChanged(val);
            _calculate();
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildResultCard({
    required String title,
    required String value,
    Color? titleColor,
    Color? valueColor,
    Color? bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: titleColor ?? Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowResult({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
    Color? bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isBold ? Colors.grey.shade800 : Colors.grey.shade600,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaCard(String title, String formula, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectionArea(
              child: Text(
                formula,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 900;

    final Widget inputPanel = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("1. Thông số đầu vào"),
          _buildInputField(
            label: "Tổng số Users",
            controller: _totalUsersController,
          ),
          _buildSliderField(
            label: "% User Active Hàng Ngày",
            value: _activeUserPct,
            min: 1,
            max: 100,
            onChanged: (val) => setState(() => _activeUserPct = val),
          ),
          _buildInputField(
            label: "Số Request / User / Ngày",
            controller: _requestsPerUserController,
          ),
          _buildSliderField(
            label: "Quy tắc Peak Traffic (% tải)",
            value: _trafficPct,
            min: 1,
            max: 100,
            onChanged: (val) => setState(() => _trafficPct = val),
          ),
          _buildSliderField(
            label: "Quy tắc Peak Time (% thời gian)",
            value: _timePct,
            min: 1,
            max: 100,
            onChanged: (val) => setState(() => _timePct = val),
          ),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: "Hệ số an toàn (Safety)",
                  controller: _safetyMultiplierController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  label: "Avg Response Time (giây)",
                  controller: _avgResponseTimeController,
                  suffixText: "s",
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("2. Giải thích logic & Công thức tính"),
          _buildFormulaCard(
            "Lượng người dùng thực tế (DAU)",
            _expDAU,
            Colors.blue.shade700,
          ),
          _buildFormulaCard(
            "Tổng lượng Request hàng ngày",
            _expTotalReq,
            Colors.blue.shade700,
          ),
          _buildFormulaCard(
            "Average RPS (Tải trung bình)",
            _expAvgRPS,
            Colors.blue.shade700,
          ),
          _buildFormulaCard(
            "Peak RPS (Tải cao điểm)",
            _expPeakRPS,
            Colors.orange.shade700,
          ),
          _buildFormulaCard(
            "Định luật Little (Tính CCU)",
            _expCCU,
            Colors.red.shade700,
          ),
        ],
      ),
    );

    final Widget outputPanel = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Kết quả dự kiến",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: [
                    _buildResultCard(
                      title: "Daily Active Users (DAU)",
                      value: _formatNumber(_dau),
                    ),
                    _buildResultCard(
                      title: "Tổng Request / Ngày",
                      value: _formatNumber(_dailyReq),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRowResult(
                  label: "Average RPS:",
                  value: "${_formatNumber(_avgRPS)} req/s",
                ),
                _buildRowResult(
                  label: "Peak RPS:",
                  value: "${_formatNumber(_peakRPS)} req/s",
                  valueColor: Colors.orange.shade800,
                ),
                _buildRowResult(
                  label: "Design RPS (x Safety):",
                  value: "${_formatNumber(_designRPS)} req/s",
                  valueColor: Colors.red.shade700,
                ),
                _buildRowResult(
                  label: "Average CCU:",
                  value: _formatNumber(_avgCCU),
                ),
                _buildRowResult(
                  label: "Peak CCU:",
                  value: _formatNumber(_peakCCU),
                  valueColor: Colors.orange.shade800,
                ),
                _buildRowResult(
                  label: "Design CCU (Mục tiêu):",
                  value: _formatNumber(_designCCU),
                  valueColor: Colors.red.shade800,
                  isBold: true,
                  bgColor: Colors.blue.shade100.withOpacity(0.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader("3. Kịch bản k6 Tự động"),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "k6_script.js",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.white70),
                        tooltip: "Copy Kịch bản",
                        onPressed: _copyToClipboard,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 400),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SelectionArea(
                        child: Text(
                          _k6Code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Capacity Planning & k6 Generator"),
        elevation: 1,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: inputPanel),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: outputPanel),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    inputPanel,
                    const Divider(height: 1, thickness: 1),
                    outputPanel,
                  ],
                ),
              ),
      ),
    );
  }
}
