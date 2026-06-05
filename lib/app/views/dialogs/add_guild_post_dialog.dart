import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/guild_controller.dart';
import '../../models/category_model.dart';
import '../../../core/constants/color_constants.dart';

class AddGuildPostDialog extends StatefulWidget {
  final List<CategoryModel> categories;
  final List<String> hobbies;

  const AddGuildPostDialog({
    required this.categories,
    required this.hobbies,
    super.key,
  });

  @override
  State<AddGuildPostDialog> createState() => _AddGuildPostDialogState();
}

class _AddGuildPostDialogState extends State<AddGuildPostDialog> {
  late final GuildController _guildController;

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedHobby;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _guildController = Get.find<GuildController>();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (_selectedCategoryId == null ||
        _selectedHobby == null ||
        _titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      Get.snackbar(
        'Incomplete Form',
        'Please fill in all fields',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final postId = await _guildController.addPost(
      hobby: _selectedHobby!,
      categoryId: _selectedCategoryId!,
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (postId != null) {
      Get.back();
      Get.snackbar(
        'Post Created',
        'Your post has been shared with the guild!',
        backgroundColor: AppColors.success,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Error',
        'Failed to create post. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Share with Guild',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Category Dropdown
              Text(
                'Category',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                hint: const Text('Select a category'),
                items: widget.categories
                    .map((category) => DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedCategoryId = value);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Hobby Dropdown
              Text(
                'Hobby',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedHobby,
                hint: const Text('Select your hobby'),
                items: widget.hobbies
                    .map((hobby) => DropdownMenuItem(
                      value: hobby,
                      child: Text(hobby),
                    ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedHobby = value);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Title Input
              Text(
                'Title',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'What is your post about?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 20),

              // Body Input
              Text(
                'Content',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bodyController,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts, tips, or experiences...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submitPost,
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Post'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
