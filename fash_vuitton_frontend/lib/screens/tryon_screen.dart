import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/picked_image.dart';
import '../../services/image_service.dart';
import '../../services/tryon_service.dart';
import '../../widgets/image_picker_card.dart';
import '../../widgets/result_card.dart';

class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  final _imageService = ImageService();
  final _tryOnService = TryOnService();
  final _descriptionController = TextEditingController();

  PickedImage? _person;
  PickedImage? _garment;
  Uint8List? _result;
  String? _error;
  bool _loading = false;

  bool get _canSubmit => _person != null && _garment != null && !_loading;

  @override
  void dispose() {
    _descriptionController.dispose();
    _tryOnService.dispose();
    super.dispose();
  }

  Future<void> _pickPerson() async {
    final image = await _imageService.pick();
    if (image == null) return;
    setState(() {
      _person = image;
      _result = null;
      _error = null;
    });
  }

  Future<void> _pickGarment() async {
    final image = await _imageService.pick();
    if (image == null) return;
    setState(() {
      _garment = image;
      _result = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final description = _descriptionController.text.trim();
      final bytes = await _tryOnService.tryOn(
        person: _person!,
        garment: _garment!,
        description: description.isEmpty ? 'a piece of clothing' : description,
      );
      if (!mounted) return;
      setState(() => _result = bytes);
    } on TryOnException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Virtual Try-On')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ImagePickerCard(
                      label: 'Your photo',
                      icon: Icons.person_outline,
                      image: _person,
                      onTap: _loading ? null : _pickPerson,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ImagePickerCard(
                      label: 'Garment',
                      icon: Icons.checkroom_outlined,
                      image: _garment,
                      onTap: _loading ? null : _pickGarment,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Garment description',
                  hintText: 'e.g. black round-neck t-shirt',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Try it on'),
              ),
              const SizedBox(height: 24),
              if (_loading) const _LoadingIndicator(),
              if (_error != null) _ErrorMessage(message: _error!),
              if (_result != null) ResultCard(imageBytes: _result!),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          'Generating your try-on. This can take up to a minute.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}
