# Scanning

Contact Lens follows the original Bizcard scanning idea:

1. Capture or select an image.
2. Run local OCR when available.
3. Parse OCR text with business-card heuristics.
4. Let the user confirm and edit fields.
5. Save the contact.

## Parser Fields

The parser extracts:

- name
- company
- job title
- phone
- mobile phone
- fax
- email
- address
- raw OCR text

It intentionally does not auto-fill website in v1, matching the Bizcard
requirement that website extraction should not be over-eager.

## OCR

Mobile builds can use the local ML Kit text-recognition adapter. Web builds use
manual paste fallback for the demo. This keeps the project free from paid model
APIs and avoids sending business cards to a remote model service.

## Known Limits

- OCR quality depends on image sharpness, contrast, and text orientation.
- Business card layouts vary widely; parser results should always be reviewed.
- Mobile platform setup may require native plugin configuration.

