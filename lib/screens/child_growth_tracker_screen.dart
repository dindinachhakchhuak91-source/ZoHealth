import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/nutrition_persistence_service.dart';

enum GrowthTrackerView { log, percentile, insights, notes }

class ChildGrowthTrackerScreen extends StatefulWidget {
  final GrowthTrackerView initialView;

  const ChildGrowthTrackerScreen({
    super.key,
    this.initialView = GrowthTrackerView.log,
  });

  @override
  State<ChildGrowthTrackerScreen> createState() =>
      _ChildGrowthTrackerScreenState();
}

class _ChildGrowthTrackerScreenState extends State<ChildGrowthTrackerScreen> {
  static const _entriesKey = 'growth_tracker_entries';
  static const _notesKey = 'growth_tracker_notes';
  static const _notesArchiveKey = 'growth_tracker_notes_archive';

  final _heightController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  final _notesController = TextEditingController();

  GrowthTrackerView _view = GrowthTrackerView.log;
  bool _useFeet = false;
  bool _usePounds = false;
  bool _loading = true;
  final NutritionPersistenceService _persistence =
      NutritionPersistenceService.instance;
  String? _lastLoadedUserId;
  List<_TrackedProfile> _trackedProfiles = [];
  String? _selectedProfileId;
  Map<String, List<_GrowthEntry>> _entriesByProfile = {};
  Map<String, List<_SavedNote>> _savedNotesByProfile = {};
  Map<String, String> _percentileResultsByProfile = {};
  Map<String, String> _sexByProfile = {};

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (_lastLoadedUserId != userId) {
      _lastLoadedUserId = userId;
      _loadData();
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static const String _defaultPercentileMessage =
      'Press Calculate to check growth percentage from your latest two logs.';

  _TrackedProfile get _selectedProfile {
    return _trackedProfiles.firstWhere(
      (profile) => profile.id == _selectedProfileId,
      orElse: () => _trackedProfiles.first,
    );
  }

  List<_GrowthEntry> get _entries =>
      _entriesByProfile[_selectedProfileId] ?? const <_GrowthEntry>[];

  List<_SavedNote> get _savedNotes =>
      _savedNotesByProfile[_selectedProfileId] ?? const <_SavedNote>[];

  String get _sex => _sexByProfile[_selectedProfileId] ?? 'Female';

  String get _percentileResult =>
      _percentileResultsByProfile[_selectedProfileId] ??
      _defaultPercentileMessage;

  void _updateSelectedProfileState({
    List<_GrowthEntry>? entries,
    List<_SavedNote>? notes,
    String? sex,
    String? percentileResult,
  }) {
    final profileId = _selectedProfileId;
    if (profileId == null) return;
    if (entries != null) {
      _entriesByProfile[profileId] = entries;
    }
    if (notes != null) {
      _savedNotesByProfile[profileId] = notes;
    }
    if (sex != null) {
      _sexByProfile[profileId] = sex;
    }
    if (percentileResult != null) {
      _percentileResultsByProfile[profileId] = percentileResult;
    }
  }

  Future<void> _loadData() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    final prefs = await SharedPreferences.getInstance();
    final remoteState = await _persistence.loadGrowthTrackerState(userId);
    final trackedProfilesState = await _persistence.loadTrackedProfilesState(userId);
    final rawEntries = prefs.getString(_entriesKey);
    final rawNotes = prefs.getString(_notesKey) ?? '';
    final rawNotesArchive = prefs.getString(_notesArchiveKey);

    final parsedEntries = rawEntries == null || rawEntries.isEmpty
        ? <_GrowthEntry>[]
        : (jsonDecode(rawEntries) as List)
            .map((item) => _GrowthEntry.fromJson(Map<String, dynamic>.from(item)))
            .toList();

    final parsedNotes = rawNotesArchive == null || rawNotesArchive.isEmpty
        ? <_SavedNote>[]
        : (jsonDecode(rawNotesArchive) as List)
            .map((item) => _SavedNote.fromJson(Map<String, dynamic>.from(item)))
            .toList();

    if (parsedNotes.isEmpty && rawNotes.trim().isNotEmpty) {
      parsedNotes.add(
        _SavedNote(
          text: rawNotes.trim(),
          createdAt: DateTime.now(),
        ),
      );
      await prefs.setString(
        _notesArchiveKey,
        jsonEncode(parsedNotes.map((note) => note.toJson()).toList()),
      );
    }

    final remoteEntries = _parseGrowthEntries(remoteState?['entries']);
    final remoteNotes = _parseSavedNotes(remoteState?['notes_archive']);
    final remoteProfiles = _parseTrackedProfiles(
      trackedProfilesState?['tracked_profiles'],
    );
    final trackedProfiles = remoteProfiles.isNotEmpty
        ? remoteProfiles
        : [
            const _TrackedProfile(
              id: 'profile_default',
              name: 'Child 1',
              type: 'Child',
            ),
          ];
    final selectedProfileId =
        trackedProfilesState?['selected_profile_id']?.toString() ??
        trackedProfiles.first.id;

    final parsedEntriesByProfile = _parseEntriesByProfile(
      remoteState?['entries_by_profile'],
    );
    final parsedNotesByProfile = _parseNotesByProfile(
      remoteState?['notes_archive_by_profile'],
    );
    final parsedSexByProfile = _parseStringMap(remoteState?['sex_by_profile']);
    final parsedPercentileByProfile = _parseStringMap(
      remoteState?['percentile_results_by_profile'],
    );

    if (parsedEntriesByProfile.isEmpty && (remoteEntries.isNotEmpty || parsedEntries.isNotEmpty)) {
      parsedEntriesByProfile[selectedProfileId] =
          remoteEntries.isNotEmpty ? remoteEntries : parsedEntries;
    }
    if (parsedNotesByProfile.isEmpty && (remoteNotes.isNotEmpty || parsedNotes.isNotEmpty)) {
      parsedNotesByProfile[selectedProfileId] =
          remoteNotes.isNotEmpty ? remoteNotes : parsedNotes;
    }
    if (parsedSexByProfile.isEmpty) {
      parsedSexByProfile[selectedProfileId] =
          remoteState?['sex']?.toString() ?? 'Female';
    }
    if (parsedPercentileByProfile.isEmpty) {
      parsedPercentileByProfile[selectedProfileId] =
          remoteState?['percentile_result']?.toString() ??
          _defaultPercentileMessage;
    }

    for (final profile in trackedProfiles) {
      parsedEntriesByProfile.putIfAbsent(profile.id, () => <_GrowthEntry>[]);
      parsedNotesByProfile.putIfAbsent(profile.id, () => <_SavedNote>[]);
      parsedSexByProfile.putIfAbsent(profile.id, () => 'Female');
      parsedPercentileByProfile.putIfAbsent(
        profile.id,
        () => _defaultPercentileMessage,
      );
    }

    if (!mounted) return;
    setState(() {
      _trackedProfiles = trackedProfiles;
      _selectedProfileId = trackedProfiles.any((profile) => profile.id == selectedProfileId)
          ? selectedProfileId
          : trackedProfiles.first.id;
      _entriesByProfile = parsedEntriesByProfile;
      _savedNotesByProfile = parsedNotesByProfile;
      _sexByProfile = parsedSexByProfile;
      _percentileResultsByProfile = parsedPercentileByProfile;
      _notesController.clear();
      _loading = false;
    });
  }

