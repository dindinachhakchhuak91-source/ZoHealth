import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/section_content_item.dart';
import '../models/section_item.dart';
import '../models/slide_item.dart';
import '../models/user_question.dart';
import '../services/supabase_service.dart';

class ContentProvider with ChangeNotifier {
  static const String _sectionContentStorageKey = 'section_content_items';
  static const String _slidesStorageKey = 'slides_items';
  static const String _questionsStorageKey = 'user_questions_items';
  static const String _adsStorageKey = 'ads_items';

  final List<SlideItem> _slides = [];

  final List<SectionItem> _sections = [
    SectionItem(
      id: 'sec_health',
      title: 'Health Tips',
      icon: Icons.favorite_border,
      route: '/section/health-tips',
    ),
    SectionItem(
      id: 'sec_vaccines',
      title: 'Vaccines',
      icon: Icons.vaccines,
      route: '/section/vaccines',
    ),
    SectionItem(
      id: 'sec_schemes',
      title: 'Schemes',
      icon: Icons.volunteer_activism,
      route: '/section/schemes',
    ),
    SectionItem(
      id: 'sec_reminders',
      title: 'Reminders',
      icon: Icons.notifications,
      route: '/section/reminders',
    ),
    SectionItem(
      id: 'sec_danger',
      title: 'Danger Signs',
      icon: Icons.warning_amber_outlined,
      route: '/section/danger-signs',
    ),
    SectionItem(
      id: 'sec_qa',
      title: 'Q&A',
      icon: Icons.question_answer,
      route: '/section/q-and-a',
    ),
  ];

  final List<SectionContentItem> _sectionContent = [
    SectionContentItem(
      id: 'content_health_1',
      sectionId: 'sec_health',
      title: 'Daily Health Tips',
      description:
          'Stay healthy with our daily tips. Drink plenty of water, exercise regularly, and get enough sleep.',
      bulletPoints: [
        'Drink 8-10 glasses of water daily',
        'Exercise for at least 30 minutes',
        'Get 7-8 hours of quality sleep',
        'Eat a balanced diet rich in fruits and vegetables',
        'Practice meditation or yoga',
      ],
      backgroundColor: Colors.blue,
    ),
    SectionContentItem(
      id: 'content_vaccines_1',
      sectionId: 'sec_vaccines',
      title: 'Vaccination Schedule',
      description:
          'Follow the recommended vaccination schedule to protect yourself and your family from preventable diseases.',
      bulletPoints: [
        'Infant vaccines (0-6 months)',
        'Childhood vaccines (6-18 months)',
        'School vaccines (6-18 years)',
        'Adult boosters',
        'Special vaccines for high-risk groups',
      ],
      backgroundColor: Colors.green,
    ),
    SectionContentItem(
      id: 'content_schemes_1',
      sectionId: 'sec_schemes',
      title: 'Government Health Schemes',
      description:
          'Avail benefits from various government health schemes and programs.',
      bulletPoints: [
        'Ayushman Bharat - PM-JAY',
        'RSBY - Rashtriya Swasthya Bima Yojana',
        'PMJAY benefits & eligibility',
        'How to register',
        'Health services covered',
      ],
      backgroundColor: Colors.amber,
    ),
    SectionContentItem(
      id: 'content_reminders_1',
      sectionId: 'sec_reminders',
      title: 'Health Reminders',
      description:
          'Important reminders for your health and wellness throughout the day.',
      bulletPoints: [
        'Morning: Drink warm water with lemon',
        'Midday: Take a 15-minute walk',
        'Afternoon: Take your medications',
        'Evening: Practice breathing exercises',
        'Night: Prepare for quality sleep',
      ],
      backgroundColor: Colors.purple,
    ),
    SectionContentItem(
      id: 'content_danger_1',
      sectionId: 'sec_danger',
      title: 'Warning Signs to Watch',
      description:
          'Recognize these danger signs and seek medical help immediately.',
      bulletPoints: [
        'Severe chest pain or pressure',
        'Difficulty breathing or shortness of breath',
        'Sudden severe headache',
        'Loss of consciousness',
        'Severe allergic reactions',
      ],
      backgroundColor: Colors.red,
    ),
    SectionContentItem(
      id: 'content_qa_1',
      sectionId: 'sec_qa',
      title: 'Frequently Asked Questions',
      description:
          'Common questions about health and wellness answered by our experts.',
      bulletPoints: [
        'How often should I visit a doctor?',
        'What is the recommended diet?',
        'When should I get vaccinated?',
        'How to maintain mental health?',
        'What exercise is best for me?',
      ],
      backgroundColor: Colors.teal,
    ),
  ];

