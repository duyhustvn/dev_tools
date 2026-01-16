import 'dart:async'; // Required for Timer in TimestampTool
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_json_view/flutter_json_view.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DevTools Pro',
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

// --- TOOL 1: JSON PRETTIFIER & VIEWER ---
class JsonTool extends StatefulWidget {
  const JsonTool({super.key});

  @override
  State<JsonTool> createState() => _JsonToolState();
}

class _JsonToolState extends State<JsonTool> {
  late final JsonSyntaxTextController _controller;
  Map<String, dynamic>? _jsonMap;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    String initialText = '{\n  "tool": "JSON Viewer",\n  "status": "Active"\n}';
    _controller = JsonSyntaxTextController(text: initialText);
    _parseJson();
  }

  void _parseJson() {
    try {
      final decoded = jsonDecode(_controller.text);
      if (decoded is Map<String, dynamic>) {
        setState(() {
          _jsonMap = decoded;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = "Input must be a JSON Object {}";
          _jsonMap = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Invalid JSON";
        _jsonMap = null;
      });
    }
  }

  void _prettify() {
    try {
      final dynamic decoded = jsonDecode(_controller.text);
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String prettyString = encoder.convert(decoded);
      setState(() {
        _controller.text = prettyString;
        _errorMessage = null;
      });
      _parseJson();
    } catch (e) {
      setState(() => _errorMessage = "Cannot prettify invalid JSON");
    }
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
        title: const Text("JSON Tools"),
        elevation: 1,
        actions: [
          // COPY BUTTON RESTORED HERE
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: "Copy Result",
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: "Prettify",
            onPressed: _prettify,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SplitPane(
        left: InputPane(
          label: "JSON INPUT",
          controller: _controller,
          errorText: _errorMessage,
          onChanged: (_) => _parseJson(),
        ),
        right: _jsonMap == null
            ? const Center(
                child: Text(
                  "Invalid JSON",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : Container(
                color: Colors.white,
                child: Column(
                  children: [
                    const PaneHeader(title: "TREE VIEW"),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: SelectionArea(
                          child: JsonView.map(
                            _jsonMap!,
                            theme: const JsonViewTheme(
                              backgroundColor: Colors.white,
                              keyStyle: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                              stringStyle: TextStyle(color: Colors.orange),
                              intStyle: TextStyle(color: Colors.green),
                              boolStyle: TextStyle(color: Colors.purple),
                            ),
                          ),
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

// --- TOOL 2: BASE64 ENCODER/DECODER ---
class Base64Tool extends StatefulWidget {
  const Base64Tool({super.key});

  @override
  State<Base64Tool> createState() => _Base64ToolState();
}

class _Base64ToolState extends State<Base64Tool> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  bool _isUrlSafe = true;

  void _encode() {
    try {
      final bytes = utf8.encode(_inputController.text);
      final result = _isUrlSafe
          ? base64Url.encode(bytes)
          : base64.encode(bytes);
      setState(() => _outputController.text = result);
    } catch (e) {
      setState(() => _outputController.text = "Error encoding: $e");
    }
  }

  void _decode() {
    try {
      String input = _inputController.text.trim();
      while (input.length % 4 != 0) {
        input += '=';
      }
      final bytes = _isUrlSafe ? base64Url.decode(input) : base64.decode(input);
      setState(() => _outputController.text = utf8.decode(bytes));
    } catch (e) {
      setState(
        () => _outputController.text = "Error decoding: Invalid Base64 string",
      );
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
                onChanged: (val) => setState(() => _isUrlSafe = val),
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
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text("Encode (Text → Base64)"),
                  onPressed: _encode,
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text("Decode (Base64 → Text)"),
                  onPressed: _decode,
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

  void _encode() {
    try {
      final result = Uri.encodeComponent(_inputController.text);
      setState(() => _outputController.text = result);
    } catch (e) {
      setState(() => _outputController.text = "Error encoding: $e");
    }
  }

  void _decode() {
    try {
      final result = Uri.decodeComponent(_inputController.text);
      setState(() => _outputController.text = result);
    } catch (e) {
      setState(() => _outputController.text = "Error decoding: $e");
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
                ElevatedButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text("Encode"),
                  onPressed: _encode,
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.link_off),
                  label: const Text("Decode"),
                  onPressed: _decode,
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
  String _result = "";
  Timer? _timer;

  // GMT+7 Helper
  String formatGmt7(DateTime dt) {
    // Add 7 hours to UTC to get Bangkok/Hanoi time
    final gmt7 = dt.toUtc().add(const Duration(hours: 7));
    return "${gmt7.year}-${gmt7.month.toString().padLeft(2, '0')}-${gmt7.day.toString().padLeft(2, '0')} "
        "${gmt7.hour.toString().padLeft(2, '0')}:${gmt7.minute.toString().padLeft(2, '0')}:${gmt7.second.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    _tsController.text = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    _convert();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

      setState(() {
        _result = "GMT+7: ${formatGmt7(dt)}\nUTC:   ${dt.toUtc()}";
      });
    } catch (e) {
      setState(() => _result = "Invalid timestamp");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Unix Timestamp Converter"),
        elevation: 1,
      ),
      body: Center(
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
                    const Text(
                      "Current Time (GMT+7)",
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatGmt7(DateTime.now()),
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
            ],
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

  Map<String, dynamic>? _headerMap;
  Map<String, dynamic>? _payloadMap;
  String? _error;
  bool? _isSignatureValid;

  void _processJwt() {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _headerMap = null;
        _payloadMap = null;
        _error = null;
        _isSignatureValid = null;
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
        _headerMap = header;
        _payloadMap = payload;
        _error = null;
      });

      _verifySignature(parts[0], parts[1], parts[2]);
    } catch (e) {
      setState(() {
        _headerMap = null;
        _payloadMap = null;
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.5)),
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
          ],
        ),
        right: Container(
          color: Colors.white,
          child: Column(
            children: [
              const PaneHeader(title: "DECODED HEADER & PAYLOAD"),
              Expanded(
                child: _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _headerMap == null
                    ? const Center(
                        child: Text(
                          "Paste a valid token to decode",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : SingleChildScrollView(
                        child: SelectionArea(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  "HEADER",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: JsonView.map(_headerMap!),
                              ),

                              const SizedBox(height: 20),

                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  "PAYLOAD",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),

                              _buildTimeClaims(),
                              const Divider(height: 1),

                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: JsonView.map(_payloadMap!),
                              ),
                            ],
                          ),
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
    int currentIndex = 0;

    for (final Match match in regex.allMatches(text)) {
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
        matchStyle = const TextStyle(color: Colors.grey);
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
