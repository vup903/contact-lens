class LocalOcrAdapter {
  const LocalOcrAdapter();

  Future<String> recognizeImagePath(String imagePath) async {
    throw UnsupportedError(
      'Local OCR is only available on mobile builds. Paste OCR text in the web demo.',
    );
  }
}

