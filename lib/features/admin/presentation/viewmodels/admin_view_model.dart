import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/app_failure.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';

enum AdminSection { dashboard, accounts, organizations }

class AdminViewModel extends ChangeNotifier {
  AdminViewModel(this.repository, this.section)
    : field = section == AdminSection.accounts ? 'fullName' : 'name';
  final AdminRepository repository;
  final AdminSection section;
  bool busy = false, disposed = false, unauthorized = false;
  String? error, message;
  String field, search = '';
  AdminStats? stats;
  List<AdminAccount> accounts = [];
  List<AdminOrganization> organizations = [];
  Map<String, dynamic>? cursor, nextCursor;
  final List<Map<String, dynamic>?> _previous = [];
  final Map<String, String> _requests = {};
  bool get hasPrevious => _previous.isNotEmpty;
  int get page => _previous.length + 1;
  void _notify() {
    if (!disposed) notifyListeners();
  }

  void _failure(Object e) {
    error = AppFailure.from(e).message;
    unauthorized =
        e is AdminFailure &&
        ['unauthenticated', 'permission-denied'].contains(e.code);
  }

  Future<void> _fetch() async {
    switch (section) {
      case AdminSection.dashboard:
        stats = await repository.stats();
      case AdminSection.accounts:
        final result = await repository.accounts(field, search, cursor);
        accounts = result.items;
        nextCursor = result.nextCursor;
      case AdminSection.organizations:
        final result = await repository.organizations(field, search, cursor);
        organizations = result.items;
        nextCursor = result.nextCursor;
    }
  }

  Future<void> load() async {
    if (busy || disposed) return;
    busy = true;
    error = null;
    unauthorized = false;
    _notify();
    try {
      await _fetch();
    } catch (e) {
      _failure(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> find(String field, String value) async {
    if (busy) return;
    this.field = field;
    search = value.trim();
    cursor = null;
    nextCursor = null;
    _previous.clear();
    await load();
  }

  Future<void> next() async {
    if (busy || nextCursor == null) return;
    _previous.add(cursor);
    cursor = nextCursor;
    await load();
  }

  Future<void> previous() async {
    if (busy || _previous.isEmpty) return;
    cursor = _previous.removeLast();
    await load();
  }

  Future<bool> submit(Map<String, dynamic> command) async {
    if (busy || disposed) return false;
    final key = jsonEncode(command);
    final request = {
      ...command,
      'requestId': _requests.putIfAbsent(key, adminRequestId),
    };
    busy = true;
    error = null;
    message = null;
    _notify();
    bool saved = false;
    try {
      await repository.mutate(request);
      saved = true;
      message = 'Changes saved and recorded in the audit log.';
      await _fetch();
    } catch (e) {
      _failure(e);
    } finally {
      busy = false;
      _notify();
    }
    return saved;
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
