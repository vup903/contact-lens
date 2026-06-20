import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LocalOcrAdapter {
  const LocalOcrAdapter();

  Future<String> recognizeImagePath(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text;
    } finally {
      await recognizer.close();
    }
  }
}

