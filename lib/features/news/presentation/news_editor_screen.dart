import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/news_post.dart';
import '../../auth/domain/auth_providers.dart';
import '../domain/news_providers.dart';

/// Create/edit form for a news post. Pass [postId] to edit an existing post,
/// or leave it null to create a new one.
class NewsEditorScreen extends ConsumerStatefulWidget {
  const NewsEditorScreen({super.key, this.postId});

  final String? postId;

  @override
  ConsumerState<NewsEditorScreen> createState() => _NewsEditorScreenState();
}

class _NewsEditorScreenState extends ConsumerState<NewsEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  String? _newPostId;
  String? _imageUrl;
  XFile? _pickedImage;
  NewsPost? _loadedFor;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.postId != null;

  String _postId() {
    if (widget.postId != null) return widget.postId!;
    return _newPostId ??= ref.read(newsRepositoryProvider).newPostId();
  }

  void _syncFromExisting(NewsPost post) {
    if (_loadedFor?.id == post.id) return;
    _loadedFor = post;
    _titleCtrl.text = post.title;
    _bodyCtrl.text = post.body;
    _imageUrl = post.imageUrl;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file != null) setState(() => _pickedImage = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = _postId();
      var imageUrl = _imageUrl;
      if (_pickedImage != null) {
        imageUrl = await ref.read(newsImageRepositoryProvider).uploadNewsImage(id, _pickedImage!);
      }

      if (_isEditing) {
        await ref.read(newsRepositoryProvider).updatePost(id, {
          'title': _titleCtrl.text.trim(),
          'body': _bodyCtrl.text.trim(),
          'imageUrl': imageUrl,
        });
      } else {
        final me = ref.read(currentAppUserProvider).value;
        await ref.read(newsRepositoryProvider).createPost(NewsPost(
              id: id,
              title: _titleCtrl.text.trim(),
              body: _bodyCtrl.text.trim(),
              authorId: me?.uid ?? '',
              authorName: me?.name ?? '',
              imageUrl: imageUrl,
            ));
      }

      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Could not save post: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final feedAsync = ref.watch(newsFeedProvider);
      return feedAsync.when(
        data: (posts) {
          final post = posts.firstWhereOrNull((p) => p.id == widget.postId);
          if (post == null) {
            return Scaffold(appBar: AppBar(), body: const Center(child: Text('Post not found.')));
          }
          _syncFromExisting(post);
          return _buildForm(context);
        },
        loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Error: $err'))),
      );
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Post' : 'New Post')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _pickedImage != null
                            ? const Center(child: Text('New image selected'))
                            : (_imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(_imageUrl!, fit: BoxFit.cover, width: double.infinity),
                                  )
                                : const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 40))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bodyCtrl,
                    decoration: const InputDecoration(labelText: 'Body', alignLabelWithHint: true),
                    minLines: 6,
                    maxLines: 16,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEditing ? 'Save Changes' : 'Publish'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
