import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';

class GameTypeItem {
  final String id;
  final String label;
  final String icon;
  final Color color;
  final String desc;

  GameTypeItem(this.id, this.label, this.icon, this.color, this.desc);
}

final List<GameTypeItem> _gameTypes = [
  GameTypeItem("platformer", "Platformer", "🏃", const Color(0xFF10B981), "Jump & run"),
  GameTypeItem("shooter", "Shooter", "🚀", const Color(0xFFEF4444), "Space shooter"),
  GameTypeItem("puzzle", "Puzzle", "🧩", const Color(0xFF8B5CF6), "Block puzzle"),
  GameTypeItem("rpg", "RPG", "⚔️", const Color(0xFFF59E0B), "Top-down RPG"),
  GameTypeItem("arcade", "Arcade", "👾", const Color(0xFF6366F1), "Classic arcade"),
  GameTypeItem("racing", "Racing", "🏎️", const Color(0xFFF97316), "Top-down race"),
];

class AiGameGenScreen extends StatefulWidget {
  const AiGameGenScreen({super.key});

  @override
  State<AiGameGenScreen> createState() => _AiGameGenScreenState();
}

class _AiGameGenScreenState extends State<AiGameGenScreen> {
  String _selectedType = "shooter";
  final TextEditingController _promptController = TextEditingController();
  bool _isRefining = false;
  bool _isGenerating = false;
  String _htmlCode = "";
  double _progress = 0;
  String? _error;
  bool _showPreview = false;
  String _activeTab = "preview"; // "preview" or "code"
  String _generationStatus = "Generating with Claude AI...";
  
  http.Client? _httpClient;
  InAppWebViewController? _webViewController;

  @override
  void dispose() {
    _httpClient?.close();
    _promptController.dispose();
    super.dispose();
  }

  String _buildPrompt(GameTypeItem type, String userPrompt) {
    return '''You are an expert HTML5 Canvas game developer. Generate a COMPLETE, FULLY WORKING HTML5 game.

GAME TYPE: ${type.label} — ${type.desc}
USER REQUEST: "$userPrompt"

MANDATORY RULES:
1. Output ONLY the raw HTML — NO markdown, NO backticks, NO explanation whatsoever
2. Start exactly with <!DOCTYPE html>
3. Use HTML5 Canvas (id="c", 800x500)
4. Use plain var/function style — NO ES6 classes
5. keyboard: track keys with keydown/keyup into a keys={} object
6. requestAnimationFrame game loop
7. Score + lives display in canvas
8. Game over screen + restart button
9. Web Audio API beep() function for sounds — NO Audio() or .mp3 files
10. Neon/dark visual style with vibrant colors
11. ALL braces must be properly closed — complete, syntactically valid JS

Begin output now with <!DOCTYPE html>:''';
  }

