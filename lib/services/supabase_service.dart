import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _initialized = false;

  Future<void> initialize({required String url, required String anonKey}) async {
    if (_initialized) return;
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    _initialized = true;
  }

  SupabaseClient get client => Supabase.instance.client;

  Future<dynamic> signUp(
    String email,
    String password, {
    Map<String, dynamic>? data,
  }) async {
    return client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<dynamic> signIn(String email, String password) async {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<bool> signInWithOAuth(
    OAuthProvider provider, {
    String? redirectTo,
  }) async {
    return client.auth.signInWithOAuth(
      provider,
      redirectTo: redirectTo,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  Future<String> uploadToBucket({
    required String bucket,
    required List<int> bytes,
    required String path,
    String? contentType,
  }) async {
    final uint8 = Uint8List.fromList(bytes);
    await client.storage.from(bucket).uploadBinary(
      path,
      uint8,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: true,
      ),
    );
    return client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> removeFromBucket({required String bucket, required String path}) async {
    await client.storage.from(bucket).remove([path]);
  }

  Future<dynamic> insert(String table, Map<String, dynamic> values) async {
    return client.from(table).insert(values);
  }

  Future<dynamic> update(
    String table,
    Map<String, dynamic> values,
    String matchColumn,
    dynamic matchValue,
  ) async {
    return client.from(table).update(values).eq(matchColumn, matchValue);
  }

  Future<dynamic> upsert(String table, Map<String, dynamic> values) async {
    return client.from(table).upsert(values);
  }

  Future<dynamic> delete(String table, String matchColumn, dynamic matchValue) async {
    return client.from(table).delete().eq(matchColumn, matchValue);
  }

  Future<List<Map<String, dynamic>>> select(
    String table, {
    String columns = '*',
  }) async {
    final result = await client.from(table).select(columns);
    return List<Map<String, dynamic>>.from(result as List);
  }
}
