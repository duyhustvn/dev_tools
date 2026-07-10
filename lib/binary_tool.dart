import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BinaryTool extends StatefulWidget {
  const BinaryTool({super.key});

  @override
  State<BinaryTool> createState() => _BinaryToolState();
}

class _BinaryToolState extends State<BinaryTool> {
  // Underlying value represented as an unsigned BigInt
  BigInt _currentValue = BigInt.zero;
  int _bitWidth = 64; // 8, 16, 32, 64
  bool _isSigned = false;

  late final TextEditingController _decController;
  late final TextEditingController _hexController;
  late final TextEditingController _binController;
  late final TextEditingController _octController;

  String? _decError;
  String? _hexError;
  String? _binError;
  String? _octError;

  @override
  void initState() {
    super.initState();
    _decController = TextEditingController(text: '0');
    _hexController = TextEditingController(text: '0');
    _binController = TextEditingController(text: '0'.padLeft(_bitWidth, '0'));
    _octController = TextEditingController(text: '0');
    _updateAllFields();
  }

  @override
  void dispose() {
    _decController.dispose();
    _hexController.dispose();
    _binController.dispose();
    _octController.dispose();
    super.dispose();
  }

  // --- Masking & Range Calculations ---

  BigInt get _mask => (BigInt.one << _bitWidth) - BigInt.one;

  BigInt _applyMask(BigInt val) => val & _mask;

  BigInt _getSignedValue(BigInt unsignedVal) {
    if (!_isSigned) return unsignedVal;
    BigInt msbMask = BigInt.one << (_bitWidth - 1);
    if ((unsignedVal & msbMask) != BigInt.zero) {
      return unsignedVal - (BigInt.one << _bitWidth);
    }
    return unsignedVal;
  }

  BigInt _getUnsignedValue(BigInt signedVal) {
    return signedVal & _mask;
  }

  // --- Formatting Output Strings ---

