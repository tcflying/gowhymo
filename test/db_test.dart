import 'package:flutter_test/flutter_test.dart';
import 'package:gowhymo/db/kid.dart';
import 'package:gowhymo/db/plan.dart';
import 'package:gowhymo/db/user.dart';
import 'package:gowhymo/db/lib.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/add_kid.dart';

void main() {
  group('Kid Model Tests', () {
    test('Kid fromJson should parse correctly', () {
      final json = {
        'id': 1,
        'name': 'Test Kid',
        'birth_date': '2020-01-01T00:00:00.000',
        'gender': 'male',
        'avatar_type': 'imageFile',
        'avatar_image_data': null,
        'description': 'Test description',
        'created_by': 'test_user',
        'created_at': '2024-01-01T00:00:00.000',
        'updated_at': '2024-01-01T00:00:00.000',
        'metadata': null,
      };

      final kid = Kid.fromJson(json);

      expect(kid.id, 1);
      expect(kid.name, 'Test Kid');
      expect(kid.gender, 'male');
      expect(kid.createdBy, 'test_user');
    });

    test('Kid toJson should serialize correctly', () {
      final kid = Kid(
        id: 1,
        name: 'Test Kid',
        birthDate: DateTime(2020, 1, 1),
        gender: 'male',
        avatarType: AvatarType.imageFile,
        avatarImageData: null,
        description: 'Test description',
        createdBy: 'test_user',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        metadata: null,
      );

      final json = kid.toJson();

      expect(json['id'], 1);
      expect(json['name'], 'Test Kid');
      expect(json['gender'], 'male');
      expect(json['created_by'], 'test_user');
    });
  });

  group('Plan Model Tests', () {
    test('Plan fromJson should parse correctly', () {
      final json = {
        'plan_id': 1,
        'kid_id': 101,
        'content': 'Test content',
        'date': '2024-01-01T00:00:00.000',
        'slot_name': '10:00',
        'location': 'Test location',
        'created_by': 'test_user',
        'created_at': '2024-01-01T00:00:00.000',
        'updated_at': '2024-01-01T00:00:00.000',
      };

      final plan = Plan.fromJson(json);

      expect(plan.planId, 1);
      expect(plan.kidId, 101);
      expect(plan.content, 'Test content');
      expect(plan.slotName, '10:00');
      expect(plan.location, 'Test location');
    });

    test('Plan toJson should serialize correctly', () {
      final plan = Plan(
        planId: 1,
        kidId: 101,
        content: 'Test content',
        date: DateTime(2024, 1, 1),
        slotName: '10:00',
        location: 'Test location',
        createdBy: 'test_user',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final json = plan.toJson();

      expect(json['plan_id'], 1);
      expect(json['kid_id'], 101);
      expect(json['content'], 'Test content');
      expect(json['slot_name'], '10:00');
      expect(json['location'], 'Test location');
    });
  });

  group('User Model Tests', () {
    test('User fromJson should parse correctly', () {
      final json = {
        'id': 'test_address',
        'phone': '1234567890',
        'email': 'test@example.com',
        'password': null,
        'nickname': 'Test User',
        'last_login_at': '2024-01-01T00:00:00.000',
        'created_at': 1704067200000,
        'updated_at': 1704067200000,
      };

      final user = User.fromJson(json);

      expect(user.id, 'test_address');
      expect(user.phone, '1234567890');
      expect(user.email, 'test@example.com');
      expect(user.nickname, 'Test User');
    });

    test('User toJson should serialize correctly', () {
      final user = User(
        id: 'test_address',
        phone: '1234567890',
        email: 'test@example.com',
        password: null,
        nickname: 'Test User',
        lastLoginAt: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final json = user.toJson();

      expect(json['id'], 'test_address');
      expect(json['phone'], '1234567890');
      expect(json['email'], 'test@example.com');
      expect(json['nickname'], 'Test User');
    });
  });
}
