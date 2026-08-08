import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

class TeacherDiscoveryEditor extends StatefulWidget {
  final TeacherDiscoverySelection initialValue;
  final ValueChanged<TeacherDiscoverySelection> onChanged;
  final bool showValidationHint;

  const TeacherDiscoveryEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.showValidationHint = false,
  });

  @override
  State<TeacherDiscoveryEditor> createState() => _TeacherDiscoveryEditorState();
}

class _TeacherDiscoveryEditorState extends State<TeacherDiscoveryEditor> {
  late Set<String> _services;
  late Map<String, Set<String>> _learnerAudiences;
  late Set<String> _levels;
  late Set<String> _languages;
  String? _primaryLanguage;

  @override
  void initState() {
    super.initState();
    _load(widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant TeacherDiscoveryEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _load(widget.initialValue);
    }
  }

  void _load(TeacherDiscoverySelection value) {
    _services = {...value.services};
    _learnerAudiences = {
      for (final ageGroup in TeacherDiscoveryTaxonomy.ageGroups)
        ageGroup.id: {
          ...?value.learnerAudiences[ageGroup.id]?.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key),
        },
    };
    _levels = {...value.levels};
    _languages = {...value.languages};
    _primaryLanguage = value.primaryLanguage;
  }

  TeacherDiscoverySelection get _value => TeacherDiscoverySelection(
        services: _services,
        learnerAudiences: {
          for (final entry in _learnerAudiences.entries)
            if (entry.value.isNotEmpty)
              entry.key: discoveryFacetFromIds(entry.value),
        },
        levels: _levels,
        languages: _languages,
        primaryLanguage: _primaryLanguage,
      );

  void _toggle(Set<String> values, String id) {
    setState(() {
      if (!values.add(id)) values.remove(id);
      if (identical(values, _languages)) {
        if (_languages.isEmpty) {
          _primaryLanguage = null;
        } else if (!_languages.contains(_primaryLanguage)) {
          _primaryLanguage = _languages.first;
        }
      }
    });
    widget.onChanged(_value);
  }

  void _toggleAudience(String ageGroup, String learnerGender) {
    setState(() {
      final genders = _learnerAudiences.putIfAbsent(ageGroup, () => {});
      if (!genders.add(learnerGender)) genders.remove(learnerGender);
    });
    widget.onChanged(_value);
  }

  @override
  Widget build(BuildContext context) {
    final validationMessage = _value.validationMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DiscoverySection(
          title: 'ماذا تدرّس؟',
          subtitle: 'يمكنك اختيار أكثر من خدمة',
          options: TeacherDiscoveryTaxonomy.services,
          selected: _services,
          onToggle: (id) => _toggle(_services, id),
        ),
        const SizedBox(height: 18),
        _AudienceMatrixSection(
          selected: _learnerAudiences,
          onToggle: _toggleAudience,
        ),
        const SizedBox(height: 18),
        _DiscoverySection(
          title: 'مستويات الطلاب',
          subtitle: 'اختر كل المستويات التي يمكنك التعامل معها',
          options: TeacherDiscoveryTaxonomy.levels,
          selected: _levels,
          onToggle: (id) => _toggle(_levels, id),
        ),
        const SizedBox(height: 18),
        _DiscoverySection(
          title: 'لغات التدريس',
          subtitle: 'اختر اللغات التي تستطيع الشرح والتوجيه بها',
          options: TeacherDiscoveryTaxonomy.languages,
          selected: _languages,
          onToggle: (id) => _toggle(_languages, id),
        ),
        if (_languages.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(
              '${(_languages.toList()..sort()).join(',')}|$_primaryLanguage',
            ),
            initialValue:
                _languages.contains(_primaryLanguage) ? _primaryLanguage : null,
            decoration: const InputDecoration(
              labelText: 'لغة التدريس الأساسية',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.translate_rounded),
            ),
            items: _languages
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(
                      TeacherDiscoveryTaxonomy.label(
                        TeacherDiscoveryTaxonomy.languages,
                        id,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              setState(() => _primaryLanguage = value);
              widget.onChanged(_value);
            },
          ),
        ],
        if (widget.showValidationHint && validationMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            validationMessage,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _AudienceMatrixSection extends StatelessWidget {
  final Map<String, Set<String>> selected;
  final void Function(String ageGroup, String learnerGender) onToggle;

  const _AudienceMatrixSection({
    required this.selected,
    required this.onToggle,
  });

  String _genderLabel(String ageGroup, String gender) {
    return switch ((ageGroup, gender)) {
      ('children', 'male') => 'بنين',
      ('children', 'female') => 'بنات',
      ('teens', 'male') => 'فتيان',
      ('teens', 'female') => 'فتيات',
      ('adults', 'male') => 'رجال',
      ('adults', 'female') => 'نساء',
      (_, 'male') => 'ذكور',
      _ => 'إناث',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'من تدرّس؟',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          'حدد الجنس المناسب داخل كل فئة عمرية بدقة',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 9),
        for (final ageGroup in TeacherDiscoveryTaxonomy.ageGroups) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ageGroup.labelAr,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final gender
                    in TeacherDiscoveryTaxonomy.learnerGenders) ...[
                  FilterChip(
                    label: Text(_genderLabel(ageGroup.id, gender.id)),
                    selected:
                        selected[ageGroup.id]?.contains(gender.id) == true,
                    onSelected: (_) => onToggle(ageGroup.id, gender.id),
                    showCheckmark: true,
                  ),
                  if (gender.id !=
                      TeacherDiscoveryTaxonomy.learnerGenders.last.id)
                    const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DiscoverySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<TeacherDiscoveryOption> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _DiscoverySection({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => FilterChip(
                  label: Text(option.labelAr),
                  selected: selected.contains(option.id),
                  onSelected: (_) => onToggle(option.id),
                  showCheckmark: true,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
