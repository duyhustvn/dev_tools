import 'dart:async'; // Required for Timer in TimestampTool
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dev_tools_pro_max/binary_tool.dart';
import 'package:dev_tools_pro_max/image_tool.dart';
import 'package:dev_tools_pro_max/rps_ccu_tool.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JSON UI',
      home: MultiToolScreen(),
    ),
  );
}

// --- MAIN SCREEN WITH NAVIGATION RAIL ---
class MultiToolScreen extends StatefulWidget {
  const MultiToolScreen({super.key});

  @override
  State<MultiToolScreen> createState() => _MultiToolScreenState();
}

class _MultiToolScreenState extends State<MultiToolScreen> {
  int _selectedIndex = 0;

  final List<Widget> _tools = [
    const JsonTool(),
    const Base64Tool(),
    const UrlTool(),
    const TimestampTool(),
    const JwtTool(),
    const Uint64CalcTool(),
    const BinaryTool(),
    const ImageTool(),
    const RpsCcuTool(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.data_object),
                label: Text('JSON'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.code),
                label: Text('Base64'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.link),
                label: Text('URL'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.access_time),
                label: Text('Time'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified_user),
                label: Text('JWT'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calculate),
                label: Text('Calculator'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.numbers),
                label: Text('Binary'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.image),
                label: Text('Image'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.speed),
                label: Text('RPS/CCU'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _tools),
          ),
        ],
      ),
    );
  }
}

// --- REUSABLE SPLIT PANE WIDGET ---
class SplitPane extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialRatio;

  const SplitPane({
    super.key,
    required this.left,
    required this.right,
    this.initialRatio = 0.5,
  });

  @override
  State<SplitPane> createState() => _SplitPaneState();
}

class _SplitPaneState extends State<SplitPane> {
  late double _ratio;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double leftWidth = totalWidth * _ratio;
        const double dividerWidth = 16.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: leftWidth, child: widget.left),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _ratio = (_ratio + (details.delta.dx / totalWidth)).clamp(
                      0.2,
                      0.8,
                    );
                  });
                },
                child: Container(
                  width: dividerWidth,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Container(
                      height: 40,
                      width: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: widget.right),
          ],
        );
      },
    );
  }
}

// --- TOOL 1: JSON PRETTIFIER & EDITOR ---
class JsonTool extends StatefulWidget {
  const JsonTool({super.key});

  @override
  State<JsonTool> createState() => _JsonToolState();
}

class _JsonToolState extends State<JsonTool> {
  late final JsonSyntaxTextController _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    String initialText = '{\n  "tool": "JSON Editor",\n  "status": "Active"\n}';
    _controller = JsonSyntaxTextController(text: initialText);
    _validateJson();
  }

  void _validateJson() {
    if (_controller.text.trim().isEmpty) {
      setState(() => _errorMessage = null);
      return;
    }
    try {
      jsonDecode(_controller.text);
      setState(() {
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Invalid JSON";
      });
    }
  }

  void _prettify() {
    if (_controller.text.trim().isEmpty) return;
    try {
      final dynamic decoded = jsonDecode(_controller.text);
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String prettyString = encoder.convert(decoded);
      setState(() {
        _controller.text = prettyString;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = "Cannot prettify invalid JSON");
    }
  }

  void _stringify() {
    if (_controller.text.trim().isEmpty) return;

    String text = _controller.text;
    bool inQuotes = false;
    bool escapeNext = false;
    StringBuffer sb = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      String char = text[i];

      // Bỏ qua khoảng trắng nếu không nằm trong dấu ngoặc kép
      if (!inQuotes) {
        if (char == ' ' || char == '\t' || char == '\n' || char == '\r') {
          continue;
        }
      }

      sb.write(char);

      // Xử lý logic đóng/mở ngoặc kép và ký tự escape (\)
      if (escapeNext) {
        escapeNext = false;
      } else if (char == '\\') {
        escapeNext = true;
      } else if (char == '"') {
        inQuotes = !inQuotes;
      }
    }

    setState(() {
      _controller.text = sb.toString();
      _validateJson(); // Kiểm tra lại JSON sau khi minify để cập nhật thông báo lỗi nếu có
    });
  }

  void _copyToClipboard() {
    if (_controller.text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("JSON copied to clipboard!"),
        duration: Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("JSON UI"),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: "Copy Result",
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.compress), // Minify/Stringify icon
            tooltip: "Stringify (Minify)",
            onPressed: _stringify,
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: "Prettify",
            onPressed: _prettify,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: InputPane(
        label: "JSON EDITOR",
        controller: _controller,
        errorText: _errorMessage,
        onChanged: (_) => _validateJson(),
      ),
    );
  }
}

