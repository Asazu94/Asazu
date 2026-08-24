import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'studio_runtime.dart';
import 'one_click_ai_ad.dart';
import 'render_engine.dart';

void main() => runApp(const AsazuStudioApp());

class AsazuStudioApp extends StatelessWidget {
  const AsazuStudioApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'ASAZU STUDIO',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
    home: const StudioHomePage(),
  );
}

class StudioHomePage extends StatefulWidget {
  const StudioHomePage({super.key});
  @override State<StudioHomePage> createState() => _StudioHomePageState();
}

class _StudioHomePageState extends State<StudioHomePage> {
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final features = TextEditingController();
  final audience = TextEditingController();
  final brand = TextEditingController(text: 'ASAZU STORE');
  String? imagePath;
  RenderPreset preset = RenderPreset.tiktok;
  StudioStatus status = StudioStatus.idle;
  double progress = 0;
  String message = 'Ready';
  String? outputPath;
  String? error;
  VideoPlayerController? player;
  StudioRuntime? runtime;
  late final StudioGenerationController controller;

  @override void initState() {
    super.initState();
    controller = StudioGenerationController();
    _initRuntime();
  }

  Future<void> _initRuntime() async {
    final root = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    setState(() {
      runtime = StudioRuntime(config: StudioConfig(workspace: Directory('${root.path}${Platform.pathSeparator}asazu_workspace')));
    });
  }

  @override void dispose() {
    for (final c in [name, description, price, features, audience, brand]) c.dispose();
    player?.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result?.files.single.path != null) setState(() => imagePath = result!.files.single.path);
  }

  Future<void> generate() async {
    if (name.text.trim().isEmpty || imagePath == null) {
      setState(() => error = 'Weka jina la bidhaa na picha ya bidhaa kwanza.');
      return;
    }
    final activeRuntime = runtime;
    if (activeRuntime == null) {
      setState(() => error = 'App bado inaandaa storage. Subiri kidogo.');
      return;
    }
    final health = await activeRuntime.healthCheck();
    if (!health.workspaceReady) {
      setState(() => error = health.warnings.join('\n'));
      return;
    }
    final output = '${activeRuntime.config.exports.path}${Platform.pathSeparator}${_safe(name.text)}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    setState(() { error = null; outputPath = null; status = StudioStatus.preparing; progress = 0; message = 'Preparing...'; });
    controller.generate(OneClickAdInput(
      product: ProductInput(name: name.text, description: description.text, price: price.text,
        features: features.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        targetAudience: audience.text, brandName: brand.text),
      productImagePath: imagePath!, outputPath: output, preset: preset,
    )).then((result) async {
      if (!mounted) return;
      setState(() { status = controller.state.status; progress = controller.state.progress; message = controller.state.message; outputPath = result.success ? result.outputPath : null; error = result.success ? null : result.render.error; });
      if (result.success) await _openPreview(result.outputPath);
    }).catchError((e) { if (mounted) setState(() { status = StudioStatus.failed; error = '$e'; }); });
    _pollState();
  }

  Future<void> _pollState() async {
    while (mounted && controller.state.status != StudioStatus.completed && controller.state.status != StudioStatus.failed) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() { status = controller.state.status; progress = controller.state.progress; message = controller.state.message; });
    }
  }

  Future<void> _openPreview(String path) async {
    final c = VideoPlayerController.file(File(path));
    try { await c.initialize(); await c.setLooping(true); if (!mounted) return; await player?.dispose(); setState(() => player = c); await c.play(); } catch (_) { await c.dispose(); }
  }

  String _safe(String value) => value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ASAZU STUDIO'), actions: [IconButton(onPressed: () async { final activeRuntime = runtime; if (activeRuntime == null) return; final h = await activeRuntime.healthCheck(); if (!mounted) return; showDialog(context: context, builder: (_) => AlertDialog(title: const Text('System Health'), content: Text('Workspace: ${h.workspaceReady ? 'OK' : 'ERROR'}\nFFmpeg: ${h.ffmpegAvailable ? 'OK' : 'NOT FOUND'}\n\n${h.warnings.join('\n')}'))); }, icon: const Icon(Icons.health_and_safety))]),
      body: LayoutBuilder(builder: (context, box) => Row(children: [
        SizedBox(width: box.maxWidth > 900 ? 420 : box.maxWidth, child: _form()),
        if (box.maxWidth > 900) Expanded(child: _preview()),
      ])),
    );
  }

  Widget _form() => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Create Advertisement', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 16),
    OutlinedButton.icon(onPressed: pickImage, icon: const Icon(Icons.image), label: Text(imagePath == null ? 'Upload Product Image' : 'Product Image Selected')),
    const SizedBox(height: 12),
    _field(name, 'Product name', Icons.shopping_bag), _field(description, 'Description', Icons.description, max: 3),
    _field(price, 'Price', Icons.payments), _field(features, 'Benefits (comma separated)', Icons.stars),
    _field(audience, 'Target audience', Icons.people), _field(brand, 'Brand name', Icons.store),
    DropdownButtonFormField<RenderPreset>(value: preset, decoration: const InputDecoration(labelText: 'Format'), items: RenderPreset.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(), onChanged: (v) => setState(() => preset = v ?? preset)),
    const SizedBox(height: 20),
    FilledButton.icon(onPressed: status == StudioStatus.generating || status == StudioStatus.rendering ? null : generate, icon: const Icon(Icons.auto_awesome), label: const Text('GENERATE AI AD')),
    const SizedBox(height: 16), LinearProgressIndicator(value: progress == 0 ? null : progress), const SizedBox(height: 8), Text(message),
    if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    if (outputPath != null) Padding(padding: const EdgeInsets.only(top: 12), child: SelectableText('Exported: $outputPath')),
  ]));

  Widget _field(TextEditingController c, String label, IconData icon, {int max = 1}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, maxLines: max, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder())));

  Widget _preview() => Container(padding: const EdgeInsets.all(24), child: Center(child: player != null && player!.value.isInitialized ? AspectRatio(aspectRatio: player!.value.aspectRatio, child: VideoPlayer(player!)) : Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.movie_creation_outlined, size: 96), const SizedBox(height: 12), Text(outputPath == null ? 'Your generated video will appear here.' : 'Preparing preview...')])));
}
