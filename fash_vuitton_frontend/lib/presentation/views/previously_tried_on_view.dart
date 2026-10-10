import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/custom_app_bar.dart';

class PreviouslyTriedOnView extends StatefulWidget {
  const PreviouslyTriedOnView({super.key});

  @override
  State<PreviouslyTriedOnView> createState() => _PreviouslyTriedOnViewState();
}

class _PreviouslyTriedOnViewState extends State<PreviouslyTriedOnView> {
  final LocalStorageService _storage = LocalStorageService();
  late Future<List<LocalTryOnResult>> _results;

  @override
  void initState() {
    super.initState();
    _results = _storage.getTryOnResults();
  }

  void _refreshResults() {
    final results = _storage.getTryOnResults();
    if (!mounted) return;
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue,
      drawer: const AppDrawer(selectedItem: 'Previously tried on images'),
      body: SafeArea(
        child: Column(
          children: [
            const CustomAppBar(title: 'Previously tried on images'),
            Expanded(
              child: FutureBuilder<List<LocalTryOnResult>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _MessageState(
                      message: 'Could not load saved try-on images.',
                      onRetry: _refreshResults,
                    );
                  }
                  final results = snapshot.data ?? [];
                  if (results.isEmpty) {
                    return const _MessageState(
                      message: 'No saved try-on images yet.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      final refreshed = _storage.getTryOnResults();
                      if (mounted) setState(() => _results = refreshed);
                      await refreshed;
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.78,
                          ),
                      itemCount: results.length,
                      itemBuilder: (_, index) =>
                          _HistoryResultCard(result: results[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _MessageState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _HistoryResultCard extends StatelessWidget {
  final LocalTryOnResult result;

  const _HistoryResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final heroTag = 'local-try-on-result-${result.id}';
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              _FullScreenResult(result: result, heroTag: heroTag),
        ),
      ),
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.memory(
            result.bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: AppColors.white,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenResult extends StatelessWidget {
  final LocalTryOnResult result;
  final String heroTag;

  const _FullScreenResult({required this.result, required this.heroTag});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: AppColors.white,
        ),
        body: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              child: Image.memory(
                result.bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.white,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      );
}