  String _sanitizeCode(String raw) {
    String s = raw.replaceAll(RegExp(r'```html', caseSensitive: false), '')
        .replaceAll(RegExp(r'```javascript', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
    int idx = s.indexOf("<!DOCTYPE");
    if (idx > 0) s = s.substring(idx);
    
    if (s.contains("<script>") && !s.contains("</script>")) {
      s += "\n</script></body></html>";
    }
    
    int endIdx = s.lastIndexOf("</html>");
    if (endIdx > 0) {
      s = s.substring(0, endIdx + 7);
    }
    
    s = s.replaceAll(RegExp(r'new Audio\([^)]*\)'), 'null')
         .replaceAll('.play()', '/*play*/');
         
    return s;
  }

  Future<void> _refinePrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _isRefining) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _isRefining = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/ai/game-gen/refine-prompt'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'prompt': prompt}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['refined'] != null) {
          setState(() {
            _promptController.text = data['refined'];
          });
        }
      } else {
        throw Exception("Failed to refine prompt: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isRefining = false);
    }
  }

  Future<void> _generateGame() async {
    final userPrompt = _promptController.text.trim();
    if (userPrompt.isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) {
      setState(() => _error = "Not authenticated");
      return;
    }

    final typeItem = _gameTypes.firstWhere((t) => t.id == _selectedType);
    final fullPrompt = _buildPrompt(typeItem, userPrompt);

    setState(() {
      _isGenerating = true;
      _htmlCode = "";
      _progress = 0;
      _error = null;
      _showPreview = false;
      _activeTab = "preview";
      _generationStatus = "Generating with Claude AI...";
    });

    _httpClient?.close();
    _httpClient = http.Client();

    try {
      final request = http.Request('POST', Uri.parse('${ApiService.baseUrl}/ai/game-gen/generate-stream'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.body = jsonEncode({'prompt': fullPrompt});

      final response = await _httpClient!.send(request);

      if (response.statusCode != 200 && response.statusCode != 201) {
        final body = await response.stream.bytesToString();
        throw Exception("API Error ${response.statusCode}: $body");
      }

      String rawText = "";
      const int targetChars = 6000;

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') break;
            
            try {
              final parsed = jsonDecode(dataStr);
              
              // Handle potential fallback notification from backend
              if (parsed['fallback'] == true) {
                setState(() => _generationStatus = "Claude busy, switching to Gemini...");
              }

              final text = parsed['delta']?['text'] as String?;
              if (text != null && text.isNotEmpty) {
                rawText += text;
                setState(() {
                  _progress = (rawText.length / targetChars * 100).clamp(0, 95);
                  // Update preview periodically if it looks like we have a canvas/game loop
                  if (rawText.length % 500 < text.length) {
                    final partial = _sanitizeCode(rawText);
                    if (partial.contains("<canvas") || partial.contains("requestAnimationFrame")) {
                      _htmlCode = partial;
                    }
                  }
                });
              }
            } catch (e) {
              // ignore parse errors for partial chunks
            }
          }
        }
      }
      
      if (mounted && _isGenerating) {
        setState(() {
          _isGenerating = false;
          _htmlCode = _sanitizeCode(rawText);
          _progress = 100;
          _showPreview = true;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _error = e.toString();
        });
      }
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(), // Empty flexibleSpace
        centerTitle: false,
        titleSpacing: 8,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
              onPressed: () {
                context.go('/dashboard?tab=home');
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'CLAUDE AI → FULL HTML5 GAME GENERATOR',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Text(
                    'GameGen AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(child: _buildConfig()),
          if (_htmlCode.isNotEmpty || _isGenerating) 
            _buildOutputSection(),
        ],
      ),
    );
  }

  Widget _buildOutputSection() {
    final type = _gameTypes.firstWhere((t) => t.id == _selectedType);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: MediaQuery.of(context).size.height * 0.6,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B2E),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton("preview", "🎮 Preview"),
                      _buildTabButton("code", "💻 Code"),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text("${_htmlCode.length} chars", style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace')),
                const Spacer(),
                if (_htmlCode.isNotEmpty) ...[
                  _buildCircleAction(Icons.refresh_rounded, () => _webViewController?.reload()),
                  const SizedBox(width: 8),
                  _buildCircleAction(Icons.copy_rounded, () {
                    Clipboard.setData(ClipboardData(text: _htmlCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied!")));
                  }),
                ],
              ],
            ),
          ),
          Expanded(
            child: _activeTab == "preview" ? _buildPreview() : _buildCodeView(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String id, String label) {
    bool active = _activeTab == id;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: 11, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildCircleAction(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white60, size: 18),
      ),
    );
  }

  Widget _buildCodeView() {
    return Container(
      width: double.infinity,
      color: Colors.black.withOpacity(0.3),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        reverse: true,
        child: Text(
          _htmlCode.isEmpty ? "Initializing Claude..." : _htmlCode,
          style: const TextStyle(color: Color(0xFF10B981), fontFamily: 'monospace', fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_htmlCode.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white24));
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: InAppWebView(
        initialData: InAppWebViewInitialData(data: _htmlCode, mimeType: 'text/html'),
        onWebViewCreated: (controller) => _webViewController = controller,
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          disableHorizontalScroll: true,
          disableVerticalScroll: true,
        ),
      ),
    );
  }

  Widget _buildConfig() {
    final sel = _gameTypes.firstWhere((t) => t.id == _selectedType);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GAME TYPE', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: _gameTypes.length,
            itemBuilder: (context, index) {
              final type = _gameTypes[index];
              final isSelected = _selectedType == type.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedType = type.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: isSelected ? type.color.withOpacity(0.15) : const Color(0xFF161B2E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? type.color.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                      width: 2,
                    ),
                    boxShadow: isSelected ? [BoxShadow(color: type.color.withOpacity(0.2), blurRadius: 15)] : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(type.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(type.label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(type.desc, style: const TextStyle(color: Colors.white24, fontSize: 8)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DESCRIBE YOUR GAME', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              GestureDetector(
                onTap: _refinePrompt,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isRefining 
                        ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFB794F6)))
                        : const Text('✨', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      const Text('AI REFINE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF161B2E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: TextField(
              controller: _promptController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. "Neon ${sel.label.toLowerCase()} with power-ups..."',
                hintStyle: const TextStyle(color: Colors.white10),
                contentPadding: const EdgeInsets.all(20),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text('⚠️ $_error', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ],
          const SizedBox(height: 32),
          if (_isGenerating) ...[
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CLAUDE IS WRITING CODE...', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900)),
                    Text('${_progress.toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress / 100,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(sel.color),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () { _httpClient?.close(); setState(() => _isGenerating = false); },
                  child: const Text('CANCEL GENERATION', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ),
              ],
            ).animate().fadeIn(),
          ] else ...[
            GestureDetector(
              onTap: _generateGame,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [sel.color, sel.color.withBlue(255).withGreen(100)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: sel.color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Text('GENERATE ${sel.label.toUpperCase()} GAME', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildTipCard('💡 Claude generates fully working games in ~15 seconds'),
          _buildTipCard('• "Neon space shooter, 3 enemy types, boss at wave 5"'),
          _buildTipCard('• "Pixel platformer with gravity, coins, and spikes"'),
        ],
      ),
    );
  }

  Widget _buildTipCard(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: Colors.white24, fontSize: 11)),
    );
  }
}
