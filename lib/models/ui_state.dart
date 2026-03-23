import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/resume_service.dart';
import 'app_state.dart';

enum AppTab { home, explore, analyze, roadmap, profile }
enum RolesTab { matches, search }
enum AnalyzeTab { overview, resume, manual }
enum RoadmapTab { path, insights }

/// Owns all UI-only state: tab indices, theme, resume upload progress.
/// Kept separate from AppState so tab changes don't rebuild data-heavy widgets.
class UiState extends ChangeNotifier {
  // ── Tab navigation ─────────────────────────────────────────────
  AppTab currentTab = AppTab.home;
  RolesTab rolesTab = RolesTab.matches;
  AnalyzeTab analyzeTab = AnalyzeTab.overview;
  RoadmapTab roadmapTab = RoadmapTab.path;

  void setTab(AppTab t) { currentTab = t; notifyListeners(); }
  void setRolesTab(RolesTab t) { rolesTab = t; notifyListeners(); }
  void setAnalyzeTab(AnalyzeTab t) { analyzeTab = t; notifyListeners(); }
  void setRoadmapTab(RoadmapTab t) { roadmapTab = t; notifyListeners(); }

  // ── Theme ──────────────────────────────────────────────────────
  bool _isLightMode = false;
  bool get isLightMode => _isLightMode;

  void toggleTheme() {
    _isLightMode = !_isLightMode;
    AppColors.update(_isLightMode);
    notifyListeners();
  }

  // ── Resume upload UI state ─────────────────────────────────────
  ResumeState resumeState = ResumeState.idle;
  String resumeProgress = '';
  double resumeProgressFraction = 0.0;
  String? resumeError;

  void setResumeState({
    required ResumeState state,
    String progress = '',
    double fraction = 0.0,
    String? error,
  }) {
    resumeState = state;
    resumeProgress = progress;
    resumeProgressFraction = fraction;
    resumeError = error;
    notifyListeners();
  }

  void resetResumeState() {
    resumeState = ResumeState.idle;
    resumeProgress = '';
    resumeProgressFraction = 0.0;
    resumeError = null;
    _pendingUnverifiedSkills = [];
    notifyListeners();
  }

  // ── Resume logic ───────────────────────────────────────────────
  List<Map<String, dynamic>> _pendingUnverifiedSkills = [];
  List<Map<String, dynamic>> get pendingUnverifiedSkills => _pendingUnverifiedSkills;

  Future<void> uploadResume(AppState app) async {
    if (app.uid == null) {
      setResumeState(
        state: ResumeState.error,
        error: 'Please sign in before uploading a resume.',
      );
      return;
    }

    resumeState = ResumeState.uploading;
    resumeProgress = 'Reading file…';
    resumeProgressFraction = 0.1;
    resumeError = null;
    notifyListeners();

    try {
      resumeProgress = 'Extracting text…';
      resumeProgressFraction = 0.25;
      notifyListeners();

      final result = await ResumeService.pickAndParseResume();

      // ── Cancelled: user closed the file picker ──────────────
      // All three conditions being falsy with no error = picker was dismissed.
      if (!result.isEmpty && result.error == null &&
          result.skills.isEmpty && result.unverifiedSkills.isEmpty) {
        resumeState = ResumeState.idle;
        resumeProgress = '';
        resumeProgressFraction = 0.0;
        notifyListeners();
        return;
      }

      // ── PDF/TXT returned empty text ─────────────────────────
      if (result.isEmpty) {
        setResumeState(
          state: ResumeState.error,
          error: 'No text could be read from this file. '
              'Try a different PDF or paste as TXT.',
        );
        return;
      }

      // ── AI / validation error ───────────────────────────────
      if (result.error != null && result.skills.isEmpty &&
          result.unverifiedSkills.isEmpty) {
        setResumeState(state: ResumeState.error, error: result.error);
        return;
      }

      // ── Save verified skills ────────────────────────────────
      final verifiedList =
          result.skills.map((s) => {...s, 'source': 'resume'}).toList();

      if (verifiedList.isNotEmpty) {
        resumeProgress = 'Saving ${verifiedList.length} skills…';
        resumeProgressFraction = 0.8;
        notifyListeners();

        try {
          await app.addSkillsBatch(verifiedList);
        } catch (saveError) {
          // Skill save failed even after the fallback in AppState.
          // Still advance to done so the user can see extracted skills
          // in the unverified confirmation card and retry from there.
          debugPrint('UiState.uploadResume: addSkillsBatch failed ($saveError). '
              'Advancing to done with unverified list for manual confirmation.');
          // Move all verified to unverified so the user can confirm + retry
          final allPending = [
            ...verifiedList,
            ...result.unverifiedSkills
                .map((s) => {...s, 'source': 'resume'})
                ,
          ];
          resumeProgress = 'Done!';
          resumeProgressFraction = 1.0;
          resumeState = ResumeState.done;
          _pendingUnverifiedSkills = allPending;
          notifyListeners();
          return;
        }
      }

      resumeProgress = 'Done!';
      resumeProgressFraction = 1.0;
      resumeState = ResumeState.done;
      _pendingUnverifiedSkills =
          result.unverifiedSkills.isNotEmpty ? result.unverifiedSkills : [];
      notifyListeners();
    } catch (e) {
      setResumeState(
        state: ResumeState.error,
        error: 'Something went wrong while reading your file. '
            'Try again or use a different format.',
      );
    }
  }

  Future<void> confirmUnverifiedSkills(AppState app, List<Map<String, dynamic>> confirmed) async {
    if (confirmed.isEmpty || app.uid == null) return;
    await app.addSkillsBatch(
      confirmed.map((s) => {...s, 'source': 'resume'}).toList(),
    );
    _pendingUnverifiedSkills = [];
    notifyListeners();
  }

  void clearForSignOut() {
    currentTab = AppTab.home;
    rolesTab = RolesTab.matches;
    analyzeTab = AnalyzeTab.overview;
    roadmapTab = RoadmapTab.path;
    resumeState = ResumeState.idle;
    resumeProgress = '';
    resumeProgressFraction = 0.0;
    resumeError = null;
    notifyListeners();
  }
}

enum ResumeState { idle, uploading, parsing, done, error }
