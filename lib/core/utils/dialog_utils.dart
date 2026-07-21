import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/color_constants.dart';

/// Standardized dialog and snackbar utilities for the entire app.
/// All dialogs share consistent styling: 16px rounded corners,
/// AppColors buttons, and the same text/color hierarchy.
class AppDialogs {
  static Widget _buildContainer({required Widget child}) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }


  /// Shows a non-dismissible loading dialog with the given [message].
  static void showLoading({String message = 'Loading...'}) {
    Get.dialog(
      _buildContainer(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Dismisses the loading dialog opened by [showLoading].
  static void dismissLoading() {
    if (Get.isDialogOpen == true) Get.back();
  }


  /// Standard confirm/cancel dialog. Returns `true` when confirmed.
  static Future<bool?> confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Color? confirmColor,
  }) {
    return Get.dialog<bool>(
      _buildContainer(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: Text(
                      cancelLabel,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Get.back(result: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor ?? AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Danger-style confirmation that requires the user to type
  /// [confirmText] into a text field before proceeding.
  /// Returns `true` when the correct text is entered and confirmed.
  static Future<bool?> dangerConfirm({
    required String title,
    required String message,
    required String confirmText,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
  }) {
    final textController = TextEditingController();
    return Get.dialog<bool>(
      _buildContainer(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Type $confirmText to confirm:',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: Text(
                      cancelLabel,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      if (textController.text.trim() != confirmText) return;
                      Get.back(result: true);
                    },
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }


  /// Shows a dialog with a text field. Returns the entered text
  /// when confirmed, or `null` if cancelled.
  ///
  /// [validator] is called on every change; return an error string to
  /// show inline, or `null` if the input is valid. The confirm button
  /// is disabled while the value is invalid.
  static Future<String?> input({
    required String title,
    String initialValue = '',
    String hintText = '',
    TextInputType keyboardType = TextInputType.text,
    String confirmLabel = 'Save',
    String cancelLabel = 'Cancel',
    String? Function(String?)? validator,
  }) {
    final textController = TextEditingController(text: initialValue);
    return Get.dialog<String>(
      _buildContainer(
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final errorText = validator != null ? validator(textController.text) : null;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    keyboardType: keyboardType,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      errorText: errorText,
                      errorMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Get.back<String>(),
                        child: Text(
                          cancelLabel,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: errorText != null
                            ? null
                            : () => Get.back(result: textController.text.trim()),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(confirmLabel),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      barrierDismissible: false,
    );
  }


  /// Wraps custom [builder] content inside the standard dialog
  /// container. Use this for complex dialogs (feedback, share, etc.)
  static Future<T?> custom<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = false,
  }) {
    return Get.dialog<T>(
      _buildContainer(child: builder(Get.context!)),
      barrierDismissible: barrierDismissible,
    );
  }


  /// Shows a dialog with a date picker button. Returns the selected
  /// date as `YYYY-MM-DD`, or `null` if cancelled.
  static Future<String?> datePicker({
    required String title,
    String initialValue = '',
    DateTime? firstDate,
    DateTime? lastDate,
    String confirmLabel = 'Save',
    String cancelLabel = 'Cancel',
  }) {
    final now = DateTime.now();
    DateTime selectedDate;
    if (initialValue.isNotEmpty) {
      selectedDate = DateTime.tryParse(initialValue) ??
          DateTime(now.year - 30, now.month, now.day);
    } else {
      selectedDate = DateTime(now.year - 30, now.month, now.day);
    }
    final minDate = firstDate ?? DateTime(now.year - 150, 1, 1);
    final maxDate = lastDate ?? now;
    if (selectedDate.isBefore(minDate)) selectedDate = minDate;
    if (selectedDate.isAfter(maxDate)) selectedDate = maxDate;

    return Get.dialog<String>(
      _buildContainer(
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            final formatted =
                '${selectedDate.year.toString().padLeft(4, '0')}-'
                '${selectedDate.month.toString().padLeft(2, '0')}-'
                '${selectedDate.day.toString().padLeft(2, '0')}';

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    readOnly: true,
                    controller: TextEditingController(text: formatted),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.calendar_month_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: minDate,
                        lastDate: maxDate,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context)
                                  .colorScheme
                                  .copyWith(primary: AppColors.primary),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setLocalState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Get.back<String>(),
                        child: Text(
                          cancelLabel,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Get.back<String>(result: formatted),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(confirmLabel),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      barrierDismissible: false,
    );
  }


  /// Green success toast.
  static void success(
    String title,
    String message, {
    int durationSeconds = 2,
  }) {
    Get.snackbar(
      title,
      message,
      backgroundColor: AppColors.success,
      colorText: AppColors.textOnPrimary,
      duration: Duration(seconds: durationSeconds),
    );
  }

  /// Red error toast.
  static void error(
    String title,
    String message, {
    int durationSeconds = 2,
  }) {
    Get.snackbar(
      title,
      message,
      backgroundColor: AppColors.error,
      colorText: AppColors.textOnPrimary,
      duration: Duration(seconds: durationSeconds),
    );
  }

  /// Amber warning toast.
  static void warning(
    String title,
    String message, {
    int durationSeconds = 3,
  }) {
    Get.snackbar(
      title,
      message,
      backgroundColor: AppColors.warning,
      colorText: AppColors.textOnPrimary,
      duration: Duration(seconds: durationSeconds),
    );
  }

  /// Primary-coloured info toast.
  static void info(
    String title,
    String message, {
    int durationSeconds = 2,
  }) {
    Get.snackbar(
      title,
      message,
      backgroundColor: AppColors.primary,
      colorText: AppColors.textOnPrimary,
      duration: Duration(seconds: durationSeconds),
    );
  }
}
