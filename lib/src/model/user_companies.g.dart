// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_companies.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserCompanies _$UserCompaniesFromJson(Map<String, dynamic> json) {
  return UserCompanies(
    current_company: json['current_company'] as int,
    allowed_companies: json['allowed_companies'] as Map<String, dynamic>,
  );
}

Map<String, dynamic> _$UserCompaniesToJson(UserCompanies instance) =>
    <String, dynamic>{
      'current_company': instance.current_company,
      'allowed_companies': instance.allowed_companies,
    };
