import 'package:flutter/material.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';
import '../app_state.dart';
import '../widgets/encounter_capture_sheet.dart';
import '../widgets/encounter_timeline.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    required this.appState,
    super.key,
  });

  final ContactLensState appState;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final contacts = widget.appState.contacts.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _HeaderRow(
                count: contacts.length,
                onAdd: () => _showContactEditor(context),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: contacts.isEmpty
                    ? const Center(child: Text('No contacts yet.'))
                    : ListView.separated(
                        itemCount: contacts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          return _ContactCard(
                            contact: contact,
                            onTap: () => _showContactDetail(context, contact),
                            onEdit: () =>
                                _showContactEditor(context, contact: contact),
                            onDelete: () =>
                                widget.appState.deleteContact(contact.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showContactEditor(
    BuildContext context, {
    Contact? contact,
  }) async {
    final result = await showDialog<Contact>(
      context: context,
      builder: (context) => _ContactEditorDialog(contact: contact),
    );
    if (result != null) {
      await widget.appState.upsertContact(result);
    }
  }

  Future<void> _showContactDetail(BuildContext context, Contact contact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactDetailSheet(
        appState: widget.appState,
        contactId: contact.id,
      ),
    );
  }
}

/// Contact detail with the encounter timeline and a one-tap "Add encounter"
/// capture flow. Rebuilds from [ContactLensState] so a freshly captured
/// encounter appears immediately in the timeline.
class _ContactDetailSheet extends StatelessWidget {
  const _ContactDetailSheet({required this.appState, required this.contactId});

  final ContactLensState appState;
  final String contactId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        Contact? contact;
        for (final candidate in appState.contacts) {
          if (candidate.id == contactId) {
            contact = candidate;
            break;
          }
        }
        if (contact == null) {
          return const SizedBox.shrink();
        }
        final resolved = contact;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                children: [
                  Text(resolved.displayName,
                      style: theme.textTheme.headlineSmall),
                  if (resolved.subtitle.isNotEmpty)
                    Text(resolved.subtitle,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                  if (resolved.other.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(resolved.other),
                  ],
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Encounters',
                            style: theme.textTheme.titleMedium),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _addEncounter(context, resolved),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Add encounter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  EncounterTimeline(encounters: resolved.encounters),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addEncounter(BuildContext context, Contact contact) async {
    final reading = await appState.currentLocation();
    if (!context.mounted) {
      return;
    }
    final draft = await showEncounterCaptureSheet(
      context,
      voiceService: appState.voiceCapture,
      reading: reading,
      source: EncounterSource.manual,
    );
    if (draft == null) {
      return;
    }
    await appState.captureEncounter(contact.id, draft);
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.count,
    required this.onAdd,
  });

  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contacts',
                  style: Theme.of(context).textTheme.headlineSmall),
              Text('$count local records indexed for private RAG'),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                child: Text(contact.displayName.characters.first.toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.displayName,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (contact.subtitle.isNotEmpty) Text(contact.subtitle),
                    if (contact.groups.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: contact.groups
                              .map((group) => Chip(
                                  label: Text(group),
                                  visualDensity: VisualDensity.compact))
                              .toList(),
                        ),
                      ),
                    if (contact.other.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          contact.other,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactEditorDialog extends StatefulWidget {
  const _ContactEditorDialog({this.contact});

  final Contact? contact;

  @override
  State<_ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<_ContactEditorDialog> {
  late final TextEditingController name;
  late final TextEditingController company;
  late final TextEditingController jobTitle;
  late final TextEditingController email;
  late final TextEditingController mobilePhone;
  late final TextEditingController phone;
  late final TextEditingController groups;
  late final TextEditingController other;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    name = TextEditingController(text: contact?.name ?? '');
    company = TextEditingController(text: contact?.company ?? '');
    jobTitle = TextEditingController(text: contact?.jobTitle ?? '');
    email = TextEditingController(text: contact?.email ?? '');
    mobilePhone = TextEditingController(text: contact?.mobilePhone ?? '');
    phone = TextEditingController(text: contact?.phone ?? '');
    groups = TextEditingController(text: contact?.groups.join(', ') ?? '');
    other = TextEditingController(text: contact?.other ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    company.dispose();
    jobTitle.dispose();
    email.dispose();
    mobilePhone.dispose();
    phone.dispose();
    groups.dispose();
    other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.contact == null ? 'Add contact' : 'Edit contact'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(name, 'Name'),
              _field(company, 'Company'),
              _field(jobTitle, 'Job title'),
              _field(email, 'Email'),
              _field(mobilePhone, 'Mobile phone'),
              _field(phone, 'Phone'),
              _field(groups, 'Groups (comma separated)'),
              _field(other, 'Notes', maxLines: 4),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final now = DateTime.now().toUtc();
            final contact = Contact(
              id: widget.contact?.id ?? newLocalId('contact'),
              createdAt: widget.contact?.createdAt ?? now,
              updatedAt: now,
              name: name.text.trim(),
              company: company.text.trim(),
              jobTitle: jobTitle.text.trim(),
              email: email.text.trim(),
              mobilePhone: mobilePhone.text.trim(),
              phone: phone.text.trim(),
              groups: groups.text
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList(),
              other: other.text.trim(),
            );
            Navigator.of(context).pop(contact);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