  Future<void> _persistRemoteState() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    await _persistence.saveTrackedProfilesState(userId, {
      'tracked_profiles': _trackedProfiles.map((profile) => profile.toJson()).toList(),
      'selected_profile_id': _selectedProfileId,
    });
    await _persistence.saveGrowthTrackerState(userId, {
      'entries_by_profile': _entriesByProfile.map(
        (key, value) => MapEntry(
          key,
          value.map((entry) => entry.toJson()).toList(),
        ),
      ),
      'notes_archive_by_profile': _savedNotesByProfile.map(
        (key, value) => MapEntry(
          key,
          value.map((note) => note.toJson()).toList(),
        ),
      ),
      'sex_by_profile': _sexByProfile,
      'percentile_results_by_profile': _percentileResultsByProfile,
      'entries': _entries.map((entry) => entry.toJson()).toList(),
      'notes_archive': _savedNotes.map((note) => note.toJson()).toList(),
      'sex': _sex,
      'percentile_result': _percentileResult,
      'tracked_profiles': _trackedProfiles.map((profile) => profile.toJson()).toList(),
      'selected_profile_id': _selectedProfileId,
    });
  }

  List<_GrowthEntry> _parseGrowthEntries(dynamic raw) {
    if (raw is! List) return const <_GrowthEntry>[];
    return raw
        .whereType<Map>()
        .map((item) => _GrowthEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<_SavedNote> _parseSavedNotes(dynamic raw) {
    if (raw is! List) return const <_SavedNote>[];
    return raw
        .whereType<Map>()
        .map((item) => _SavedNote.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<_TrackedProfile> _parseTrackedProfiles(dynamic raw) {
    if (raw is! List) return const <_TrackedProfile>[];
    return raw
        .whereType<Map>()
        .map((item) => _TrackedProfile.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Map<String, List<_GrowthEntry>> _parseEntriesByProfile(dynamic raw) {
    if (raw is! Map) return <String, List<_GrowthEntry>>{};
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        _parseGrowthEntries(value),
      ),
    );
  }

  Map<String, List<_SavedNote>> _parseNotesByProfile(dynamic raw) {
    if (raw is! Map) return <String, List<_SavedNote>>{};
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        _parseSavedNotes(value),
      ),
    );
  }

  Map<String, String> _parseStringMap(dynamic raw) {
    if (raw is! Map) return <String, String>{};
    return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _entriesKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
    await _persistRemoteState();
  }

  Future<void> _persistNotesArchive(List<_SavedNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notesArchiveKey,
      jsonEncode(notes.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(_notesKey, notes.isEmpty ? '' : notes.first.text);
    await _persistRemoteState();
  }

  Future<void> _persistTrackedProfiles() async {
    await _persistRemoteState();
  }

  Future<void> _showAddProfileDialog() async {
    final nameController = TextEditingController();
    String profileType = 'Child';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Add Profile',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Emma',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Child', label: Text('Child')),
                  ButtonSegment(value: 'Person', label: Text('Person')),
                ],
                selected: {profileType},
                onSelectionChanged: (selection) {
                  setDialogState(() {
                    profileType = selection.first;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final profile = _TrackedProfile(
                  id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  type: profileType,
                );
                if (!mounted) return;
                setState(() {
                  _trackedProfiles = [..._trackedProfiles, profile];
                  _selectedProfileId = profile.id;
                  _entriesByProfile[profile.id] = <_GrowthEntry>[];
                  _savedNotesByProfile[profile.id] = <_SavedNote>[];
                  _sexByProfile[profile.id] = 'Female';
                  _percentileResultsByProfile[profile.id] =
                      _defaultPercentileMessage;
                  _notesController.clear();
                });
                await _persistTrackedProfiles();
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelectedProfile() async {
    if (_trackedProfiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Keep at least one profile in this account.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    final profile = _selectedProfile;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Delete ${profile.name}?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'All saved growth and micronutrition data for this profile will be removed. This cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red[600]),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final remainingProfiles = _trackedProfiles
        .where((item) => item.id != profile.id)
        .toList();
    final nextProfileId = remainingProfiles.first.id;

    setState(() {
      _trackedProfiles = remainingProfiles;
      _selectedProfileId = nextProfileId;
      _entriesByProfile.remove(profile.id);
      _savedNotesByProfile.remove(profile.id);
      _sexByProfile.remove(profile.id);
      _percentileResultsByProfile.remove(profile.id);
      _notesController.clear();
    });

    await _persistTrackedProfiles();
  }
  Future<void> _saveNotes() async {
    final trimmedNotes = _notesController.text.trim();
    if (trimmedNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a note before saving.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    final note = _SavedNote(text: trimmedNotes, createdAt: DateTime.now());
    final updatedNotes = [note, ..._savedNotes];
    await _persistNotesArchive(updatedNotes);

    if (!mounted) return;

    setState(() {
      _updateSelectedProfileState(notes: updatedNotes);
      _notesController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Note added to archive.', style: GoogleFonts.poppins()),
      ),
    );
  }

  Future<void> _deleteSavedNoteAt(int index) async {
    if (index < 0 || index >= _savedNotes.length) return;

    final updatedNotes = [..._savedNotes]..removeAt(index);
    await _persistNotesArchive(updatedNotes);

    if (!mounted) return;

    setState(() {
      _updateSelectedProfileState(notes: updatedNotes);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Note deleted from archive.', style: GoogleFonts.poppins()),
      ),
    );
  }
  Future<void> _addEntry() async {
    final heightMain = double.tryParse(_heightController.text.trim());
    final weightRaw = double.tryParse(_weightController.text.trim());
    final inchesRaw = _useFeet
        ? double.tryParse(_heightInchesController.text.trim().isEmpty
            ? '0'
            : _heightInchesController.text.trim())
        : 0;

    final invalidHeight = _useFeet
        ? heightMain == null || heightMain <= 0 || inchesRaw == null || inchesRaw < 0
        : heightMain == null || heightMain <= 0;

    if (invalidHeight || weightRaw == null || weightRaw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter valid height and weight.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    final inches = inchesRaw ?? 0;
    final heightCm = _useFeet
        ? (((heightMain * 12) + inches) * 2.54)
        : heightMain;
    final weightKg = _usePounds ? weightRaw * 0.45359237 : weightRaw;
    final updatedEntries = [
      _GrowthEntry(
        date: DateTime.now(),
        heightCm: heightCm,
        weightKg: weightKg,
      ),
      ..._entries,
    ];
    setState(() {
      _updateSelectedProfileState(entries: updatedEntries);
      _heightController.clear();
      _heightInchesController.clear();
      _weightController.clear();
    });

    await _saveEntries();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Growth entry saved.', style: GoogleFonts.poppins()),
      ),
    );
  }

  Future<void> _deleteEntryAt(int index) async {
    if (index < 0 || index >= _entries.length) return;

    setState(() {
      final updatedEntries = [..._entries]..removeAt(index);
      _updateSelectedProfileState(entries: updatedEntries);
    });

    await _saveEntries();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Growth entry deleted.', style: GoogleFonts.poppins()),
      ),
    );
  }
  void _calculatePercentile() {
    if (_entries.length < 2) {
      setState(() {
        _updateSelectedProfileState(
          percentileResult:
              'You need at least 2 logs to calculate percentile growth.',
        );
      });
      return;
    }

    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 2 || age > 18) {
      setState(() {
        _updateSelectedProfileState(
          percentileResult: 'Enter an age between 2 and 18, then tap Calculate.',
        );
      });
      return;
    }

    final sorted = [..._entries]..sort((a, b) => a.date.compareTo(b.date));
    final previous = sorted[sorted.length - 2];
    final latest = sorted.last;

    final heightGrowthPercent = previous.heightCm <= 0
        ? 0.0
        : ((latest.heightCm - previous.heightCm) / previous.heightCm) * 100;
    final weightGrowthPercent = previous.weightKg <= 0
        ? 0.0
        : ((latest.weightKg - previous.weightKg) / previous.weightKg) * 100;

    final meters = latest.heightCm / 100;
    final bmi = latest.weightKg / (meters * meters);
    String bmiStatus;
    if (bmi < 18.5) {
      bmiStatus = 'Underweight';
    } else if (bmi <= 24.9) {
      bmiStatus = 'Healthy';
    } else {
      bmiStatus = 'Overweight';
    }

    final sexLower = _sex.toLowerCase();

    setState(() {
      _updateSelectedProfileState(
        percentileResult:
          'Height gained: ${heightGrowthPercent.toStringAsFixed(1)}%\n'
          'Weight gained: ${weightGrowthPercent.toStringAsFixed(1)}%\n'
          '$age years old $sexLower\n'
          "BMI ${bmi.toStringAsFixed(1)}: ${bmiStatus == 'Healthy' ? 'Healthy' : '$bmiStatus (Not healthy)'}",
      );
    });
  }
  String _buildInsights() {
    if (_entries.length < 2) {
      return 'Log at least two entries to detect growth changes.';
    }

    final sorted = [..._entries]..sort((a, b) => a.date.compareTo(b.date));
    final previous = sorted[sorted.length - 2];
    final latest = sorted.last;

    final days = latest.date.difference(previous.date).inDays.abs().clamp(1, 3650);
    final heightDelta = latest.heightCm - previous.heightCm;
    final weightDelta = latest.weightKg - previous.weightKg;
    final heightPerMonth = heightDelta / days * 30;
    final weightPerMonth = weightDelta / days * 30;

    final flags = <String>[];
    if (heightPerMonth.abs() >= 3.0) {
      flags.add('Height changed quickly (${heightPerMonth.toStringAsFixed(1)} cm/month).');
    }
    if (weightPerMonth.abs() >= 2.0) {
      flags.add('Weight changed quickly (${weightPerMonth.toStringAsFixed(1)} kg/month).');
    }

    if (flags.isEmpty) {
      return 'No sudden growth shifts detected between your latest two logs.';
    }

    return flags.join(' ');
  }

  String _viewLabel(GrowthTrackerView view) {
    switch (view) {
      case GrowthTrackerView.log:
        return 'Log';
      case GrowthTrackerView.percentile:
        return 'Percentile';
      case GrowthTrackerView.insights:
        return 'Insights';
      case GrowthTrackerView.notes:
        return 'Notes';
    }
  }

  IconData _viewIcon(GrowthTrackerView view) {
    switch (view) {
      case GrowthTrackerView.log:
        return Icons.edit_note_rounded;
      case GrowthTrackerView.percentile:
        return Icons.query_stats_rounded;
      case GrowthTrackerView.insights:
        return Icons.insights_rounded;
      case GrowthTrackerView.notes:
        return Icons.note_alt_outlined;
    }
  }

  InputDecoration _inputDecoration({required String label, String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: isDark ? const Color(0xFF14293F) : Colors.white,
      labelStyle: GoogleFonts.poppins(
        color: isDark ? Colors.white70 : const Color(0xFF5A7184),
        fontWeight: FontWeight.w500,
      ),
      hintStyle: GoogleFonts.poppins(
        color: isDark ? Colors.white38 : const Color(0xFF90A4B5),
        fontSize: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2C4A69) : const Color(0xFFD1E1F1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2C4A69) : const Color(0xFFD1E1F1),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFF1563A7), width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _surfaceCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF10253B), Color(0xFF0E1E31)]
              : const [Color(0xFFF5FAFF), Color(0xFFEAF3FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A4566) : const Color(0xFFC7DDF1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _statChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white24 : const Color(0xFFCEE1F4),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1563A7)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : const Color(0xFF5C748A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitSelector({
    required String title,
    required bool rightSelected,
    required String leftLabel,
    required String rightLabel,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white24 : const Color(0xFFCEE1F4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF5C748A),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(value: false, label: Text(leftLabel, softWrap: false)),
              ButtonSegment<bool>(value: true, label: Text(rightLabel, softWrap: false)),
            ],
            selected: {rightSelected},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }

  String _heightDisplay(double heightCm) {
    if (!_useFeet) {
      return '${heightCm.toStringAsFixed(1)} cm';
    }
    final totalInches = heightCm / 2.54;
    final feet = (totalInches / 12).floor();
    final inches = totalInches - (feet * 12);
    return '$feet ft ${inches.toStringAsFixed(1)} in';
  }

  String _weightDisplay(double weightKg) {
    if (!_usePounds) {
      return '${weightKg.toStringAsFixed(1)} kg';
    }
    final pounds = weightKg / 0.45359237;
    return '${pounds.toStringAsFixed(1)} lb';
  }

  Widget _buildLogView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _unitSelector(
                  title: 'Height Unit',
                  rightSelected: _useFeet,
                  leftLabel: 'cm',
                  rightLabel: 'ft/in',
                  onChanged: (value) {
                    setState(() {
                      _useFeet = value;
                      _heightController.clear();
                      _heightInchesController.clear();
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _unitSelector(
                  title: 'Weight Unit',
                  rightSelected: _usePounds,
                  leftLabel: 'kg',
                  rightLabel: 'lb',
                  onChanged: (value) {
                    setState(() {
                      _usePounds = value;
                      _weightController.clear();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_useFeet)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration(label: 'Height (ft)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _heightInchesController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration(label: 'Additional (in)'),
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration(label: 'Height (cm)'),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                _inputDecoration(label: _usePounds ? 'Weight (lb)' : 'Weight (kg)'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _addEntry,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Save Growth Entry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                backgroundColor: const Color(0xFF1563A7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Recent entries',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            Text(
              'No entries yet.',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white70 : Colors.blueGrey[700],
              ),
            )
          else
            ..._entries.take(8).toList().asMap().entries.map(
                  (entry) {
                    final index = entry.key;
                    final logEntry = entry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white24
                              : const Color(0xFFD2E3F2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Color(0xFF1563A7),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${logEntry.date.day}/${logEntry.date.month}/${logEntry.date.year}',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '${_heightDisplay(logEntry.heightCm)}  |  ${_weightDisplay(logEntry.weightKg)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: IconButton(
                                onPressed: () => _deleteEntryAt(index),
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Delete entry',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildProfileSelectorCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking profile',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF5C748A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_selectedProfile.name} (${_selectedProfile.type})',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _showAddProfileDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(
                  'Add',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trackedProfiles.map((profile) {
              final selected = profile.id == _selectedProfileId;
              return ChoiceChip(
                label: Text('${profile.name} (${profile.type})'),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedProfileId = profile.id;
                    _notesController.clear();
                  });
                  _persistTrackedProfiles();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _deleteSelectedProfile,
              icon: const Icon(Icons.delete_outline),
              label: Text(
                'Delete Current Profile',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[600],
                side: BorderSide(color: Colors.red[300]!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentileView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration(label: 'Age (2-18 years)'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Female', label: Text('Female')),
              ButtonSegment(value: 'Male', label: Text('Male')),
            ],
            selected: {_sex},
            onSelectionChanged: (selection) {
              setState(() {
                _updateSelectedProfileState(sex: selection.first);
              });
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _calculatePercentile,
              icon: const Icon(Icons.calculate_outlined),
              label: Text(
                'Calculate',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                backgroundColor: const Color(0xFF1563A7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white24 : const Color(0xFFCDE1F3),
              ),
            ),
            child: Text(
              _percentileResult,
              style: GoogleFonts.poppins(fontSize: 13, height: 1.45),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Uses your latest two logs for growth percentages. You need at least 2 logs for calculation.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.blueGrey[600],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildInsightsView() {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trend Insights',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1563A7),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _buildInsights(),
            style: GoogleFonts.poppins(fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }

  String _formatSavedNoteTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year  $hour:$minute';
  }

  Widget _buildNotesView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _notesController,
            maxLines: 8,
            decoration: _inputDecoration(
              label: 'Pediatric follow-up notes',
              hint: 'Add milestones, concerns, or doctor recommendations...',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveNotes,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                'Save Notes',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                backgroundColor: const Color(0xFF1563A7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_savedNotes.isNotEmpty) const SizedBox(height: 12),
          if (_savedNotes.isNotEmpty)
            Text(
              'Notes archive',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF5C748A),
              ),
            ),
          if (_savedNotes.isNotEmpty) const SizedBox(height: 8),
          ..._savedNotes.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final note = entry.value;

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white24 : const Color(0xFFCDE1F3),
                  ),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    title: Text(
                      _formatSavedNoteTime(note.createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      note.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF5C748A),
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          note.text,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.45,
                            color: isDark ? Colors.white : const Color(0xFF102A43),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _deleteSavedNoteAt(index),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: Text(
                            'Delete',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          style: FilledButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompactWidth = MediaQuery.of(context).size.width < 420;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Child Growth Tracker',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF091525), Color(0xFF102438)]
                      : const [Color(0xFFF3F8FE), Color(0xFFEAF2FB)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileSelectorCard(),
                  const SizedBox(height: 12),
                  Text(
                    'Use the tabs below to log growth, check percentile status, review trends, and keep follow-up notes.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : const Color(0xFF587084),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statChip(
                        label: 'Entries',
                        value: '${_entries.length}',
                        icon: Icons.timeline_rounded,
                      ),
                      const SizedBox(width: 10),
                      _statChip(
                        label: 'Latest update',
                        value: _entries.isEmpty
                            ? 'None'
                            : '${_entries.first.date.day}/${_entries.first.date.month}',
                        icon: Icons.event_available_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<GrowthTrackerView>(
                    style: ButtonStyle(
                      textStyle: WidgetStateProperty.all(
                        GoogleFonts.poppins(
                          fontSize: isCompactWidth ? 11 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      padding: WidgetStateProperty.all(
                        EdgeInsets.symmetric(
                          horizontal: isCompactWidth ? 8 : 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    segments: GrowthTrackerView.values
                        .map(
                          (view) => ButtonSegment(
                            value: view,
                            icon: isCompactWidth ? null : Icon(_viewIcon(view), size: 16),
                            label: Text(
                              _viewLabel(view),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        )
                        .toList(),
                    selected: {_view},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _view = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_view == GrowthTrackerView.log) _buildLogView(),
                  if (_view == GrowthTrackerView.percentile)
                    _buildPercentileView(),
                  if (_view == GrowthTrackerView.insights) _buildInsightsView(),
                  if (_view == GrowthTrackerView.notes) _buildNotesView(),
                ],
              ),
            ),
    );
  }
}

class _SavedNote {
  final String text;
  final DateTime createdAt;

  const _SavedNote({
    required this.text,
    required this.createdAt,
  });

  factory _SavedNote.fromJson(Map<String, dynamic> json) => _SavedNote(
        text: json['text']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'created_at': createdAt.toIso8601String(),
      };
}

class _TrackedProfile {
  final String id;
  final String name;
  final String type;

  const _TrackedProfile({
    required this.id,
    required this.name,
    required this.type,
  });

  factory _TrackedProfile.fromJson(Map<String, dynamic> json) => _TrackedProfile(
        id: json['id']?.toString() ?? 'profile_default',
        name: json['name']?.toString() ?? 'Child 1',
        type: json['type']?.toString() ?? 'Child',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
      };
}

class _GrowthEntry {
  final DateTime date;
  final double heightCm;
  final double weightKg;

  const _GrowthEntry({
    required this.date,
    required this.heightCm,
    required this.weightKg,
  });

  factory _GrowthEntry.fromJson(Map<String, dynamic> json) => _GrowthEntry(
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        heightCm: double.tryParse(json['height_cm']?.toString() ?? '') ?? 0,
        weightKg: double.tryParse(json['weight_kg']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'height_cm': heightCm,
        'weight_kg': weightKg,
      };
}
















