  final List<UserQuestion> _userQuestions = [];
  final List<Map<String, String>> _ads = [];
  bool _isInitialized = false;

  ContentProvider() {
    _initializeContent();
  }

  List<SlideItem> get slides => List.unmodifiable(_slides);
  List<SectionItem> get sections => List.unmodifiable(_sections);
  List<SectionContentItem> get sectionContent => List.unmodifiable(_sectionContent);
  List<Map<String, String>> get ads => List.unmodifiable(_ads);
  List<UserQuestion> get userQuestions => List.unmodifiable(_userQuestions);
  bool get isInitialized => _isInitialized;

  SectionContentItem? getContentForSection(String sectionId) {
    try {
      return _sectionContent.firstWhere((content) => content.sectionId == sectionId);
    } catch (_) {
      return null;
    }
  }

  List<SectionContentItem> getContentListForSection(String sectionId) {
    return _sectionContent.where((content) => content.sectionId == sectionId).toList();
  }

  Future<void> _initializeContent() async {
    await _loadSlidesFromLocal();
    await _loadAdsFromLocal();
    await _loadQuestionsFromLocal();
    await _loadSectionContentFromLocal();

    await _loadSlidesFromSupabase();
    await _loadAdsFromSupabase();
    await _loadQuestionsFromSupabase();
    await _loadSectionContentFromSupabase();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadSlidesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedItems = prefs.getString(_slidesStorageKey);
      if (encodedItems == null || encodedItems.isEmpty) return;

      final decodedItems = jsonDecode(encodedItems);
      if (decodedItems is! List) return;

      _slides
        ..clear()
        ..addAll(
          decodedItems
              .whereType<Map>()
              .map((item) => SlideItem.fromJson(Map<String, dynamic>.from(item))),
        );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadSlidesFromSupabase() async {
    try {
      final rows = await SupabaseService.instance.select('slides');
      if (rows.isEmpty) {
        await _saveSlidesLocally();
        return;
      }

      _slides
        ..clear()
        ..addAll(rows.map(SlideItem.fromJson));
      await _saveSlidesLocally();
      notifyListeners();
    } catch (_) {
      await _saveSlidesLocally();
    }
  }

  Future<void> _loadSectionContentFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedItems = prefs.getString(_sectionContentStorageKey);
      if (encodedItems == null || encodedItems.isEmpty) return;

      final decodedItems = jsonDecode(encodedItems);
      if (decodedItems is! List) return;

      _sectionContent
        ..clear()
        ..addAll(
          decodedItems.whereType<Map>().map(
                (item) => SectionContentItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
        );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadSectionContentFromSupabase() async {
    try {
      final rows = await SupabaseService.instance.select('section_content');
      if (rows.isEmpty) {
        await _seedDefaultSectionContent();
        return;
      }

      _sectionContent
        ..clear()
        ..addAll(rows.map(SectionContentItem.fromJson));
      await _saveSectionContentLocally();
      notifyListeners();
    } catch (_) {
      await _saveSectionContentLocally();
    }
  }

  Future<void> _seedDefaultSectionContent() async {
    try {
      for (final content in List<SectionContentItem>.from(_sectionContent)) {
        await SupabaseService.instance.upsert('section_content', content.toJson());
      }
    } catch (_) {}

    await _saveSectionContentLocally();
  }

  Future<void> _loadQuestionsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedItems = prefs.getString(_questionsStorageKey);
      if (encodedItems == null || encodedItems.isEmpty) return;

      final decodedItems = jsonDecode(encodedItems);
      if (decodedItems is! List) return;

      _userQuestions
        ..clear()
        ..addAll(
          decodedItems.whereType<Map>().map(
                (item) => UserQuestion.fromJson(Map<String, dynamic>.from(item)),
              ),
        );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadQuestionsFromSupabase() async {
    try {
      final rows = await SupabaseService.instance.select('user_questions');
      if (rows.isEmpty) {
        await _saveQuestionsLocally();
        return;
      }

      _userQuestions
        ..clear()
        ..addAll(rows.map(UserQuestion.fromJson));
      await _saveQuestionsLocally();
      notifyListeners();
    } catch (_) {
      await _saveQuestionsLocally();
    }
  }

  Future<void> _loadAdsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedItems = prefs.getString(_adsStorageKey);
      if (encodedItems == null || encodedItems.isEmpty) return;

      final decodedItems = jsonDecode(encodedItems);
      if (decodedItems is! List) return;

      _ads
        ..clear()
        ..addAll(
          decodedItems.whereType<Map>().map(
                (item) => Map<String, String>.from(
                  item.map((key, value) => MapEntry(key.toString(), value?.toString() ?? '')),
                ),
              ),
        );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadAdsFromSupabase() async {
    try {
      final rows = await SupabaseService.instance.select('ads');
      if (rows.isEmpty) {
        _ads.clear();
        await _saveAdsLocally();
        notifyListeners();
        return;
      }

      _ads
        ..clear()
        ..addAll(rows.map(_adFromJson));
      await _saveAdsLocally();
      notifyListeners();
    } catch (_) {
      await _saveAdsLocally();
    }
  }


  List<UserQuestion> getUnansweredQuestions() {
    return _userQuestions.where((q) => !q.isAnswered).toList();
  }

  List<UserQuestion> getAnsweredQuestions() {
    return _userQuestions.where((q) => q.isAnswered).toList();
  }

  void addUserQuestion(UserQuestion question) {
    _userQuestions.add(question);
    notifyListeners();
    _saveQuestionsLocally();
    _persistQuestion(question);
  }

  void replyToQuestion(String questionId, String reply) {
    final index = _userQuestions.indexWhere((q) => q.id == questionId);
    if (index == -1) return;

    final question = _userQuestions[index];
    final updatedQuestion = question.copyWith(
      reply: reply,
      repliedAt: DateTime.now(),
      isAnswered: true,
    );
    _userQuestions[index] = updatedQuestion;

    final qaContent = SectionContentItem(
      id: 'content_qa_user_$questionId',
      sectionId: 'sec_qa',
      title: 'Q: ${question.question}',
      description: 'A: $reply',
      bulletPoints: const [],
      backgroundColor: Colors.teal,
    );

    final contentIndex =
        _sectionContent.indexWhere((content) => content.id == qaContent.id);
    if (contentIndex == -1) {
      _sectionContent.add(qaContent);
    } else {
      _sectionContent[contentIndex] = qaContent;
    }

    notifyListeners();
    _saveQuestionsLocally();
    _saveSectionContentLocally();
    _persistQuestion(updatedQuestion);
    _persistSectionContent(qaContent);
  }

  void deleteUserQuestion(String questionId) {
    final question = _userQuestions.cast<UserQuestion?>().firstWhere(
          (q) => q?.id == questionId,
          orElse: () => null,
        );

    if (question?.isAnswered == true) {
      final qaContentId = 'content_qa_user_$questionId';
      _sectionContent.removeWhere((content) => content.id == qaContentId);
      _deleteSectionContentRemote(qaContentId);
      _saveSectionContentLocally();
    }

    _userQuestions.removeWhere((q) => q.id == questionId);
    notifyListeners();
    _saveQuestionsLocally();
    _deleteQuestionRemote(questionId);
  }

  void addSlide(SlideItem slide) {
    _slides.add(slide);
    notifyListeners();
    _saveSlidesLocally();
    _persistSlide(slide);
  }

  void updateSlide(String id, SlideItem updated) {
    final index = _slides.indexWhere((s) => s.id == id);
    if (index == -1) return;

    _slides[index] = updated;
    notifyListeners();
    _saveSlidesLocally();
    _persistSlide(updated);
  }

  void removeSlide(String id) {
    _slides.removeWhere((s) => s.id == id);
    notifyListeners();
    _saveSlidesLocally();
    _deleteSlideRemote(id);
  }

  Future<void> _persistSlide(SlideItem slide) async {
    try {
      await SupabaseService.instance.upsert('slides', slide.toJson());
    } catch (_) {}
  }

  Future<void> _deleteSlideRemote(String id) async {
    try {
      await SupabaseService.instance.delete('slides', 'id', id);
    } catch (_) {}
  }

  Future<void> _saveSlidesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(_slides.map((slide) => slide.toJson()).toList());
      await prefs.setString(_slidesStorageKey, payload);
    } catch (_) {}
  }

