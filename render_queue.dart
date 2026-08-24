import 'dart:async';

import 'platform_optimization.dart';
import 'render_engine.dart';

class RenderJob {
  final String id;
  final RenderRequest request;
  final RenderPriority priority;
  const RenderJob({required this.id, required this.request, this.priority = RenderPriority.normal});
}

class RenderJobState {
  final String id;
  final RenderStatus status;
  final RenderResult? result;
  const RenderJobState({required this.id, required this.status, this.result});
}

class RenderQueue {
  final RenderEngine engine;
  final int maxConcurrent;
  final List<RenderJob> _pending = [];
  final Map<String, RenderJobState> _states = {};
  int _running = 0;
  bool _closed = false;

  RenderQueue({required this.engine, int? maxConcurrent, PlatformOptimizationProfile? profile})
      : maxConcurrent = maxConcurrent ?? (profile ?? PlatformOptimizationProfile.detect()).maxConcurrentRenders;

  List<RenderJobState> get states => List.unmodifiable(_states.values);

  Future<RenderJobState> enqueue(RenderJob job) {
    if (_closed) return Future.error(StateError('Render queue is closed'));
    final completer = Completer<RenderJobState>();
    _states[job.id] = const RenderJobState(id: 'pending', status: RenderStatus.queued);
    _pending.add(job);
    _pending.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    _pump(completer, job.id);
    return completer.future;
  }

  Future<void> close() async {
    _closed = true;
    _pending.clear();
  }

  void _pump(Completer<RenderJobState> completer, String targetId) {
    while (_running < maxConcurrent && _pending.isNotEmpty) {
      final job = _pending.removeAt(0);
      _running++;
      _run(job).then((state) {
        _states[job.id] = state;
        if (job.id == targetId && !completer.isCompleted) completer.complete(state);
      }).catchError((Object error, StackTrace stack) {
        final state = RenderJobState(id: job.id, status: RenderStatus.failed);
        _states[job.id] = state;
        if (job.id == targetId && !completer.isCompleted) completer.complete(state);
      }).whenComplete(() {
        _running--;
        if (!_closed) _pump(completer, targetId);
      });
    }
  }

  Future<RenderJobState> _run(RenderJob job) async {
    _states[job.id] = RenderJobState(id: job.id, status: RenderStatus.rendering);
    final result = await engine.render(job.request);
    return RenderJobState(id: job.id, status: result.status, result: result);
  }
}
