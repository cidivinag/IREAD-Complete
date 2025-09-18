import 'package:flutter/material.dart';

class AssessmentBreakdownDialog extends StatelessWidget {
  final String recognizedText;
  final double accuracyScore;
  final double completenessScore;
  final VoidCallback onClose;

  const AssessmentBreakdownDialog({
    Key? key,
    required this.recognizedText,
    required this.accuracyScore,
    required this.completenessScore,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFF5E8C7),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assessment Breakdown',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF8B4513),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recognized Text: $recognizedText',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                color: Color(0xFF8B4513),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Accuracy Score: ${accuracyScore.toStringAsFixed(1)}',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                color: Color(0xFF8B4513),
              ),
            ),
            Text(
              'Completeness Score: ${completenessScore.toStringAsFixed(1)}',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                color: Color(0xFF8B4513),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onClose();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Color(0xFF8B4513),
                  textStyle: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