  void addSection(SectionItem section) {
    _sections.add(section);
    notifyListeners();
  }

  void updateSection(String id, SectionItem updated) {
    final index = _sections.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sections[index] = updated;
      notifyListeners();
    }
  }

  void removeSection(String id) {
    _sections.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void addSectionContent(SectionContentItem content) {
    _sectionContent.add(content);
    notifyListeners();
    _saveSectionContentLocally();
    _persistSectionContent(content);
  }

  void updateSectionContent(String id, SectionContentItem updated) {
    final index = _sectionContent.indexWhere((c) => c.id == id);
    if (index == -1) return;

    _sectionContent[index] = updated;
    notifyListeners();
    _saveSectionContentLocally();
    _persistSectionContent(updated);
  }

  void removeSectionContent(String id) {
    _sectionContent.removeWhere((c) => c.id == id);
    notifyListeners();
    _saveSectionContentLocally();
    _deleteSectionContentRemote(id);
  }

  Future<void> _persistSectionContent(SectionContentItem content) async {
    try {
      await SupabaseService.instance.upsert('section_content', content.toJson());
    } catch (_) {}
  }

  Future<void> _deleteSectionContentRemote(String id) async {
    try {
      await SupabaseService.instance.delete('section_content', 'id', id);
    } catch (_) {}
  }

  Future<void> _saveSectionContentLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload =
          jsonEncode(_sectionContent.map((content) => content.toJson()).toList());
      await prefs.setString(_sectionContentStorageKey, payload);
    } catch (_) {}
  }

  void addAd(Map<String, String> ad) {
    _ads.add(ad);
    notifyListeners();
    _saveAdsLocally();
    _persistAd(ad);
  }

  void updateAd(int index, Map<String, String> updatedAd) {
    if (index < 0 || index >= _ads.length) return;

    _ads[index] = updatedAd;
    notifyListeners();
    _saveAdsLocally();
    _persistAd(updatedAd);
  }

  void removeAd(int index) {
    if (index < 0 || index >= _ads.length) return;

    final ad = _ads[index];
    final id = ad['id'];
    final image = ad['image'];

    _ads.removeAt(index);
    notifyListeners();
    _saveAdsLocally();

    if (id != null) {
      _deleteAdRemote(id);
    }

    if (image != null && image.contains('ads/')) {
      _deleteAdImageRemote(image);
    }
  }

  Future<void> _persistQuestion(UserQuestion question) async {
    try {
      await SupabaseService.instance.upsert('user_questions', question.toJson());
    } catch (_) {}
  }

  Future<void> _deleteQuestionRemote(String questionId) async {
    try {
      await SupabaseService.instance.delete('user_questions', 'id', questionId);
    } catch (_) {}
  }

  Future<void> _saveQuestionsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(
        _userQuestions.map((question) => question.toJson()).toList(),
      );
      await prefs.setString(_questionsStorageKey, payload);
    } catch (_) {}
  }

  Future<void> _persistAd(Map<String, String> ad) async {
    try {
      await SupabaseService.instance.upsert('ads', _adToJson(ad));
    } catch (_) {}
  }

  Future<void> _deleteAdRemote(String id) async {
    try {
      await SupabaseService.instance.delete('ads', 'id', id);
    } catch (_) {}
  }

  Future<void> _deleteAdImageRemote(String path) async {
    try {
      await SupabaseService.instance.removeFromBucket(bucket: 'ads', path: path);
    } catch (_) {}
  }

  Future<void> _saveAdsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(_ads.map(_adToJson).toList());
      await prefs.setString(_adsStorageKey, payload);
    } catch (_) {}
  }

  Map<String, dynamic> _adToJson(Map<String, String> ad) => {
        'id': ad['id'] ?? '',
        'title': ad['title'] ?? '',
        'description': ad['description'] ?? '',
        'image': ad['image'] ?? '',
      };

  Map<String, String> _adFromJson(Map<String, dynamic> json) => {
        'id': json['id']?.toString() ?? '',
        'title': json['title']?.toString() ?? '',
        'description': json['description']?.toString() ?? '',
        'image': json['image']?.toString() ?? '',
      };
}