// --- TOOL 2: BASE64 ENCODER/DECODER ---
class Base64Tool extends StatefulWidget {
  const Base64Tool({super.key});

  @override
  State<Base64Tool> createState() => _Base64ToolState();
}

class _Base64ToolState extends State<Base64Tool> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  bool _isEncodeMode = true;
  bool _isUrlSafe = true;

  void _process() {
    if (_inputController.text.isEmpty) {
      setState(() => _outputController.text = "");
      return;
    }

    if (_isEncodeMode) {
      try {
        final bytes = utf8.encode(_inputController.text);
        final result = _isUrlSafe
            ? base64Url.encode(bytes)
            : base64.encode(bytes);
        setState(() => _outputController.text = result);
      } catch (e) {
        setState(() => _outputController.text = "Error encoding: $e");
      }
    } else {
      try {
        String input = _inputController.text.trim();
        while (input.length % 4 != 0) {
          input += '=';
        }
        final bytes = _isUrlSafe
            ? base64Url.decode(input)
            : base64.decode(input);
        setState(() => _outputController.text = utf8.decode(bytes));
      } catch (e) {
        setState(
          () =>
              _outputController.text = "Error decoding: Invalid Base64 string",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Base64 Converter"),
        elevation: 1,
        actions: [
          Row(
            children: [
              const Text("URL Safe"),
              Switch(
                value: _isUrlSafe,
                onChanged: (val) {
                  setState(() {
                    _isUrlSafe = val;
                    _process();
                  });
                },
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<bool>(
                      value: _isEncodeMode,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.blue,
                      ),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_downward,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text("Encode"),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_upward,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text("Decode"),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _isEncodeMode = val;
                            _process();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SplitPane(
              left: InputPane(
                label: "INPUT",
                controller: _inputController,
                hintText: "Enter text to encode or Base64 to decode...",
                onChanged: (_) => _process(),
              ),
              right: InputPane(
                label: "OUTPUT",
                controller: _outputController,
                readOnly: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- TOOL 3: URL ENCODER/DECODER ---
class UrlTool extends StatefulWidget {
  const UrlTool({super.key});

  @override
  State<UrlTool> createState() => _UrlToolState();
}

class _UrlToolState extends State<UrlTool> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  bool _isEncodeMode = true;

  void _process() {
    if (_inputController.text.isEmpty) {
      setState(() => _outputController.text = "");
      return;
    }

    if (_isEncodeMode) {
      try {
        final result = Uri.encodeComponent(_inputController.text);
        setState(() => _outputController.text = result);
      } catch (e) {
        setState(() => _outputController.text = "Error encoding: $e");
      }
    } else {
      try {
        final result = Uri.decodeComponent(_inputController.text);
        setState(() => _outputController.text = result);
      } catch (e) {
        setState(() => _outputController.text = "Error decoding: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("URL Encoder/Decoder"), elevation: 1),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<bool>(
                      value: _isEncodeMode,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.blue,
                      ),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_downward,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text("Encode"),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_upward,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text("Decode"),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _isEncodeMode = val;
                            _process();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SplitPane(
              left: InputPane(
                label: "INPUT",
                controller: _inputController,
                hintText: "Enter URL or parameters...",
                onChanged: (_) => _process(),
              ),
              right: InputPane(
                label: "OUTPUT",
                controller: _outputController,
                readOnly: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- TOOL 4: TIMESTAMP CONVERTER ---
class TimestampTool extends StatefulWidget {
  const TimestampTool({super.key});

  @override
  State<TimestampTool> createState() => _TimestampToolState();
}

class _TimestampToolState extends State<TimestampTool> {
  final TextEditingController _tsController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _minuteController = TextEditingController();
  final TextEditingController _secondController = TextEditingController();
  String _result = "";
  String _dateResult = "";
  int _selectedTimezoneOffset = 7;
  Timer? _timer;
  static const List<int> _timezoneOffsets = [
    -12,
    -11,
    -10,
    -9,
    -8,
    -7,
    -6,
    -5,
    -4,
    -3,
    -2,
    -1,
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
  ];

  String _formatTimezoneLabel(int offset) {
    return offset >= 0 ? "GMT+$offset" : "GMT$offset";
  }

  String _formatInTimezone(DateTime dt, int offset) {
    final shifted = dt.toUtc().add(Duration(hours: offset));
    return "${shifted.year}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')} "
        "${shifted.hour.toString().padLeft(2, '0')}:${shifted.minute.toString().padLeft(2, '0')}:${shifted.second.toString().padLeft(2, '0')}";
  }

  void _setDateFields(DateTime dt) {
    final shifted = dt.toUtc().add(Duration(hours: _selectedTimezoneOffset));
    _yearController.text = shifted.year.toString();
    _monthController.text = shifted.month.toString().padLeft(2, '0');
    _dayController.text = shifted.day.toString().padLeft(2, '0');
    _hourController.text = shifted.hour.toString().padLeft(2, '0');
    _minuteController.text = shifted.minute.toString().padLeft(2, '0');
    _secondController.text = shifted.second.toString().padLeft(2, '0');
  }

  @override
  void initState() {
    super.initState();
    _tsController.text = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    _setDateFields(DateTime.now());
    _convert();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tsController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _convert() {
    final text = _tsController.text.trim();
    if (text.isEmpty) {
      setState(() => _result = "");
      return;
    }

    try {
      int ts = int.parse(text);
      bool isMillis = text.length > 11;

      final dt = isMillis
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      final timezoneLabel = _formatTimezoneLabel(_selectedTimezoneOffset);

      setState(() {
        _result =
            "$timezoneLabel: ${_formatInTimezone(dt, _selectedTimezoneOffset)}\nUTC:   ${dt.toUtc()}";
      });
    } catch (e) {
      setState(() => _result = "Invalid timestamp");
    }
  }

  void _convertDateTimeToUnix() {
    try {
      final year = int.parse(_yearController.text.trim());
      final month = int.parse(_monthController.text.trim());
      final day = int.parse(_dayController.text.trim());
      final hour = int.parse(_hourController.text.trim());
      final minute = int.parse(_minuteController.text.trim());
      final second = int.parse(_secondController.text.trim());

      final localDate = DateTime.utc(year, month, day, hour, minute, second);
      final isValidDate =
          localDate.year == year &&
          localDate.month == month &&
          localDate.day == day &&
          localDate.hour == hour &&
          localDate.minute == minute &&
          localDate.second == second;

      if (!isValidDate) {
        throw const FormatException("Invalid date/time");
      }

      final utcDate = DateTime.utc(
        year,
        month,
        day,
        hour - _selectedTimezoneOffset,
        minute,
        second,
      );
      final seconds = utcDate.millisecondsSinceEpoch ~/ 1000;
      final milliseconds = utcDate.millisecondsSinceEpoch;
      final timezoneLabel = _formatTimezoneLabel(_selectedTimezoneOffset);

      setState(() {
        _dateResult =
            "Seconds: $seconds\n"
            "Milliseconds: $milliseconds\n"
            "$timezoneLabel: ${_formatInTimezone(utcDate, _selectedTimezoneOffset)}\n"
            "UTC: ${utcDate.toIso8601String()}";
      });
    } catch (e) {
      setState(() => _dateResult = "Invalid date/time");
    }
  }

  Widget _buildDateTimeField({
    required Key fieldKey,
    required String label,
    required TextEditingController controller,
    required int maxLength,
  }) {
    return SizedBox(
      width: 88,
      child: TextField(
        key: fieldKey,
        controller: controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          counterText: "",
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        keyboardType: TextInputType.number,
        onSubmitted: (_) => _convertDateTimeToUnix(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Unix Timestamp Converter"),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Current Time (${_formatTimezoneLabel(_selectedTimezoneOffset)})",
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatInTimezone(
                          DateTime.now(),
                          _selectedTimezoneOffset,
                        ),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        "${(DateTime.now().millisecondsSinceEpoch ~/ 1000)}",
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  "Convert Timestamp",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tsController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Unix Timestamp (Seconds or Milliseconds)",
                          labelText: "Timestamp",
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _convert(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _convert,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
                      child: const Text("Convert"),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (_result.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: SelectableText(
                      _result,
                      style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                const Text(
                  "Convert Date & Time",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    _buildDateTimeField(
                      fieldKey: const Key('date-year-field'),
                      label: "Year",
                      controller: _yearController,
                      maxLength: 4,
                    ),
                    _buildDateTimeField(
                      fieldKey: const Key('date-month-field'),
                      label: "Month",
                      controller: _monthController,
                      maxLength: 2,
                    ),
                    _buildDateTimeField(
                      fieldKey: const Key('date-day-field'),
                      label: "Day",
                      controller: _dayController,
                      maxLength: 2,
                    ),
                    _buildDateTimeField(
                      fieldKey: const Key('date-hour-field'),
                      label: "Hour",
                      controller: _hourController,
                      maxLength: 2,
                    ),
                    _buildDateTimeField(
                      fieldKey: const Key('date-minute-field'),
                      label: "Minute",
                      controller: _minuteController,
                      maxLength: 2,
                    ),
                    _buildDateTimeField(
                      fieldKey: const Key('date-second-field'),
                      label: "Second",
                      controller: _secondController,
                      maxLength: 2,
                    ),
                    SizedBox(
                      width: 152,
                      child: DropdownButtonFormField<int>(
                        key: const Key('date-timezone-dropdown'),
                        initialValue: _selectedTimezoneOffset,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "Timezone",
                        ),
                        items: _timezoneOffsets
                            .map(
                              (offset) => DropdownMenuItem<int>(
                                value: offset,
                                child: Text(_formatTimezoneLabel(offset)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedTimezoneOffset = value);
                          _convert();
                          if (_dateResult.isNotEmpty) {
                            _convertDateTimeToUnix();
                          }
                        },
                      ),
                    ),
                    ElevatedButton(
                      key: const Key('date-to-unix-convert-button'),
                      onPressed: _convertDateTimeToUnix,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
                      child: const Text("Convert"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_dateResult.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _dateResult.startsWith("Invalid")
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _dateResult.startsWith("Invalid")
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: SelectableText(
                      _dateResult,
                      style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- TOOL 5: JWT DECODER & VERIFIER ---
class JwtTool extends StatefulWidget {
  const JwtTool({super.key});

  @override
  State<JwtTool> createState() => _JwtToolState();
}

class _JwtToolState extends State<JwtTool> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();
  late final JsonSyntaxTextController _headerController;
  late final JsonSyntaxTextController _payloadController;

  Map<String, dynamic>? _payloadMap;
  String? _error;
  bool? _isSignatureValid;
  String? _headerError;
  String? _payloadError;

  @override
  void initState() {
    super.initState();
    _headerController = JsonSyntaxTextController(text: '');
    _payloadController = JsonSyntaxTextController(text: '');
    _headerController.addListener(_onHeaderChanged);
    _payloadController.addListener(_onPayloadChanged);

    // Initial state with defaults
    _secretController.text = "your-256-bit-secret";
    _headerController.text = '{\n  "alg": "HS256",\n  "typ": "JWT"\n}';
    _payloadController.text = '{\n  "sub": "1234567890",\n  "name": "John Doe",\n  "iat": 1516239022\n}';
    _generateJwtSilent();
  }

  @override
  void dispose() {
    _headerController.removeListener(_onHeaderChanged);
    _payloadController.removeListener(_onPayloadChanged);
    _headerController.dispose();
    _payloadController.dispose();
    _tokenController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _onHeaderChanged() {
    try {
      final text = _headerController.text;
      if (text.trim().isEmpty) {
        setState(() {
          _headerError = null;
        });
        return;
      }
      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) {
        setState(() {
          _headerError = null;
        });
      } else {
        setState(() {
          _headerError = "Must be a JSON object";
        });
      }
    } catch (e) {
      setState(() {
        _headerError = "Invalid JSON";
      });
    }
  }

  void _onPayloadChanged() {
    try {
      final text = _payloadController.text;
      if (text.trim().isEmpty) {
        setState(() {
          _payloadMap = null;
          _payloadError = null;
        });
        return;
      }
      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) {
        setState(() {
          _payloadMap = parsed;
          _payloadError = null;
        });
      } else {
        setState(() {
          _payloadError = "Must be a JSON object";
        });
      }
    } catch (e) {
      setState(() {
        _payloadError = "Invalid JSON";
      });
    }
  }

  void _processJwt() {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _payloadMap = null;
        _headerController.removeListener(_onHeaderChanged);
        _payloadController.removeListener(_onPayloadChanged);
        _headerController.text = "";
        _payloadController.text = "";
        _headerController.addListener(_onHeaderChanged);
        _payloadController.addListener(_onPayloadChanged);
        _error = null;
        _isSignatureValid = null;
        _headerError = null;
        _payloadError = null;
      });
      return;
    }

    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw const FormatException("Invalid JWT: Must have 3 parts");
      }

      final header = _decodeBase64Json(parts[0]);
      final payload = _decodeBase64Json(parts[1]);

      setState(() {
        _payloadMap = payload;

        _headerController.removeListener(_onHeaderChanged);
        _payloadController.removeListener(_onPayloadChanged);
        _headerController.text = const JsonEncoder.withIndent('  ').convert(header);
        _payloadController.text = const JsonEncoder.withIndent('  ').convert(payload);
        _headerController.addListener(_onHeaderChanged);
        _payloadController.addListener(_onPayloadChanged);

        _error = null;
        _headerError = null;
        _payloadError = null;
      });

      _verifySignature(parts[0], parts[1], parts[2]);
    } catch (e) {
      setState(() {
        _payloadMap = null;
        _headerController.removeListener(_onHeaderChanged);
        _payloadController.removeListener(_onPayloadChanged);
        _headerController.text = "";
        _payloadController.text = "";
        _headerController.addListener(_onHeaderChanged);
        _payloadController.addListener(_onPayloadChanged);
        _error = "Error: ${e.toString()}";
        _isSignatureValid = null;
      });
    }
  }

  void _verifySignature(
    String headerB64,
    String payloadB64,
    String signatureB64,
  ) {
    final secret = _secretController.text;
    if (secret.isEmpty) {
      setState(() => _isSignatureValid = null);
      return;
    }

    try {
      final hmac = Hmac(sha256, utf8.encode(secret));
      final dataToSign = utf8.encode("$headerB64.$payloadB64");
      final digest = hmac.convert(dataToSign);
      String calculatedSig = base64Url.encode(digest.bytes).replaceAll('=', '');

      setState(() {
        _isSignatureValid = calculatedSig == signatureB64;
      });
    } catch (e) {
      setState(() => _isSignatureValid = false);
    }
  }

  void _generateJwt() {
    final secret = _secretController.text;
    if (secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vui lòng nhập Secret Key để ký và tạo JWT mới!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final headerStr = _headerController.text.trim();
      final headerJson = jsonDecode(headerStr);
      final payloadStr = _payloadController.text.trim();
      final payloadJson = jsonDecode(payloadStr);

      final headerBytes = utf8.encode(jsonEncode(headerJson));
      final payloadBytes = utf8.encode(jsonEncode(payloadJson));

      final headerB64 = base64Url.encode(headerBytes).replaceAll('=', '');
      final payloadB64 = base64Url.encode(payloadBytes).replaceAll('=', '');

      final hmac = Hmac(sha256, utf8.encode(secret));
      final dataToSign = utf8.encode("$headerB64.$payloadB64");
      final digest = hmac.convert(dataToSign);
      final signatureB64 = base64Url.encode(digest.bytes).replaceAll('=', '');

      final newToken = "$headerB64.$payloadB64.$signatureB64";

      setState(() {
        _tokenController.text = newToken;
        _payloadMap = payloadJson;
        _error = null;
        _isSignatureValid = true;
      });

      Clipboard.setData(ClipboardData(text: newToken));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("JWT mới đã được tạo và copy vào clipboard!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Lỗi tạo JWT: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _generateJwtSilent() {
    try {
      final headerStr = _headerController.text.trim();
      final headerJson = jsonDecode(headerStr);
      final payloadStr = _payloadController.text.trim();
      final payloadJson = jsonDecode(payloadStr);

      final headerBytes = utf8.encode(jsonEncode(headerJson));
      final payloadBytes = utf8.encode(jsonEncode(payloadJson));

      final headerB64 = base64Url.encode(headerBytes).replaceAll('=', '');
      final payloadB64 = base64Url.encode(payloadBytes).replaceAll('=', '');

      final secret = _secretController.text;
      final hmac = Hmac(sha256, utf8.encode(secret));
      final dataToSign = utf8.encode("$headerB64.$payloadB64");
      final digest = hmac.convert(dataToSign);
      final signatureB64 = base64Url.encode(digest.bytes).replaceAll('=', '');

      _tokenController.text = "$headerB64.$payloadB64.$signatureB64";
      _payloadMap = payloadJson;
      _error = null;
      _isSignatureValid = true;
    } catch (e) {
      _error = e.toString();
    }
  }

  Map<String, dynamic> _decodeBase64Json(String str) {
    String normalized = base64Url.normalize(str);
    String decodedString = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decodedString);
  }

  // --- Helper to build time badges ---
  Widget _buildTimeClaims() {
    if (_payloadMap == null) return const SizedBox.shrink();

    final List<Widget> timeWidgets = [];

    void addTimeWidget(String key, String label, Color color) {
      if (_payloadMap!.containsKey(key)) {
        final val = _payloadMap![key];
        if (val is int) {
          final dt = DateTime.fromMillisecondsSinceEpoch(
            val * 1000,
            isUtc: true,
          ).add(const Duration(hours: 7));
          final formatted =
              "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
              "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";

          timeWidgets.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "$label: ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    TextSpan(
                      text: formatted,
                      style: TextStyle(color: color),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
          timeWidgets.add(const SizedBox(width: 8));
        }
      }
    }

    addTimeWidget('iat', 'Issued At', Colors.blue.shade700);
    addTimeWidget('exp', 'Expires', Colors.orange.shade800);
    addTimeWidget('nbf', 'Not Before', Colors.purple.shade700);

    if (timeWidgets.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.yellow.shade50,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          const Text(
            "GMT+7: ",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          ...timeWidgets,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("JWT Decoder & Verifier"), elevation: 1),
      body: SplitPane(
        initialRatio: 0.4,
        left: Column(
          children: [
            Expanded(
              flex: 3,
              child: InputPane(
                label: "ENCODED TOKEN",
                controller: _tokenController,
                onChanged: (_) => _processJwt(),
                hintText: "Paste JWT (ey...) here",
                errorText: _error,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.grey.shade50,
                child: Column(
                  children: [
                    const PaneHeader(title: "VERIFY SIGNATURE (HS256)"),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _secretController,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText: "Enter your secret key...",
                            border: InputBorder.none,
                            suffixIcon: _isSignatureValid == null
                                ? null
                                : Icon(
                                    _isSignatureValid!
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: _isSignatureValid!
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                          ),
                          onChanged: (_) => _processJwt(),
                        ),
                      ),
                    ),
                    if (_isSignatureValid != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        color: _isSignatureValid!
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        child: Text(
                          _isSignatureValid!
                              ? "Signature Verified"
                              : "Invalid Signature",
                          style: TextStyle(
                            color: _isSignatureValid!
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generateJwt,
                      icon: const Icon(Icons.flash_on),
                      label: const Text("Tạo JWT mới"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () {
                      final token = _tokenController.text.trim();
                      if (token.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: token));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("JWT copied to clipboard!")),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    tooltip: "Copy JWT",
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        right: Container(
          color: Colors.white,
          child: Column(
            children: [
              const PaneHeader(title: "DECODED HEADER & PAYLOAD"),
              Expanded(
                child: Column(
                  children: [
                    // Header Section Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: Colors.grey.shade200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "HEADER: ALGORITHM & TOKEN TYPE",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (_headerError != null)
                            Text(
                              _headerError!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Header Section Body
                    Expanded(
                      flex: 1,
                      child: Container(
                        color: Colors.grey.shade50,
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _headerController,
                          maxLines: null,
                          minLines: null,
                          expands: true,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Header JSON",
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),

                    // Payload Section Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: Colors.grey.shade200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "PAYLOAD: DATA / CLAIMS",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (_payloadError != null)
                            Text(
                              _payloadError!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Time Claims Display
                    _buildTimeClaims(),
                    // Payload Section Body
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: Colors.grey.shade50,
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _payloadController,
                          maxLines: null,
                          minLines: null,
                          expands: true,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Payload JSON",
                          ),
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
    );
  }
}

// --- EXPRESSION PARSER HELPER ---
class _ExpressionParser {
  final String expr;
  int _pos = 0;

  _ExpressionParser(this.expr);

  BigInt? parse() {
    if (expr.isEmpty) return null;
    BigInt result = _parseE();
    if (_pos < expr.length) {
      throw Exception("Unexpected character at end of expression");
    }
    return result;
  }

  BigInt _parseE() {
    BigInt v = _parseT();
    while (_pos < expr.length) {
      if (expr[_pos] == '+') {
        _pos++;
        v = (v + _parseT()).toUnsigned(64); // Wrap around for uint64
      } else if (expr[_pos] == '-') {
        _pos++;
        v = (v - _parseT()).toUnsigned(64); // Wrap around for uint64
      } else {
        break;
      }
    }
    return v;
  }

  BigInt _parseT() {
    BigInt v = _parseF();
    while (_pos < expr.length) {
      if (expr[_pos] == '*') {
        _pos++;
        v = (v * _parseF()).toUnsigned(64);
      } else if (expr[_pos] == '/') {
        _pos++;
        BigInt divisor = _parseF();
        if (divisor == BigInt.zero) throw Exception("Divide by zero");
        v = (v ~/ divisor).toUnsigned(64); // Integer division
      } else {
        break;
      }
    }
    return v;
  }

  BigInt _parseF() {
    if (_pos >= expr.length) throw Exception("Unexpected end of expression");
    if (expr[_pos] == '(') {
      _pos++;
      BigInt v = _parseE();
      if (_pos >= expr.length || expr[_pos] != ')') {
        throw Exception("Missing closing parenthesis");
      }
      _pos++;
      return v;
    }
    int start = _pos;
    while (_pos < expr.length && RegExp(r'[0-9]').hasMatch(expr[_pos])) {
      _pos++;
    }
    if (start == _pos) throw Exception("Expected number");
    return BigInt.parse(expr.substring(start, _pos));
  }
}

// --- TOOL 6: UINT64 CALCULATOR (EXPRESSION BASED) ---
class Uint64CalcTool extends StatefulWidget {
  const Uint64CalcTool({super.key});

  @override
  State<Uint64CalcTool> createState() => _Uint64CalcToolState();
}

class _Uint64CalcToolState extends State<Uint64CalcTool> {
  final TextEditingController _exprController = TextEditingController();
  final TextEditingController _result = TextEditingController();

  void _calculate() {
    String text = _exprController.text.trim();
    if (text.isEmpty) {
      setState(() => _result.text = "");
      return;
    }

    try {
      BigInt? res = _evaluateExpression(text);
      if (res != null) {
        setState(() => _result.text = res.toString());
      } else {
        setState(() => _result.text = "");
      }
    } catch (e) {
      setState(() => _result.text = "Error: Invalid expression or syntax");
    }
  }

  BigInt? _evaluateExpression(String expr) {
    // Sanitize and replace user-friendly multiplication symbols
    expr = expr.replaceAll(' ', '').replaceAll('x', '*').replaceAll('X', '*');
    if (expr.isEmpty) return null;
    return _ExpressionParser(expr).parse();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Uint64 Calculator"), elevation: 1),
      body: SplitPane(
        initialRatio: 0.5,
        left: InputPane(
          label: "EXPRESSION (UINT64)",
          controller: _exprController,
          hintText: "Enter expression, e.g., (10 * 4) + 2 - 3",
          onChanged: (_) => _calculate(),
        ),
        right: Column(
          children: [
            const PaneHeader(title: "RESULT"),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.grey.shade100,
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: SelectionArea(
                    child: Text(
                      _result.text.isEmpty
                          ? "Waiting for expression..."
                          : _result.text,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _result.text.startsWith("Error")
                            ? Colors.red
                            : Colors.green.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            if (!_result.text.startsWith("Error") && _result.text.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.white,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _result.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Result copied!")),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text("Copy Result"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class InputPane extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? errorText;
  final Function(String)? onChanged;
  final bool readOnly;
  final String? hintText;

  const InputPane({
    super.key,
    required this.label,
    required this.controller,
    this.errorText,
    this.onChanged,
    this.readOnly = false,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PaneHeader(title: label),
        Expanded(
          child: Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: controller,
              maxLines: null,
              minLines: null,
              expands: true,
              readOnly: readOnly,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                errorText: errorText,
                hintText: hintText,
                alignLabelWithHint: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class PaneHeader extends StatelessWidget {
  final String title;
  const PaneHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.grey.shade200,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// --- CUSTOM CONTROLLER FOR SYNTAX HIGHLIGHTING ---
class JsonSyntaxTextController extends TextEditingController {
  JsonSyntaxTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final RegExp regex = RegExp(
      r'("(?:\.|[^"\\])*")|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(true|false|null)|([{}\[\],:])',
    );

    style ??= const TextStyle(color: Colors.black);
    final matches = regex.allMatches(text).toList();

    int highlightIndex1 = -1;
    int highlightIndex2 = -1;

    // Lấy vị trí con trỏ hiện tại
    int cursor = selection.baseOffset;

    if (cursor >= 0) {
      // Thu thập tất cả các ngoặc hợp lệ (không nằm trong string)
      List<MapEntry<int, String>> brackets = [];
      for (int i = 0; i < matches.length; i++) {
        final m = matches[i];
        if (m.group(4) != null) {
          String punc = m.group(0)!;
          if ('{}[]()'.contains(punc)) {
            brackets.add(MapEntry(m.start, punc));
          }
        }
      }

      // Kiểm tra xem con trỏ có đang đứng cạnh một ngoặc nào không
      int targetBracketIndex = -1;
      String targetBracket = '';
      for (int i = 0; i < brackets.length; i++) {
        if (brackets[i].key == cursor) {
          targetBracketIndex = i;
          targetBracket = brackets[i].value;
          break;
        } else if (brackets[i].key == cursor - 1) {
          targetBracketIndex = i;
          targetBracket = brackets[i].value;
        }
      }

      // Nếu đang đứng cạnh một ngoặc, đi tìm ngoặc đối xứng của nó
      if (targetBracketIndex != -1) {
        if ('{['.contains(targetBracket) || targetBracket == '(') {
          int depth = 1;
          String closeBracket = targetBracket == '{'
              ? '}'
              : (targetBracket == '[' ? ']' : ')');
          for (int i = targetBracketIndex + 1; i < brackets.length; i++) {
            if (brackets[i].value == targetBracket) {
              depth++;
            } else if (brackets[i].value == closeBracket) {
              depth--;
            }

            if (depth == 0) {
              highlightIndex1 = brackets[targetBracketIndex].key;
              highlightIndex2 = brackets[i].key;
              break;
            }
          }
        } else if ('}]'.contains(targetBracket) || targetBracket == ')') {
          int depth = 1;
          String openBracket = targetBracket == '}'
              ? '{'
              : (targetBracket == ']' ? '[' : '(');
          for (int i = targetBracketIndex - 1; i >= 0; i--) {
            if (brackets[i].value == targetBracket) {
              depth++;
            } else if (brackets[i].value == openBracket) {
              depth--;
            }

            if (depth == 0) {
              highlightIndex1 = brackets[targetBracketIndex].key;
              highlightIndex2 = brackets[i].key;
              break;
            }
          }
        }
      }
    }

    int currentIndex = 0;

    for (final Match match in matches) {
      if (match.start > currentIndex) {
        children.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: style,
          ),
        );
      }

      final String? matchedText = match.group(0);
      TextStyle matchStyle = style;

      if (match.group(1) != null) {
        // String
        bool isKey = false;
        int nextIndex = match.end;
        while (nextIndex < text.length && text[nextIndex].trim().isEmpty) {
          nextIndex++;
        }
        if (nextIndex < text.length && text[nextIndex] == ':') isKey = true;
        matchStyle = TextStyle(
          color: isKey ? Colors.blue[800] : Colors.orange[800],
          fontWeight: isKey ? FontWeight.bold : FontWeight.normal,
        );
      } else if (match.group(2) != null) {
        // Number
        matchStyle = const TextStyle(color: Colors.green);
      } else if (match.group(3) != null) {
        // Keyword
        matchStyle = const TextStyle(
          color: Colors.purple,
          fontWeight: FontWeight.bold,
        );
      } else if (match.group(4) != null) {
        // Punctuation
        // Đổi màu nền (highlight) nếu là ngoặc đang được trỏ tới
        if (match.start == highlightIndex1 || match.start == highlightIndex2) {
          matchStyle = const TextStyle(
            color: Colors.white,
            backgroundColor: Colors.blueAccent,
            fontWeight: FontWeight.bold,
          );
        } else {
          matchStyle = const TextStyle(color: Colors.grey);
        }
      }

      children.add(TextSpan(text: matchedText, style: matchStyle));
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      children.add(TextSpan(text: text.substring(currentIndex), style: style));
    }

    return TextSpan(style: style, children: children);
  }
}
