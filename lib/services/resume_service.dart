import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'ai_service.dart';
import 'skill_validator.dart';

class ResumeParseResult {
  final List<Map<String, dynamic>> skills;           // verified — stored immediately
  final List<Map<String, dynamic>> unverifiedSkills; // pending user confirmation
  final String? error;
  final bool isEmpty;

  ResumeParseResult({
    required this.skills,
    this.unverifiedSkills = const [],
    this.error,
    this.isEmpty = false,
  });
}

/// Handles resume file picking and text extraction.
/// Supports PDF (via syncfusion_flutter_pdf) and TXT files.
/// All parsing is done client-side — no Cloud Storage needed.
class ResumeService {
  /// Pick a PDF or TXT file, extract text, run AI + validation pipeline.
  /// Returns verified skills and unverified skills separately.
  static Future<ResumeParseResult> pickAndParseResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        return ResumeParseResult(skills: []);
      }

      final file = result.files.first;
      String text = '';

      if (!kIsWeb && file.path != null) {
        text = await _readFromPath(file.path!, file.extension ?? 'txt');
      } else if (file.bytes != null) {
        text = await _extractText(file.bytes!, file.extension ?? 'txt');
      }

      if (text.trim().isEmpty) {
        return ResumeParseResult(skills: [], isEmpty: true);
      }

      // Run AI extraction — let AiKeyMissingException and AiRequestException
      // propagate up so the catch block below can show the real error message.
      List<Map<String, dynamic>> rawSkills;
      try {
        rawSkills = await AiService.extractSkillsFromText(text);
      } on AiKeyMissingException {
        return ResumeParseResult(
          skills: [],
          error: 'Service not configured. Please contact support.',
        );
      } on AiRequestException catch (e) {
        return ResumeParseResult(
          skills: [],
          error: e.statusCode == 401
              ? 'AI Service Authentication failed. Please verify your GROQ_API_KEY in .env.'
              : 'Analysis service is temporarily unavailable. Please try again.',
        );
      }

      if (rawSkills.isEmpty) {
        return ResumeParseResult(
          skills: [],
          error:
              'No skills could be identified in your resume. Ensure the file '
              'contains clearly listed technical skills, tools, or frameworks.',
        );
      }

      // Run validation pipeline: verified vs unverified
      final validation = SkillValidator.validate(rawSkills);

      if (validation.verified.isEmpty && validation.unverified.isEmpty) {
        return ResumeParseResult(
          skills: [],
          error:
              'Your resume was read but only contained general terms. '
              'Try adding specific technical skills, tools, or frameworks.',
        );
      }

      return ResumeParseResult(
        skills: validation.verified,
        unverifiedSkills: validation.unverified,
      );
    } catch (e) {
      debugPrint('ResumeService.pickAndParseResume error: $e');
      return ResumeParseResult(
          skills: [], error: 'An error occurred while reading your file.');
    }
  }

  static Future<String> _readFromPath(String path, String ext) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      return await _extractText(bytes, ext);
    } catch (e) {
      debugPrint('ResumeService._readFromPath error: $e');
      return '';
    }
  }

  static Future<String> _extractText(Uint8List bytes, String ext) async {
    try {
      if (ext.toLowerCase() == 'txt') {
        return _decodeText(bytes);
      }
      if (ext.toLowerCase() == 'pdf') {
        return await _extractPdfText(bytes);
      }
      return '';
    } catch (e) {
      debugPrint('ResumeService._extractText error: $e');
      return '';
    }
  }

  static Future<String> _extractPdfText(Uint8List bytes) async {
    try {
      // Run on a background isolate — PDF parsing is CPU-heavy and blocks
      // the main thread on large resumes, causing visible UI jank.
      return await compute(_parsePdfInIsolate, bytes);
    } catch (e) {
      debugPrint('ResumeService._extractPdfText error: $e');
      return '';
    }
  }

  /// Top-level function required by compute() — must not be a closure.
  static String _parsePdfInIsolate(Uint8List bytes) {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      return _cleanExtractedText(text);
    } catch (_) {
      return '';
    }
  }

  static String _cleanExtractedText(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF]'), ' ')
        .trim();
    return cleaned.length > 6000 ? cleaned.substring(0, 6000) : cleaned;
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return _cleanExtractedText(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return '';
    }
  }

  /// Parse manually entered text into skills (used by Manual tab).
  static Future<List<Map<String, dynamic>>> parseManualText(
      String text) async {
    if (text.trim().isEmpty) return [];
    final raw = await AiService.extractSkillsFromText(text);
    final validation = SkillValidator.validate(raw);
    return [...validation.verified, ...validation.unverified];
  }
}