  String _getFormattedDec() {
    BigInt val = _getSignedValue(_currentValue);
    String str = val.toString();
    bool isNegative = str.startsWith('-');
    if (isNegative) str = str.substring(1);
    StringBuffer sb = StringBuffer();
    int len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) sb.write(',');
      sb.write(str[i]);
    }
    return (isNegative ? '-' : '') + sb.toString();
  }

  String _getFormattedHex() {
    int hexLength = _bitWidth ~/ 4;
    String hexStr = _currentValue.toRadixString(16).toUpperCase().padLeft(hexLength, '0');
    StringBuffer sb = StringBuffer();
    // Group hex digits by 4 (16 bits) for better readability
    for (int i = 0; i < hexStr.length; i++) {
      if (i > 0 && (hexStr.length - i) % 4 == 0) sb.write(' ');
      sb.write(hexStr[i]);
    }
    return '0x ${sb.toString()}';
  }

  String _getFormattedBin() {
    String binStr = _currentValue.toRadixString(2).padLeft(_bitWidth, '0');
    StringBuffer sb = StringBuffer();
    // Group binary digits by 4 (nibble) or 8 (byte). Let's group by 8.
    for (int i = 0; i < binStr.length; i++) {
      if (i > 0 && (binStr.length - i) % 8 == 0) sb.write(' ');
      sb.write(binStr[i]);
    }
    return sb.toString();
  }

  String _getFormattedOct() {
    String octStr = _currentValue.toRadixString(8);
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < octStr.length; i++) {
      if (i > 0 && (octStr.length - i) % 3 == 0) sb.write(' ');
      sb.write(octStr[i]);
    }
    return '0o ${sb.toString()}';
  }

  // --- Parsing input strings ---

  BigInt? _parseDec(String text) {
    String cleaned = text.replaceAll(RegExp(r'[,\s_]'), '');
    if (cleaned.isEmpty) return BigInt.zero;
    if (cleaned == '-') return null; // Wait for digits

    BigInt? val = BigInt.tryParse(cleaned);
    if (val == null) return null;

    if (_isSigned) {
      BigInt minVal = -(BigInt.one << (_bitWidth - 1));
      BigInt maxVal = (BigInt.one << (_bitWidth - 1)) - BigInt.one;
      if (val < minVal || val > maxVal) return null;
    } else {
      BigInt minVal = BigInt.zero;
      BigInt maxVal = (BigInt.one << _bitWidth) - BigInt.one;
      if (val < minVal || val > maxVal) return null;
    }
    return val;
  }

  BigInt? _parseHex(String text) {
    String cleaned = text.replaceAll(RegExp(r'[,\s_xXoO]'), '');
    if (cleaned.isEmpty) return BigInt.zero;
    BigInt? val = BigInt.tryParse(cleaned, radix: 16);
    if (val == null) return null;

    BigInt maxVal = (BigInt.one << _bitWidth) - BigInt.one;
    if (val < BigInt.zero || val > maxVal) return null;
    return val;
  }

  BigInt? _parseBin(String text) {
    String cleaned = text.replaceAll(RegExp(r'[\s_]'), '');
    if (cleaned.isEmpty) return BigInt.zero;
    BigInt? val = BigInt.tryParse(cleaned, radix: 2);
    if (val == null) return null;

    BigInt maxVal = (BigInt.one << _bitWidth) - BigInt.one;
    if (val < BigInt.zero || val > maxVal) return null;
    return val;
  }

  BigInt? _parseOct(String text) {
    String cleaned = text.replaceAll(RegExp(r'[,\s_oO]'), '');
    if (cleaned.isEmpty) return BigInt.zero;
    BigInt? val = BigInt.tryParse(cleaned, radix: 8);
    if (val == null) return null;

    BigInt maxVal = (BigInt.one << _bitWidth) - BigInt.one;
    if (val < BigInt.zero || val > maxVal) return null;
    return val;
  }

  // --- Actions ---

  void _updateFromBase(String baseType, String text) {
    setState(() {
      if (baseType == 'dec') {
        BigInt? val = _parseDec(text);
        if (val != null || text.trim().isEmpty || text.trim() == '-') {
          _decError = null;
          if (val != null) {
            _currentValue = _getUnsignedValue(val);
            _syncControllers(exclude: 'dec');
          }
        } else {
          _decError = 'Invalid Decimal for $_bitWidth-bit ${_isSigned ? "Signed" : "Unsigned"}';
        }
      } else if (baseType == 'hex') {
        BigInt? val = _parseHex(text);
        if (val != null || text.trim().isEmpty) {
          _hexError = null;
          if (val != null) {
            _currentValue = val;
            _syncControllers(exclude: 'hex');
          }
        } else {
          _hexError = 'Invalid Hex for $_bitWidth-bit';
        }
      } else if (baseType == 'bin') {
        BigInt? val = _parseBin(text);
        if (val != null || text.trim().isEmpty) {
          _binError = null;
          if (val != null) {
            _currentValue = val;
            _syncControllers(exclude: 'bin');
          }
        } else {
          _binError = 'Invalid Binary for $_bitWidth-bit';
        }
      } else if (baseType == 'oct') {
        BigInt? val = _parseOct(text);
        if (val != null || text.trim().isEmpty) {
          _octError = null;
          if (val != null) {
            _currentValue = val;
            _syncControllers(exclude: 'oct');
          }
        } else {
          _octError = 'Invalid Octal for $_bitWidth-bit';
        }
      }
    });
  }

  void _syncControllers({required String exclude}) {
    if (exclude != 'dec') _decController.text = _getFormattedDec();
    if (exclude != 'hex') _hexController.text = _getFormattedHex();
    if (exclude != 'bin') _binController.text = _getFormattedBin();
    if (exclude != 'oct') _octController.text = _getFormattedOct();
  }

  void _updateAllFields() {
    _decController.text = _getFormattedDec();
    _hexController.text = _getFormattedHex();
    _binController.text = _getFormattedBin();
    _octController.text = _getFormattedOct();
    _decError = null;
    _hexError = null;
    _binError = null;
    _octError = null;
  }

  void _toggleBit(int index) {
    setState(() {
      _currentValue = _currentValue ^ (BigInt.one << index);
      _currentValue = _applyMask(_currentValue);
      _updateAllFields();
    });
  }

  void _leftShift() {
    setState(() {
      _currentValue = _applyMask(_currentValue << 1);
      _updateAllFields();
    });
  }

  void _rightShift() {
    setState(() {
      _currentValue = _applyMask(_currentValue >> 1);
      _updateAllFields();
    });
  }

  void _bitwiseNot() {
    setState(() {
      _currentValue = _applyMask(~_currentValue);
      _updateAllFields();
    });
  }

  void _addOne() {
    setState(() {
      _currentValue = _applyMask(_currentValue + BigInt.one);
      _updateAllFields();
    });
  }

  void _subOne() {
    setState(() {
      _currentValue = _applyMask(_currentValue - BigInt.one);
      _updateAllFields();
    });
  }

  void _clear() {
    setState(() {
      _currentValue = BigInt.zero;
      _updateAllFields();
    });
  }

  void _random() {
    final rand = Random();
    BigInt val = BigInt.zero;
    for (int i = 0; i < _bitWidth; i++) {
      if (rand.nextBool()) {
        val |= (BigInt.one << i);
      }
    }
    setState(() {
      _currentValue = val;
      _updateAllFields();
    });
  }

  void _copyToClipboard(String text, String formatName) {
    Clipboard.setData(ClipboardData(text: text.replaceAll(RegExp(r'[,\s_oxXoO]'), '')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$formatName value copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  // --- ASCII & Bytes Preview ---

  String _getAsciiPreview() {
    List<int> bytes = [];
    BigInt temp = _currentValue;
    int byteCount = _bitWidth ~/ 8;
    for (int i = 0; i < byteCount; i++) {
      bytes.add((temp & BigInt.from(0xFF)).toInt());
      temp >>= 8;
    }
    bytes = bytes.reversed.toList();

    return bytes.map((b) {
      if (b >= 32 && b <= 126) {
        return String.fromCharCode(b);
      } else if (b == 0) {
        return 'Ø'; // Use empty/null set symbol for null character
      } else {
        return '·';
      }
    }).join(' ');
  }

  List<int> _getBytes() {
    List<int> bytes = [];
    BigInt temp = _currentValue;
    int byteCount = _bitWidth ~/ 8;
    for (int i = 0; i < byteCount; i++) {
      bytes.add((temp & BigInt.from(0xFF)).toInt());
      temp >>= 8;
    }
    return bytes.reversed.toList();
  }

  // --- Build UI Components ---

  // --- Build UI Components ---

  Widget _buildConfigPanel() {
    final widths = [8, 16, 32, 64];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Bit Width:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                ...widths.map((w) {
                  final isSelected = _bitWidth == w;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _bitWidth = w;
                          _currentValue = _applyMask(_currentValue);
                          _updateAllFields();
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          '$w-bit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.blue.shade800 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Signed Format:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isSigned,
                  onChanged: (val) {
                    setState(() {
                      _isSigned = val;
                      _updateAllFields();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationsPanel() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ElevatedButton.icon(
          onPressed: _leftShift,
          icon: const Icon(Icons.keyboard_double_arrow_left),
          label: const Text('LSL (<< 1)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade800,
            elevation: 0,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _rightShift,
          icon: const Icon(Icons.keyboard_double_arrow_right),
          label: const Text('LSR (>> 1)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade800,
            elevation: 0,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _bitwiseNot,
          icon: const Icon(Icons.restart_alt),
          label: const Text('NOT (~)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade800,
            elevation: 0,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _addOne,
          icon: const Icon(Icons.add),
          label: const Text('Add 1'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade50,
            foregroundColor: Colors.green.shade800,
            elevation: 0,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _subOne,
          icon: const Icon(Icons.remove),
          label: const Text('Sub 1'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade50,
            foregroundColor: Colors.green.shade800,
            elevation: 0,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Binary & Base Converter'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: _clear,
          ),
          IconButton(
            icon: const Icon(Icons.casino_outlined),
            tooltip: 'Random Value',
            onPressed: _random,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 850;

            final leftColumn = Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigPanel(),
                  const SizedBox(height: 20),
                  _buildBaseInputField(
                    fieldKey: const Key('binary-dec-field'),
                    label: 'Decimal',
                    controller: _decController,
                    errorText: _decError,
                    onChanged: (text) => _updateFromBase('dec', text),
                    helperText: _getDecRangeMessage(),
                    icon: Icons.pin_outlined,
                    formatName: 'Decimal',
                  ),
                  const SizedBox(height: 16),
                  _buildBaseInputField(
                    fieldKey: const Key('binary-hex-field'),
                    label: 'Hexadecimal (Base 16)',
                    controller: _hexController,
                    errorText: _hexError,
                    onChanged: (text) => _updateFromBase('hex', text),
                    icon: Icons.grid_3x3,
                    formatName: 'Hex',
                  ),
                  const SizedBox(height: 16),
                  _buildBaseInputField(
                    fieldKey: const Key('binary-bin-field'),
                    label: 'Binary (Base 2)',
                    controller: _binController,
                    errorText: _binError,
                    onChanged: (text) => _updateFromBase('bin', text),
                    icon: Icons.code,
                    formatName: 'Binary',
                  ),
                  const SizedBox(height: 16),
                  _buildBaseInputField(
                    fieldKey: const Key('binary-oct-field'),
                    label: 'Octal (Base 8)',
                    controller: _octController,
                    errorText: _octError,
                    onChanged: (text) => _updateFromBase('oct', text),
                    icon: Icons.eight_k_plus_outlined,
                    formatName: 'Octal',
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Bitwise / Quick Operations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildOperationsPanel(),
                ],
              ),
            );

            final rightColumn = Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Interactive Bit Board',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Click on any bit to toggle its value (0 ↔ 1). Leftmost is MSB, rightmost is LSB.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  _buildBitBoard(),
                  const SizedBox(height: 30),
                  const Text(
                    'Byte Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildByteDetailsCard(),
                ],
              ),
            );

            if (isNarrow) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    leftColumn,
                    const Divider(height: 1, thickness: 1),
                    rightColumn,
                  ],
                ),
              );
            } else {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(child: leftColumn),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(child: rightColumn),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  String _getDecRangeMessage() {
    if (_isSigned) {
      BigInt minVal = -(BigInt.one << (_bitWidth - 1));
      BigInt maxVal = (BigInt.one << (_bitWidth - 1)) - BigInt.one;
      return 'Range: $minVal to $maxVal';
    } else {
      BigInt maxVal = (BigInt.one << _bitWidth) - BigInt.one;
      return 'Range: 0 to $maxVal';
    }
  }

  Widget _buildBaseInputField({
    required Key fieldKey,
    required String label,
    required TextEditingController controller,
    required String? errorText,
    required ValueChanged<String> onChanged,
    String? helperText,
    required IconData icon,
    required String formatName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: fieldKey,
                controller: controller,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                decoration: InputDecoration(
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  errorText: errorText,
                  helperText: helperText,
                  helperStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  isDense: true,
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy $formatName',
              onPressed: () => _copyToClipboard(controller.text, formatName),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBitBoard() {
    List<Widget> rows = [];
    int itemsPerRow = 8;
    int rowCount = _bitWidth ~/ itemsPerRow;

    for (int r = 0; r < rowCount; r++) {
      List<Widget> bitWidgets = [];
      for (int i = 0; i < itemsPerRow; i++) {
        // Calculate bit index. The bits are displayed from MSB (left) to LSB (right).
        // For row r, the bit indices start from (_bitWidth - 1 - r*8) down to (_bitWidth - 8 - r*8).
        int bitIndex = _bitWidth - 1 - (r * itemsPerRow + i);
        bool isSet = (_currentValue & (BigInt.one << bitIndex)) != BigInt.zero;

        bitWidgets.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Tooltip(
                message: 'Bit $bitIndex\nValue: ${BigInt.one << bitIndex}',
                child: InkWell(
                  onTap: () => _toggleBit(bitIndex),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSet ? Colors.blue.shade400 : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      gradient: isSet
                          ? LinearGradient(
                              colors: [Colors.blue.shade500, Colors.indigo.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSet ? null : Colors.white,
                      boxShadow: isSet
                          ? [
                              BoxShadow(
                                color: Colors.blue.shade200.withValues(alpha: 0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isSet ? '1' : '0',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSet ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$bitIndex',
                          style: TextStyle(
                            fontSize: 9,
                            color: isSet ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              // Label for Byte index
              Container(
                width: 54,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Byte ${rowCount - 1 - r}:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ),
              ...bitWidgets,
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildByteDetailsCard() {
    List<int> bytes = _getBytes();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ASCII Representation',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getAsciiPreview(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Raw Bytes (Hex)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' '),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isSigned) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Two\'s Complement: The most significant bit (MSB) at index ${_bitWidth - 1} acts as the sign bit. Since value is ${_getSignedValue(_currentValue)}, representation is ${_getSignedValue(_currentValue).isNegative ? "negative" : "positive"}.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
