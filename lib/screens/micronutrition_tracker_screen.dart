import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/nutrition_persistence_service.dart';

enum MicronutritionView { nutrients, gaps, reminders }

class MicronutritionTrackerScreen extends StatefulWidget {
  final MicronutritionView initialView;

  const MicronutritionTrackerScreen({
    super.key,
    this.initialView = MicronutritionView.nutrients,
  });

  @override
  State<MicronutritionTrackerScreen> createState() =>
      _MicronutritionTrackerScreenState();
}

class _MicronutritionTrackerScreenState
    extends State<MicronutritionTrackerScreen> {
  static const _checksKey = 'micronutrition_daily_checks';
  static const _checksOrderKey = 'micronutrition_daily_checks_order';
  static const _checksDateKey = 'micronutrition_daily_checks_date';
  static const _gapHistoryKey = 'micronutrition_gap_history';
  static const _remindersKey = 'micronutrition_reminders';
  static const List<String> _defaultTrackItems = [
    'Iron',
    'Calcium',
    'Vitamin D',
    'Vitamin A',
    'Vitamin C',
    'Hydration',
  ];

  final Map<String, bool> _checks = {
    'Iron': false,
    'Calcium': false,
    'Vitamin D': false,
    'Vitamin A': false,
    'Vitamin C': false,
    'Hydration': false,
  };

  MicronutritionView _view = MicronutritionView.nutrients;
  bool _loading = true;
  final NutritionPersistenceService _persistence =
      NutritionPersistenceService.instance;
  String? _lastLoadedUserId;
  Timer? _midnightResetTimer;
  List<_TrackedProfile> _trackedProfiles = [];
  String? _selectedProfileId;
  Map<String, Map<String, bool>> _checksByProfile = {};
  Map<String, List<String>> _checkOrderByProfile = {};
  Map<String, List<_GapRecord>> _gapHistoryByProfile = {};
  Map<String, List<_ReminderItem>> _remindersByProfile = {};
  Map<String, String?> _lastSavedDateByProfile = {};
  Map<String, String?> _gapAuditDateByProfile = {};

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
    _loadData();
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _midnightResetTimer?.cancel();
    super.dispose();
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

  _TrackedProfile get _selectedProfile {
    return _trackedProfiles.firstWhere(
      (profile) => profile.id == _selectedProfileId,
      orElse: () => _trackedProfiles.first,
    );
  }

  Map<String, bool> get _activeChecks =>
      _checksByProfile[_selectedProfileId] ?? <String, bool>{};

  List<String> get _checkOrder =>
      _checkOrderByProfile[_selectedProfileId] ?? _defaultTrackItems;

  List<_GapRecord> get _gapHistory =>
      _gapHistoryByProfile[_selectedProfileId] ?? const <_GapRecord>[];

  List<_ReminderItem> get _reminders =>
      _remindersByProfile[_selectedProfileId] ?? const <_ReminderItem>[];

  String? get _lastSavedDate => _lastSavedDateByProfile[_selectedProfileId];

  int get _gapLogCount => _gapHistory.length;

  void _updateActiveProfileState({
    Map<String, bool>? checks,
    List<String>? checkOrder,
    List<_GapRecord>? gapHistory,
    List<_ReminderItem>? reminders,
    String? lastSavedDate,
    bool setNullLastSavedDate = false,
  }) {
    final profileId = _selectedProfileId;
    if (profileId == null) return;
    if (checks != null) {
      _checksByProfile[profileId] = checks;
    }
    if (checkOrder != null) {
      _checkOrderByProfile[profileId] = checkOrder;
    }
    if (gapHistory != null) {
      _gapHistoryByProfile[profileId] = gapHistory;
    }
    if (reminders != null) {
      _remindersByProfile[profileId] = reminders;
    }
    if (setNullLastSavedDate) {
      _lastSavedDateByProfile[profileId] = null;
    } else if (lastSavedDate != null) {
      _lastSavedDateByProfile[profileId] = lastSavedDate;
    }
  }

  Future<void> _loadData() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    final prefs = await SharedPreferences.getInstance();
    final remoteState = await _persistence.loadMicronutritionTrackerState(userId);
    final trackedProfilesState = await _persistence.loadTrackedProfilesState(userId);

    final rawChecks = prefs.getString(_checksKey);
    final rawChecksOrder = prefs.getStringList(_checksOrderKey);
    final rawGapHistory = prefs.getString(_gapHistoryKey);
    final rawReminders = prefs.getString(_remindersKey);
    final checksDate = prefs.getString(_checksDateKey);

    final localChecks = rawChecks == null || rawChecks.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(rawChecks));
    final localGapHistory = rawGapHistory == null || rawGapHistory.isEmpty
        ? <_GapRecord>[]
        : (jsonDecode(rawGapHistory) as List)
            .map((item) => _GapRecord.fromJson(Map<String, dynamic>.from(item)))
            .toList();
    final remoteGapHistory = (remoteState?['gap_history'] is List)
        ? (remoteState!['gap_history'] as List)
            .whereType<Map>()
            .map((item) => _GapRecord.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <_GapRecord>[];

    final reminders = rawReminders == null || rawReminders.isEmpty
        ? <_ReminderItem>[]
        : (jsonDecode(rawReminders) as List)
            .map((item) =>
                _ReminderItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();

    final remoteReminders = (remoteState?['reminders'] is List)
        ? (remoteState!['reminders'] as List)
            .whereType<Map>()
            .map((item) =>
                _ReminderItem.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <_ReminderItem>[];

    final effectiveSavedDate =
        remoteState?['checks_date']?.toString() ?? checksDate;
    final shouldResetChecks =
        effectiveSavedDate != null && effectiveSavedDate != _todayLabel();

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

    final checksByProfile = _parseChecksByProfile(remoteState?['checks_by_profile']);
    final checkOrderByProfile = _parseStringListMap(
      remoteState?['check_order_by_profile'],
    );
    final gapHistoryByProfile = _parseGapHistoryByProfile(
      remoteState?['gap_history_by_profile'],
    );
    final remindersByProfile = _parseRemindersByProfile(
      remoteState?['reminders_by_profile'],
    );
    final lastSavedDateByProfile = _parseNullableStringMap(
      remoteState?['checks_date_by_profile'],
    );
    final gapAuditDateByProfile = _parseNullableStringMap(
      remoteState?['gap_audit_date_by_profile'],
    );

    final fallbackProfileId = trackedProfiles.any((item) => item.id == selectedProfileId)
        ? selectedProfileId
        : trackedProfiles.first.id;

    if (checksByProfile.isEmpty) {
      final remoteChecks = Map<String, dynamic>.from(remoteState?['checks'] ?? {});
      final localOrder = rawChecksOrder ?? const <String>[];
      final remoteOrder = (remoteState?['check_order'] is List)
          ? (remoteState!['check_order'] as List)
              .map((item) => item.toString())
              .toList()
          : const <String>[];
      final effectiveOrder = remoteOrder.isNotEmpty
          ? remoteOrder
          : (localOrder.isNotEmpty ? localOrder : _defaultTrackItems);
      final mergedChecks = <String, bool>{
        for (final item in effectiveOrder)
          item: (remoteChecks[item] ?? localChecks[item]) == true,
      };
      checksByProfile[fallbackProfileId] = mergedChecks;
      checkOrderByProfile[fallbackProfileId] = effectiveOrder;
      gapHistoryByProfile[fallbackProfileId] =
          remoteGapHistory.isNotEmpty ? remoteGapHistory : localGapHistory;
      remindersByProfile[fallbackProfileId] =
          remoteReminders.isNotEmpty ? remoteReminders : reminders;
      lastSavedDateByProfile[fallbackProfileId] =
          shouldResetChecks ? null : effectiveSavedDate;
    }

    for (final profile in trackedProfiles) {
      final order = checkOrderByProfile.putIfAbsent(
        profile.id,
        () => [..._defaultTrackItems],
      );
      checksByProfile.putIfAbsent(
        profile.id,
        () => {
          for (final item in order) item: false,
        },
      );
      gapHistoryByProfile.putIfAbsent(profile.id, () => <_GapRecord>[]);
      remindersByProfile.putIfAbsent(profile.id, () => <_ReminderItem>[]);
      lastSavedDateByProfile.putIfAbsent(profile.id, () => null);
      gapAuditDateByProfile.putIfAbsent(profile.id, _todayLabel);
    }
    _applyMidnightGapAudit(
      now: DateTime.now(),
      trackedProfiles: trackedProfiles,
      checksByProfile: checksByProfile,
      checkOrderByProfile: checkOrderByProfile,
      gapHistoryByProfile: gapHistoryByProfile,
      lastSavedDateByProfile: lastSavedDateByProfile,
      gapAuditDateByProfile: gapAuditDateByProfile,
    );
    await prefs.remove(_checksKey);
    await prefs.remove(_checksDateKey);

    if (!mounted) return;
    setState(() {
      _trackedProfiles = trackedProfiles;
      _selectedProfileId = fallbackProfileId;
      _checksByProfile = checksByProfile;
      _checkOrderByProfile = checkOrderByProfile;
      _gapHistoryByProfile = gapHistoryByProfile;
      _remindersByProfile = remindersByProfile;
      _lastSavedDateByProfile = lastSavedDateByProfile;
      _gapAuditDateByProfile = gapAuditDateByProfile;
      _loading = false;
    });
    await _persistRemoteState();
    _scheduleMidnightReset();
  }

  String _todayLabel() {
    return _dateLabelFor(DateTime.now());
  }

  String _dateLabelFor(DateTime date) {
    final now = date;
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _applyMidnightGapAudit({
    required DateTime now,
    required List<_TrackedProfile> trackedProfiles,
    required Map<String, Map<String, bool>> checksByProfile,
    required Map<String, List<String>> checkOrderByProfile,
    required Map<String, List<_GapRecord>> gapHistoryByProfile,
    required Map<String, String?> lastSavedDateByProfile,
    required Map<String, String?> gapAuditDateByProfile,
  }) {
    final todayLabel = _dateLabelFor(now);
    final yesterdayLabel = _dateLabelFor(now.subtract(const Duration(days: 1)));

    for (final profile in trackedProfiles) {
      final profileId = profile.id;
      if (gapAuditDateByProfile[profileId] == todayLabel) {
        continue;
      }

      final order = checkOrderByProfile[profileId] ?? [..._defaultTrackItems];
      final checks = checksByProfile[profileId] ??
          {
            for (final item in order) item: false,
          };
      final lastSavedDate = lastSavedDateByProfile[profileId];

      if (lastSavedDate != yesterdayLabel) {
        final missedItems = order.where((item) => checks[item] != true).toList();
        if (missedItems.isNotEmpty) {
          final recordedAt = now.toIso8601String();
          gapHistoryByProfile[profileId] = [
            ...missedItems.map(
              (item) => _GapRecord(label: item, recordedAt: recordedAt),
            ),
            ...(gapHistoryByProfile[profileId] ?? const <_GapRecord>[]),
          ];
        }
      }

      checksByProfile[profileId] = {
        for (final item in order) item: false,
      };
      lastSavedDateByProfile[profileId] = null;
      gapAuditDateByProfile[profileId] = todayLabel;
    }
  }

  void _scheduleMidnightReset() {
    _midnightResetTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightResetTimer = Timer(nextMidnight.difference(now), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final checksByProfile = Map<String, Map<String, bool>>.fromEntries(
        _checksByProfile.entries.map(
          (entry) => MapEntry(entry.key, Map<String, bool>.from(entry.value)),
        ),
      );
      final gapHistoryByProfile = Map<String, List<_GapRecord>>.fromEntries(
        _gapHistoryByProfile.entries.map(
          (entry) => MapEntry(entry.key, List<_GapRecord>.from(entry.value)),
        ),
      );
      final lastSavedDateByProfile = Map<String, String?>.from(_lastSavedDateByProfile);
      final gapAuditDateByProfile = Map<String, String?>.from(_gapAuditDateByProfile);
      _applyMidnightGapAudit(
        now: nextMidnight,
        trackedProfiles: _trackedProfiles,
        checksByProfile: checksByProfile,
        checkOrderByProfile: _checkOrderByProfile,
        gapHistoryByProfile: gapHistoryByProfile,
        lastSavedDateByProfile: lastSavedDateByProfile,
        gapAuditDateByProfile: gapAuditDateByProfile,
      );
      await prefs.remove(_checksKey);
      await prefs.remove(_checksDateKey);
      if (!mounted) return;
      setState(() {
        _checksByProfile = checksByProfile;
        _gapHistoryByProfile = gapHistoryByProfile;
        _lastSavedDateByProfile = lastSavedDateByProfile;
        _gapAuditDateByProfile = gapAuditDateByProfile;
      });
      await _persistRemoteState();
      _scheduleMidnightReset();
    });
  }

  Future<void> _persistRemoteState() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    await _persistence.saveTrackedProfilesState(userId, {
      'tracked_profiles': _trackedProfiles.map((profile) => profile.toJson()).toList(),
      'selected_profile_id': _selectedProfileId,
    });
    await _persistence.saveMicronutritionTrackerState(userId, {
      'checks_by_profile': _checksByProfile,
      'check_order_by_profile': _checkOrderByProfile,
      'checks_date_by_profile': _lastSavedDateByProfile,
      'gap_audit_date_by_profile': _gapAuditDateByProfile,
      'gap_history_by_profile': _gapHistoryByProfile.map(
        (key, value) => MapEntry(
          key,
          value.map((item) => item.toJson()).toList(),
        ),
      ),
      'reminders_by_profile': _remindersByProfile.map(
        (key, value) => MapEntry(
          key,
          value.map((item) => item.toJson()).toList(),
        ),
      ),
      'checks': _activeChecks,
      'check_order': _checkOrder,
      'checks_date': _lastSavedDate,
      'reminders': _reminders.map((item) => item.toJson()).toList(),
      'tracked_profiles': _trackedProfiles.map((profile) => profile.toJson()).toList(),
      'selected_profile_id': _selectedProfileId,
    });
  }

  List<_TrackedProfile> _parseTrackedProfiles(dynamic raw) {
    if (raw is! List) return const <_TrackedProfile>[];
    return raw
        .whereType<Map>()
        .map((item) => _TrackedProfile.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Map<String, Map<String, bool>> _parseChecksByProfile(dynamic raw) {
    if (raw is! Map) return <String, Map<String, bool>>{};
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is Map
            ? value.map((itemKey, itemValue) => MapEntry(itemKey.toString(), itemValue == true))
            : <String, bool>{},
      ),
    );
  }

  Map<String, List<String>> _parseStringListMap(dynamic raw) {
    if (raw is! Map) return <String, List<String>>{};
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is List ? value.map((item) => item.toString()).toList() : <String>[],
      ),
    );
  }

  Map<String, List<_GapRecord>> _parseGapHistoryByProfile(dynamic raw) {
    if (raw is! Map) return <String, List<_GapRecord>>{};
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is List
            ? value
                .whereType<Map>()
                .map((item) => _GapRecord.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : <_GapRecord>[],
      ),
    );
  }

  Map<String, List<_ReminderItem>> _parseRemindersByProfile(dynamic raw) {
    if (raw is! Map) return <String, List<_ReminderItem>>{};
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is List
            ? value
                .whereType<Map>()
                .map((item) => _ReminderItem.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : <_ReminderItem>[],
      ),
    );
  }

  Map<String, String?> _parseNullableStringMap(dynamic raw) {
    if (raw is! Map) return <String, String?>{};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value?.toString()),
    );
  }

  Future<void> _saveChecks() async {
    final now = DateTime.now();
    final dateLabel = _todayLabel();
    final newGapRecords = _gaps()
        .map(
          (item) => _GapRecord(
            label: item,
            recordedAt: now.toIso8601String(),
          ),
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _updateActiveProfileState(
        lastSavedDate: dateLabel,
        gapHistory: [
          ...newGapRecords,
          ..._gapHistory,
        ],
      );
    });

    await _saveChecksStateLocally();
    await _persistRemoteState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Micronutrient check saved for today.',
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }

  Future<void> _saveChecksStateLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_checksKey, jsonEncode(_activeChecks));
    await prefs.setStringList(_checksOrderKey, _checkOrder);
    await prefs.setString(
      _gapHistoryKey,
      jsonEncode(_gapHistory.map((item) => item.toJson()).toList()),
    );

    if (_lastSavedDate == null || _lastSavedDate!.isEmpty) {
      await prefs.remove(_checksDateKey);
    } else {
      await prefs.setString(_checksDateKey, _lastSavedDate!);
    }
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _remindersKey,
      jsonEncode(_reminders.map((item) => item.toJson()).toList()),
    );
    await _persistRemoteState();
  }

  Future<void> _clearGapLog() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Clear gap log?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will remove all logged gap history for ${_selectedProfile.name}.',
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
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (shouldClear != true || !mounted) return;

    setState(() {
      _updateActiveProfileState(gapHistory: <_GapRecord>[]);
    });
    await _saveChecksStateLocally();
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
                  _checkOrderByProfile[profile.id] = [..._defaultTrackItems];
                  _checksByProfile[profile.id] = {
                    for (final item in _defaultTrackItems) item: false,
                  };
                  _gapHistoryByProfile[profile.id] = <_GapRecord>[];
                  _remindersByProfile[profile.id] = <_ReminderItem>[];
                  _lastSavedDateByProfile[profile.id] = null;
                  _gapAuditDateByProfile[profile.id] = _todayLabel();
                });
                await _persistRemoteState();
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
          'All saved micronutrition data for this profile will be removed. This cannot be undone.',
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

    setState(() {
      _trackedProfiles = remainingProfiles;
      _selectedProfileId = remainingProfiles.first.id;
      _checksByProfile.remove(profile.id);
      _checkOrderByProfile.remove(profile.id);
      _gapHistoryByProfile.remove(profile.id);
      _remindersByProfile.remove(profile.id);
      _lastSavedDateByProfile.remove(profile.id);
      _gapAuditDateByProfile.remove(profile.id);
    });

    await _persistRemoteState();
  }

  Future<void> _addReminder() async {
    final labelController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Add Reminder',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: 'Reminder text',
                  hintText: 'Take vitamin D after breakfast',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(
                    'Time: ${selectedTime.format(context)}',
                    style: GoogleFonts.poppins(),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF2C4A69)
                          : const Color(0xFFBED4E9),
                    ),
                  ),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked == null) return;
                    setDialogState(() {
                      selectedTime = picked;
                    });
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final label = labelController.text.trim();
                if (label.isEmpty) {
                  return;
                }

                final navigator = Navigator.of(context);

                setState(() {
                  _updateActiveProfileState(
                    reminders: [
                      _ReminderItem(
                        label: label,
                        hour: selectedTime.hour,
                        minute: selectedTime.minute,
                      ),
                      ..._reminders,
                    ],
                  );
                });

                await _saveReminders();
                if (!mounted) return;
                navigator.pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String? _normalizeTrackLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _showTrackItemDialog({String? existingLabel}) async {
    final controller = TextEditingController(text: existingLabel ?? '');
    final isEditing = existingLabel != null;
    final navigator = Navigator.of(context);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isEditing ? 'Edit Track Item' : 'Add Track Item',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Item name',
            hintText: 'Magnesium',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final normalized = _normalizeTrackLabel(controller.text);
              if (normalized == null) return;

              final duplicate = _checkOrder.any(
                (item) =>
                    item.toLowerCase() == normalized.toLowerCase() &&
                    item != existingLabel,
              );
              if (duplicate) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'That item already exists.',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.red[600],
                  ),
                );
                return;
              }

              setState(() {
                if (existingLabel != null) {
                  final updatedChecks = Map<String, bool>.from(_activeChecks);
                  final currentValue = updatedChecks.remove(existingLabel) ?? false;
                  updatedChecks[normalized] = currentValue;
                  final updatedGapHistory = _gapHistory
                      .map((item) => item.label == existingLabel
                          ? item.copyWith(label: normalized)
                          : item)
                      .toList();
                  final updatedOrder = [..._checkOrder];
                  final index = _checkOrder.indexOf(existingLabel);
                  if (index != -1) {
                    updatedOrder[index] = normalized;
                  }
                  _updateActiveProfileState(
                    checks: updatedChecks,
                    gapHistory: updatedGapHistory,
                    checkOrder: updatedOrder,
                  );
                } else {
                  _updateActiveProfileState(
                    checks: {
                      ..._activeChecks,
                      normalized: false,
                    },
                    checkOrder: [..._checkOrder, normalized],
                  );
                }
              });

              await _saveChecksStateLocally();
              await _persistRemoteState();
              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTrackItem(String label) async {
    setState(() {
      final updatedChecks = Map<String, bool>.from(_activeChecks)..remove(label);
      final updatedOrder = [..._checkOrder]..remove(label);
      final updatedGapHistory =
          _gapHistory.where((item) => item.label != label).toList();
      _updateActiveProfileState(
        checks: updatedChecks,
        checkOrder: updatedOrder,
        gapHistory: updatedGapHistory,
      );
    });
    await _saveChecksStateLocally();
    await _persistRemoteState();
  }
  List<String> _gaps() => _checkOrder
      .where((item) => _activeChecks[item] != true)
      .toList();

  _GapRecord? _latestGapRecordFor(String label) {
    for (final item in _gapHistory) {
      if (item.label == label) {
        return item;
      }
    }
    return null;
  }

  String _formatGapTimestamp(String raw) {
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;

    final hour12 = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final period = parsed.hour >= 12 ? 'PM' : 'AM';
    final minute = parsed.minute.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day at $hour12:$minute $period';
  }

  int get _completedCount =>
      _checkOrder.where((item) => _activeChecks[item] == true).length;

  String _viewLabel(MicronutritionView view) {
    switch (view) {
      case MicronutritionView.nutrients:
        return 'Track';
      case MicronutritionView.gaps:
        return 'Gaps';
      case MicronutritionView.reminders:
        return 'Reminders';
    }
  }

  IconData _viewIcon(MicronutritionView view) {
    switch (view) {
      case MicronutritionView.nutrients:
        return Icons.monitor_heart_outlined;
      case MicronutritionView.gaps:
        return Icons.warning_amber_rounded;
      case MicronutritionView.reminders:
        return Icons.alarm_rounded;
    }
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
              : Colors.white.withValues(alpha: 0.88),
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
                  });
                  _persistRemoteState();
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

  Widget _buildTrackView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _showTrackItemDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                'Add Track Item',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                backgroundColor: isDark
                    ? const Color(0xFF1A3554)
                    : const Color(0xFFE4F0FC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._checkOrder.map(
            (nutrient) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white24 : const Color(0xFFD2E3F2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      title: Text(
                        nutrient,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: _activeChecks[nutrient] ?? false,
                      activeColor: const Color(0xFF1563A7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      onChanged: (value) {
                        setState(() {
                          final updatedChecks =
                              Map<String, bool>.from(_activeChecks);
                          updatedChecks[nutrient] = value == true;
                          _updateActiveProfileState(checks: updatedChecks);
                        });
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit item',
                    onPressed: () => _showTrackItemDialog(existingLabel: nutrient),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF1563A7),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete item',
                    onPressed: () => _deleteTrackItem(nutrient),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveChecks,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                'Save Today Intake',
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _lastSavedDate == null
                  ? 'No daily check saved yet.'
                  : 'Last saved: $_lastSavedDate',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.blueGrey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapsView() {
    final gaps = _gaps();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statChip(
                label: 'Current gaps',
                value: '${gaps.length}',
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(width: 10),
              _statChip(
                label: 'Gap log',
                value: '$_gapLogCount',
                icon: Icons.history_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (gaps.isEmpty)
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF1563A7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Great job. No nutrient gaps flagged in your latest check.',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              'Possible gaps from your latest check',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1563A7),
              ),
            ),
            const SizedBox(height: 12),
            ...gaps.map(
              (item) {
                final gapRecord = _latestGapRecordFor(item);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2B4A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1F4D78)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              gapRecord == null
                                  ? 'Recorded when this gap is saved.'
                                  : 'Recorded: ${_formatGapTimestamp(gapRecord.recordedAt)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          if (_gapHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gap log history',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _clearGapLog,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: Text(
                    'Clear All',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[600],
                    side: BorderSide(color: Colors.red[300]!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._gapHistory.map(
              (item) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white24 : const Color(0xFFD2E3F2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.history_toggle_off_rounded,
                      size: 18,
                      color: Color(0xFF1563A7),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF102A43),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatGapTimestamp(item.recordedAt),
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemindersView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _addReminder,
              icon: const Icon(Icons.alarm_add_outlined),
              label: Text(
                'Add Reminder',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                backgroundColor: isDark
                    ? const Color(0xFF1A3554)
                    : const Color(0xFFE4F0FC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_reminders.isEmpty)
            Text(
              'No reminders yet.',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white70 : Colors.blueGrey[700],
              ),
            )
          else
            ..._reminders.asMap().entries.map(
                  (entry) => Container(
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
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1563A7).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 18,
                            color: Color(0xFF1563A7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${entry.value.label}  (${entry.value.formattedTime})',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            setState(() {
                              final updatedReminders = [..._reminders]
                                ..removeAt(entry.key);
                              _updateActiveProfileState(
                                reminders: updatedReminders,
                              );
                            });
                            await _saveReminders();
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
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
          'Micronutrition Tracker',
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
                    'Track daily nutrient intake, spot gaps, and keep reminders for consistency.',
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
                        label: 'Completed',
                        value: '$_completedCount/${_checks.length}',
                        icon: Icons.verified_rounded,
                      ),
                      const SizedBox(width: 10),
                      _statChip(
                        label: 'Saved',
                        value: _lastSavedDate ?? 'Not yet',
                        icon: Icons.event_available_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<MicronutritionView>(
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
                    segments: MicronutritionView.values
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
                  if (_view == MicronutritionView.nutrients) _buildTrackView(),
                  if (_view == MicronutritionView.gaps) _buildGapsView(),
                  if (_view == MicronutritionView.reminders) _buildRemindersView(),
                ],
              ),
            ),
    );
  }
}

class _GapRecord {
  final String label;
  final String recordedAt;

  const _GapRecord({
    required this.label,
    required this.recordedAt,
  });

  _GapRecord copyWith({
    String? label,
    String? recordedAt,
  }) => _GapRecord(
        label: label ?? this.label,
        recordedAt: recordedAt ?? this.recordedAt,
      );

  factory _GapRecord.fromJson(Map<String, dynamic> json) => _GapRecord(
        label: json['label']?.toString() ?? '',
        recordedAt: json['recorded_at']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'recorded_at': recordedAt,
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

class _ReminderItem {
  final String label;
  final int hour;
  final int minute;

  const _ReminderItem({
    required this.label,
    required this.hour,
    required this.minute,
  });

  String get formattedTime {
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  factory _ReminderItem.fromJson(Map<String, dynamic> json) => _ReminderItem(
        label: json['label']?.toString() ?? '',
        hour: int.tryParse(json['hour']?.toString() ?? '') ?? 8,
        minute: int.tryParse(json['minute']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'hour': hour,
        'minute': minute,
      };
}












































