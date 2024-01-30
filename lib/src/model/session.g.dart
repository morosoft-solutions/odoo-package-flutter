// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Session _$SessionFromJson(Map<String, dynamic> json) {
  return Session(
    json['id'] as String,
    UserLoggedIn.fromJson(json['user'] as Map<String, dynamic>),
    DateTime.parse(json['expirationDate'] as String), 
  );
}

Map<String, dynamic> _$SessionToJson(Session instance) => <String, dynamic>{
      'id': instance.id,
      'user': instance.user.toJson(),
      'expirationDate': instance.expirationDate.toIso8601String(), 
    };
