# Testing

## Automated

```bash
flutter analyze
flutter test
```

## Covered Scenarios

- Tokenizer handles Latin, numbers, and CJK.
- RAG ranks direct field matches.
- RAG returns a no-match fallback without hallucination.
- Manifest rebuilds when contact content changes.
- Manifest rebuilds when fingerprint changes.
- Parser extracts Taiwan business card fields.
- Parser extracts English business card fields without auto-filling website.
- Local repository seeds sample data and persists manifest.

## Manual Checks

- Start Flutter Web and confirm sample contacts load.
- Add, edit, and delete a contact.
- Run the assistant with representative queries.
- Paste OCR text in Scan and save a parsed contact.
- On mobile, test image picker/OCR on a real device.

