/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

abstract class SyncPayload implements _i1.SerializableModel {
  SyncPayload._({
    required this.pairingCode,
    required this.data,
  });

  factory SyncPayload({
    required String pairingCode,
    required String data,
  }) = _SyncPayloadImpl;

  factory SyncPayload.fromJson(Map<String, dynamic> jsonSerialization) {
    return SyncPayload(
      pairingCode: jsonSerialization['pairingCode'] as String,
      data: jsonSerialization['data'] as String,
    );
  }

  String pairingCode;

  String data;

  /// Returns a shallow copy of this [SyncPayload]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  SyncPayload copyWith({
    String? pairingCode,
    String? data,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SyncPayload',
      'pairingCode': pairingCode,
      'data': data,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _SyncPayloadImpl extends SyncPayload {
  _SyncPayloadImpl({
    required String pairingCode,
    required String data,
  }) : super._(
         pairingCode: pairingCode,
         data: data,
       );

  /// Returns a shallow copy of this [SyncPayload]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  SyncPayload copyWith({
    String? pairingCode,
    String? data,
  }) {
    return SyncPayload(
      pairingCode: pairingCode ?? this.pairingCode,
      data: data ?? this.data,
    );
  }
}
