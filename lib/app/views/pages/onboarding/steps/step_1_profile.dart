import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../controllers/onboarding_controller.dart';
import '../../../widgets/mascot_widget.dart';

class Step1Profile extends StatelessWidget {
  const Step1Profile({super.key});

  @override
  Widget build(BuildContext context) {
    // Find the controller we created in the parent page
    final OnboardingController controller = Get.find();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 🦊 1. THE FOX SPEAKS
          const MascotWidget(
            emotion: 'happy',
            message: "Hi! I'm Hobie. Before we start your adventure, I need to know who you are!",
          ),
          const SizedBox(height: 30),

          // 2. FORM INPUTS
          TextField(
            controller: controller.nickname,
            decoration: const InputDecoration(
              labelText: "Hero Name (Nickname)",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: controller.age,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Age",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cake_outlined),
            ),
          ),
          const SizedBox(height: 20),

          // 3. GENDER DROPDOWN
          Obx(() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: controller.selectedGender.value,
                isExpanded: true,
                items: ["Male", "Female", "Other"].map((String val) {
                  return DropdownMenuItem(value: val, child: Text(val));
                }).toList(),
                onChanged: (value) => controller.selectedGender.value = value!,
              ),
            ),
          )),
          
          const SizedBox(height: 40),

          // 4. NEXT BUTTON
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                // Simple validation
                if (controller.nickname.text.isEmpty) {
                  Get.snackbar("Hobie says:", "Please tell me your name!", 
                    icon: const Icon(Icons.error, color: Colors.white),
                    backgroundColor: Colors.orange, colorText: Colors.white);
                } else {
                  controller.nextPage(); // Turn the page ->
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text("NEXT STEP"),
            ),
          ),
        ],
      ),
    );
  }
}