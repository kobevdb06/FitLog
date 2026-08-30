// dart format width=80
// ignore_for_file: type=lint
part of 'database.dart';

class $UserProfileTableTable extends UserProfileTable
    with TableInfo<$UserProfileTableTable, UserProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<int> birthDate = GeneratedColumn<int>(
    'birth_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
    'sex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    birthDate,
    sex,
    heightCm,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    }
    if (data.containsKey('sex')) {
      context.handle(
        _sexMeta,
        sex.isAcceptableOrUnknown(data['sex']!, _sexMeta),
      );
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birth_date'],
      ),
      sex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sex'],
      ),
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserProfileTableTable createAlias(String alias) {
    return $UserProfileTableTable(attachedDatabase, alias);
  }
}

class UserProfileRow extends DataClass implements Insertable<UserProfileRow> {
  final String id;
  final String? displayName;

  /// Unix millis, UTC, midnight of the birth date.
  final int? birthDate;

  /// `male` | `female` | `other` | `undisclosed`.
  final String? sex;
  final double? heightCm;
  final int createdAt;
  final int updatedAt;
  const UserProfileRow({
    required this.id,
    this.displayName,
    this.birthDate,
    this.sex,
    this.heightCm,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || birthDate != null) {
      map['birth_date'] = Variable<int>(birthDate);
    }
    if (!nullToAbsent || sex != null) {
      map['sex'] = Variable<String>(sex);
    }
    if (!nullToAbsent || heightCm != null) {
      map['height_cm'] = Variable<double>(heightCm);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  UserProfileTableCompanion toCompanion(bool nullToAbsent) {
    return UserProfileTableCompanion(
      id: Value(id),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      birthDate: birthDate == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDate),
      sex: sex == null && nullToAbsent ? const Value.absent() : Value(sex),
      heightCm: heightCm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightCm),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileRow(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      birthDate: serializer.fromJson<int?>(json['birthDate']),
      sex: serializer.fromJson<String?>(json['sex']),
      heightCm: serializer.fromJson<double?>(json['heightCm']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String?>(displayName),
      'birthDate': serializer.toJson<int?>(birthDate),
      'sex': serializer.toJson<String?>(sex),
      'heightCm': serializer.toJson<double?>(heightCm),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  UserProfileRow copyWith({
    String? id,
    Value<String?> displayName = const Value.absent(),
    Value<int?> birthDate = const Value.absent(),
    Value<String?> sex = const Value.absent(),
    Value<double?> heightCm = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => UserProfileRow(
    id: id ?? this.id,
    displayName: displayName.present ? displayName.value : this.displayName,
    birthDate: birthDate.present ? birthDate.value : this.birthDate,
    sex: sex.present ? sex.value : this.sex,
    heightCm: heightCm.present ? heightCm.value : this.heightCm,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserProfileRow copyWithCompanion(UserProfileTableCompanion data) {
    return UserProfileRow(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      sex: data.sex.present ? data.sex.value : this.sex,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileRow(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('birthDate: $birthDate, ')
          ..write('sex: $sex, ')
          ..write('heightCm: $heightCm, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    birthDate,
    sex,
    heightCm,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileRow &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.birthDate == this.birthDate &&
          other.sex == this.sex &&
          other.heightCm == this.heightCm &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserProfileTableCompanion extends UpdateCompanion<UserProfileRow> {
  final Value<String> id;
  final Value<String?> displayName;
  final Value<int?> birthDate;
  final Value<String?> sex;
  final Value<double?> heightCm;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const UserProfileTableCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.sex = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfileTableCompanion.insert({
    required String id,
    this.displayName = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.sex = const Value.absent(),
    this.heightCm = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UserProfileRow> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<int>? birthDate,
    Expression<String>? sex,
    Expression<double>? heightCm,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (birthDate != null) 'birth_date': birthDate,
      if (sex != null) 'sex': sex,
      if (heightCm != null) 'height_cm': heightCm,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfileTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? displayName,
    Value<int?>? birthDate,
    Value<String?>? sex,
    Value<double?>? heightCm,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserProfileTableCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      birthDate: birthDate ?? this.birthDate,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<int>(birthDate.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(sex.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileTableCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('birthDate: $birthDate, ')
          ..write('sex: $sex, ')
          ..write('heightCm: $heightCm, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTableTable extends AppSettingsTable
    with TableInfo<$AppSettingsTableTable, AppSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitWeightMeta = const VerificationMeta(
    'unitWeight',
  );
  @override
  late final GeneratedColumn<String> unitWeight = GeneratedColumn<String>(
    'unit_weight',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('kg'),
  );
  static const VerificationMeta _unitLengthMeta = const VerificationMeta(
    'unitLength',
  );
  @override
  late final GeneratedColumn<String> unitLength = GeneratedColumn<String>(
    'unit_length',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('cm'),
  );
  static const VerificationMeta _unitDistanceMeta = const VerificationMeta(
    'unitDistance',
  );
  @override
  late final GeneratedColumn<String> unitDistance = GeneratedColumn<String>(
    'unit_distance',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('km'),
  );
  static const VerificationMeta _defaultRestSecondsMeta =
      const VerificationMeta('defaultRestSeconds');
  @override
  late final GeneratedColumn<int> defaultRestSeconds = GeneratedColumn<int>(
    'default_rest_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(90),
  );
  static const VerificationMeta _restSoundEnabledMeta = const VerificationMeta(
    'restSoundEnabled',
  );
  @override
  late final GeneratedColumn<bool> restSoundEnabled = GeneratedColumn<bool>(
    'rest_sound_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("rest_sound_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _setCheckSoundEnabledMeta =
      const VerificationMeta('setCheckSoundEnabled');
  @override
  late final GeneratedColumn<bool> setCheckSoundEnabled = GeneratedColumn<bool>(
    'set_check_sound_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("set_check_sound_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _prAlertEnabledMeta = const VerificationMeta(
    'prAlertEnabled',
  );
  @override
  late final GeneratedColumn<bool> prAlertEnabled = GeneratedColumn<bool>(
    'pr_alert_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pr_alert_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastBackupAtMeta = const VerificationMeta(
    'lastBackupAt',
  );
  @override
  late final GeneratedColumn<int> lastBackupAt = GeneratedColumn<int>(
    'last_backup_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingPickKindMeta = const VerificationMeta(
    'pendingPickKind',
  );
  @override
  late final GeneratedColumn<String> pendingPickKind = GeneratedColumn<String>(
    'pending_pick_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingPickRefMeta = const VerificationMeta(
    'pendingPickRef',
  );
  @override
  late final GeneratedColumn<String> pendingPickRef = GeneratedColumn<String>(
    'pending_pick_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('dark'),
  );
  static const VerificationMeta _localeMeta = const VerificationMeta('locale');
  @override
  late final GeneratedColumn<String> locale = GeneratedColumn<String>(
    'locale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('nl'),
  );
  static const VerificationMeta _onboardingDoneMeta = const VerificationMeta(
    'onboardingDone',
  );
  @override
  late final GeneratedColumn<bool> onboardingDone = GeneratedColumn<bool>(
    'onboarding_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _exercisesSeededMeta = const VerificationMeta(
    'exercisesSeeded',
  );
  @override
  late final GeneratedColumn<bool> exercisesSeeded = GeneratedColumn<bool>(
    'exercises_seeded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("exercises_seeded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _barWeightKgMeta = const VerificationMeta(
    'barWeightKg',
  );
  @override
  late final GeneratedColumn<double> barWeightKg = GeneratedColumn<double>(
    'bar_weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(20.0),
  );
  static const VerificationMeta _availablePlatesKgMeta = const VerificationMeta(
    'availablePlatesKg',
  );
  @override
  late final GeneratedColumn<String> availablePlatesKg =
      GeneratedColumn<String>(
        'available_plates_kg',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[25,20,15,10,5,2.5,1.25]'),
      );
  static const VerificationMeta _defaultWarmupSetsMeta = const VerificationMeta(
    'defaultWarmupSets',
  );
  @override
  late final GeneratedColumn<int> defaultWarmupSets = GeneratedColumn<int>(
    'default_warmup_sets',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _prDefaultWarmupSetsMeta =
      const VerificationMeta('prDefaultWarmupSets');
  @override
  late final GeneratedColumn<int> prDefaultWarmupSets = GeneratedColumn<int>(
    'pr_default_warmup_sets',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _prDefaultExtraAttemptsMeta =
      const VerificationMeta('prDefaultExtraAttempts');
  @override
  late final GeneratedColumn<int> prDefaultExtraAttempts = GeneratedColumn<int>(
    'pr_default_extra_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _autoLockSecondsMeta = const VerificationMeta(
    'autoLockSeconds',
  );
  @override
  late final GeneratedColumn<int> autoLockSeconds = GeneratedColumn<int>(
    'auto_lock_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    unitWeight,
    unitLength,
    unitDistance,
    defaultRestSeconds,
    restSoundEnabled,
    setCheckSoundEnabled,
    prAlertEnabled,
    lastBackupAt,
    pendingPickKind,
    pendingPickRef,
    themeMode,
    locale,
    onboardingDone,
    exercisesSeeded,
    barWeightKg,
    availablePlatesKg,
    defaultWarmupSets,
    prDefaultWarmupSets,
    prDefaultExtraAttempts,
    autoLockSeconds,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('unit_weight')) {
      context.handle(
        _unitWeightMeta,
        unitWeight.isAcceptableOrUnknown(data['unit_weight']!, _unitWeightMeta),
      );
    }
    if (data.containsKey('unit_length')) {
      context.handle(
        _unitLengthMeta,
        unitLength.isAcceptableOrUnknown(data['unit_length']!, _unitLengthMeta),
      );
    }
    if (data.containsKey('unit_distance')) {
      context.handle(
        _unitDistanceMeta,
        unitDistance.isAcceptableOrUnknown(
          data['unit_distance']!,
          _unitDistanceMeta,
        ),
      );
    }
    if (data.containsKey('default_rest_seconds')) {
      context.handle(
        _defaultRestSecondsMeta,
        defaultRestSeconds.isAcceptableOrUnknown(
          data['default_rest_seconds']!,
          _defaultRestSecondsMeta,
        ),
      );
    }
    if (data.containsKey('rest_sound_enabled')) {
      context.handle(
        _restSoundEnabledMeta,
        restSoundEnabled.isAcceptableOrUnknown(
          data['rest_sound_enabled']!,
          _restSoundEnabledMeta,
        ),
      );
    }
    if (data.containsKey('set_check_sound_enabled')) {
      context.handle(
        _setCheckSoundEnabledMeta,
        setCheckSoundEnabled.isAcceptableOrUnknown(
          data['set_check_sound_enabled']!,
          _setCheckSoundEnabledMeta,
        ),
      );
    }
    if (data.containsKey('pr_alert_enabled')) {
      context.handle(
        _prAlertEnabledMeta,
        prAlertEnabled.isAcceptableOrUnknown(
          data['pr_alert_enabled']!,
          _prAlertEnabledMeta,
        ),
      );
    }
    if (data.containsKey('last_backup_at')) {
      context.handle(
        _lastBackupAtMeta,
        lastBackupAt.isAcceptableOrUnknown(
          data['last_backup_at']!,
          _lastBackupAtMeta,
        ),
      );
    }
    if (data.containsKey('pending_pick_kind')) {
      context.handle(
        _pendingPickKindMeta,
        pendingPickKind.isAcceptableOrUnknown(
          data['pending_pick_kind']!,
          _pendingPickKindMeta,
        ),
      );
    }
    if (data.containsKey('pending_pick_ref')) {
      context.handle(
        _pendingPickRefMeta,
        pendingPickRef.isAcceptableOrUnknown(
          data['pending_pick_ref']!,
          _pendingPickRefMeta,
        ),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('locale')) {
      context.handle(
        _localeMeta,
        locale.isAcceptableOrUnknown(data['locale']!, _localeMeta),
      );
    }
    if (data.containsKey('onboarding_done')) {
      context.handle(
        _onboardingDoneMeta,
        onboardingDone.isAcceptableOrUnknown(
          data['onboarding_done']!,
          _onboardingDoneMeta,
        ),
      );
    }
    if (data.containsKey('exercises_seeded')) {
      context.handle(
        _exercisesSeededMeta,
        exercisesSeeded.isAcceptableOrUnknown(
          data['exercises_seeded']!,
          _exercisesSeededMeta,
        ),
      );
    }
    if (data.containsKey('bar_weight_kg')) {
      context.handle(
        _barWeightKgMeta,
        barWeightKg.isAcceptableOrUnknown(
          data['bar_weight_kg']!,
          _barWeightKgMeta,
        ),
      );
    }
    if (data.containsKey('available_plates_kg')) {
      context.handle(
        _availablePlatesKgMeta,
        availablePlatesKg.isAcceptableOrUnknown(
          data['available_plates_kg']!,
          _availablePlatesKgMeta,
        ),
      );
    }
    if (data.containsKey('default_warmup_sets')) {
      context.handle(
        _defaultWarmupSetsMeta,
        defaultWarmupSets.isAcceptableOrUnknown(
          data['default_warmup_sets']!,
          _defaultWarmupSetsMeta,
        ),
      );
    }
    if (data.containsKey('pr_default_warmup_sets')) {
      context.handle(
        _prDefaultWarmupSetsMeta,
        prDefaultWarmupSets.isAcceptableOrUnknown(
          data['pr_default_warmup_sets']!,
          _prDefaultWarmupSetsMeta,
        ),
      );
    }
    if (data.containsKey('pr_default_extra_attempts')) {
      context.handle(
        _prDefaultExtraAttemptsMeta,
        prDefaultExtraAttempts.isAcceptableOrUnknown(
          data['pr_default_extra_attempts']!,
          _prDefaultExtraAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('auto_lock_seconds')) {
      context.handle(
        _autoLockSecondsMeta,
        autoLockSeconds.isAcceptableOrUnknown(
          data['auto_lock_seconds']!,
          _autoLockSecondsMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      unitWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_weight'],
      )!,
      unitLength: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_length'],
      )!,
      unitDistance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_distance'],
      )!,
      defaultRestSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_rest_seconds'],
      )!,
      restSoundEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}rest_sound_enabled'],
      )!,
      setCheckSoundEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}set_check_sound_enabled'],
      )!,
      prAlertEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pr_alert_enabled'],
      )!,
      lastBackupAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_backup_at'],
      ),
      pendingPickKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_pick_kind'],
      ),
      pendingPickRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_pick_ref'],
      ),
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      locale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale'],
      )!,
      onboardingDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_done'],
      )!,
      exercisesSeeded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}exercises_seeded'],
      )!,
      barWeightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bar_weight_kg'],
      )!,
      availablePlatesKg: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}available_plates_kg'],
      )!,
      defaultWarmupSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_warmup_sets'],
      )!,
      prDefaultWarmupSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pr_default_warmup_sets'],
      )!,
      prDefaultExtraAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pr_default_extra_attempts'],
      )!,
      autoLockSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auto_lock_seconds'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTableTable createAlias(String alias) {
    return $AppSettingsTableTable(attachedDatabase, alias);
  }
}

class AppSettingsRow extends DataClass implements Insertable<AppSettingsRow> {
  final String id;

  /// `kg` | `lb`.
  final String unitWeight;

  /// `cm` | `in`.
  final String unitLength;

  /// `km` | `mi`.
  final String unitDistance;
  final int defaultRestSeconds;
  final bool restSoundEnabled;
  final bool setCheckSoundEnabled;
  final bool prAlertEnabled;

  /// When the last encrypted backup was written, in unix millis.
  ///
  /// It is written before the database snapshot is taken, so the value inside
  /// a backup is that backup's own moment: after a restore the reminder is
  /// right without any extra bookkeeping.
  final int? lastBackupAt;

  /// One of [PickKind] while a photo is being picked, null otherwise.
  ///
  /// Android may kill the app while the camera is in front of it. The note
  /// survives that, and is what tells the next launch where the picture it
  /// gets handed back belongs.
  final String? pendingPickKind;

  /// What the pending pick was for: a pose, or an exercise and a slot.
  final String? pendingPickRef;

  /// `system` | `light` | `dark`. Defaults to dark: this app is dark first.
  final String themeMode;
  final String locale;
  final bool onboardingDone;

  /// Set once the bundled exercise catalogue has been imported.
  final bool exercisesSeeded;

  /// Barbell weight in kg used by the plate calculator.
  final double barWeightKg;

  /// JSON array of available plate weights in kg, per side.
  final String availablePlatesKg;

  /// How many warm-up sets a newly added exercise starts with, 0 to 5.
  final int defaultWarmupSets;

  /// How many warm-up rungs a PR attempt is pre-filled with, 2 to 8.
  final int prDefaultWarmupSets;

  /// How many further attempts to offer after a successful one, 0 to 3.
  final int prDefaultExtraAttempts;

  /// Seconds of background time before the app locks. 0 = immediately,
  /// -1 = never.
  final int autoLockSeconds;
  final int updatedAt;
  const AppSettingsRow({
    required this.id,
    required this.unitWeight,
    required this.unitLength,
    required this.unitDistance,
    required this.defaultRestSeconds,
    required this.restSoundEnabled,
    required this.setCheckSoundEnabled,
    required this.prAlertEnabled,
    this.lastBackupAt,
    this.pendingPickKind,
    this.pendingPickRef,
    required this.themeMode,
    required this.locale,
    required this.onboardingDone,
    required this.exercisesSeeded,
    required this.barWeightKg,
    required this.availablePlatesKg,
    required this.defaultWarmupSets,
    required this.prDefaultWarmupSets,
    required this.prDefaultExtraAttempts,
    required this.autoLockSeconds,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['unit_weight'] = Variable<String>(unitWeight);
    map['unit_length'] = Variable<String>(unitLength);
    map['unit_distance'] = Variable<String>(unitDistance);
    map['default_rest_seconds'] = Variable<int>(defaultRestSeconds);
    map['rest_sound_enabled'] = Variable<bool>(restSoundEnabled);
    map['set_check_sound_enabled'] = Variable<bool>(setCheckSoundEnabled);
    map['pr_alert_enabled'] = Variable<bool>(prAlertEnabled);
    if (!nullToAbsent || lastBackupAt != null) {
      map['last_backup_at'] = Variable<int>(lastBackupAt);
    }
    if (!nullToAbsent || pendingPickKind != null) {
      map['pending_pick_kind'] = Variable<String>(pendingPickKind);
    }
    if (!nullToAbsent || pendingPickRef != null) {
      map['pending_pick_ref'] = Variable<String>(pendingPickRef);
    }
    map['theme_mode'] = Variable<String>(themeMode);
    map['locale'] = Variable<String>(locale);
    map['onboarding_done'] = Variable<bool>(onboardingDone);
    map['exercises_seeded'] = Variable<bool>(exercisesSeeded);
    map['bar_weight_kg'] = Variable<double>(barWeightKg);
    map['available_plates_kg'] = Variable<String>(availablePlatesKg);
    map['default_warmup_sets'] = Variable<int>(defaultWarmupSets);
    map['pr_default_warmup_sets'] = Variable<int>(prDefaultWarmupSets);
    map['pr_default_extra_attempts'] = Variable<int>(prDefaultExtraAttempts);
    map['auto_lock_seconds'] = Variable<int>(autoLockSeconds);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AppSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsTableCompanion(
      id: Value(id),
      unitWeight: Value(unitWeight),
      unitLength: Value(unitLength),
      unitDistance: Value(unitDistance),
      defaultRestSeconds: Value(defaultRestSeconds),
      restSoundEnabled: Value(restSoundEnabled),
      setCheckSoundEnabled: Value(setCheckSoundEnabled),
      prAlertEnabled: Value(prAlertEnabled),
      lastBackupAt: lastBackupAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastBackupAt),
      pendingPickKind: pendingPickKind == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingPickKind),
      pendingPickRef: pendingPickRef == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingPickRef),
      themeMode: Value(themeMode),
      locale: Value(locale),
      onboardingDone: Value(onboardingDone),
      exercisesSeeded: Value(exercisesSeeded),
      barWeightKg: Value(barWeightKg),
      availablePlatesKg: Value(availablePlatesKg),
      defaultWarmupSets: Value(defaultWarmupSets),
      prDefaultWarmupSets: Value(prDefaultWarmupSets),
      prDefaultExtraAttempts: Value(prDefaultExtraAttempts),
      autoLockSeconds: Value(autoLockSeconds),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsRow(
      id: serializer.fromJson<String>(json['id']),
      unitWeight: serializer.fromJson<String>(json['unitWeight']),
      unitLength: serializer.fromJson<String>(json['unitLength']),
      unitDistance: serializer.fromJson<String>(json['unitDistance']),
      defaultRestSeconds: serializer.fromJson<int>(json['defaultRestSeconds']),
      restSoundEnabled: serializer.fromJson<bool>(json['restSoundEnabled']),
      setCheckSoundEnabled: serializer.fromJson<bool>(
        json['setCheckSoundEnabled'],
      ),
      prAlertEnabled: serializer.fromJson<bool>(json['prAlertEnabled']),
      lastBackupAt: serializer.fromJson<int?>(json['lastBackupAt']),
      pendingPickKind: serializer.fromJson<String?>(json['pendingPickKind']),
      pendingPickRef: serializer.fromJson<String?>(json['pendingPickRef']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      locale: serializer.fromJson<String>(json['locale']),
      onboardingDone: serializer.fromJson<bool>(json['onboardingDone']),
      exercisesSeeded: serializer.fromJson<bool>(json['exercisesSeeded']),
      barWeightKg: serializer.fromJson<double>(json['barWeightKg']),
      availablePlatesKg: serializer.fromJson<String>(json['availablePlatesKg']),
      defaultWarmupSets: serializer.fromJson<int>(json['defaultWarmupSets']),
      prDefaultWarmupSets: serializer.fromJson<int>(
        json['prDefaultWarmupSets'],
      ),
      prDefaultExtraAttempts: serializer.fromJson<int>(
        json['prDefaultExtraAttempts'],
      ),
      autoLockSeconds: serializer.fromJson<int>(json['autoLockSeconds']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'unitWeight': serializer.toJson<String>(unitWeight),
      'unitLength': serializer.toJson<String>(unitLength),
      'unitDistance': serializer.toJson<String>(unitDistance),
      'defaultRestSeconds': serializer.toJson<int>(defaultRestSeconds),
      'restSoundEnabled': serializer.toJson<bool>(restSoundEnabled),
      'setCheckSoundEnabled': serializer.toJson<bool>(setCheckSoundEnabled),
      'prAlertEnabled': serializer.toJson<bool>(prAlertEnabled),
      'lastBackupAt': serializer.toJson<int?>(lastBackupAt),
      'pendingPickKind': serializer.toJson<String?>(pendingPickKind),
      'pendingPickRef': serializer.toJson<String?>(pendingPickRef),
      'themeMode': serializer.toJson<String>(themeMode),
      'locale': serializer.toJson<String>(locale),
      'onboardingDone': serializer.toJson<bool>(onboardingDone),
      'exercisesSeeded': serializer.toJson<bool>(exercisesSeeded),
      'barWeightKg': serializer.toJson<double>(barWeightKg),
      'availablePlatesKg': serializer.toJson<String>(availablePlatesKg),
      'defaultWarmupSets': serializer.toJson<int>(defaultWarmupSets),
      'prDefaultWarmupSets': serializer.toJson<int>(prDefaultWarmupSets),
      'prDefaultExtraAttempts': serializer.toJson<int>(prDefaultExtraAttempts),
      'autoLockSeconds': serializer.toJson<int>(autoLockSeconds),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AppSettingsRow copyWith({
    String? id,
    String? unitWeight,
    String? unitLength,
    String? unitDistance,
    int? defaultRestSeconds,
    bool? restSoundEnabled,
    bool? setCheckSoundEnabled,
    bool? prAlertEnabled,
    Value<int?> lastBackupAt = const Value.absent(),
    Value<String?> pendingPickKind = const Value.absent(),
    Value<String?> pendingPickRef = const Value.absent(),
    String? themeMode,
    String? locale,
    bool? onboardingDone,
    bool? exercisesSeeded,
    double? barWeightKg,
    String? availablePlatesKg,
    int? defaultWarmupSets,
    int? prDefaultWarmupSets,
    int? prDefaultExtraAttempts,
    int? autoLockSeconds,
    int? updatedAt,
  }) => AppSettingsRow(
    id: id ?? this.id,
    unitWeight: unitWeight ?? this.unitWeight,
    unitLength: unitLength ?? this.unitLength,
    unitDistance: unitDistance ?? this.unitDistance,
    defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
    restSoundEnabled: restSoundEnabled ?? this.restSoundEnabled,
    setCheckSoundEnabled: setCheckSoundEnabled ?? this.setCheckSoundEnabled,
    prAlertEnabled: prAlertEnabled ?? this.prAlertEnabled,
    lastBackupAt: lastBackupAt.present ? lastBackupAt.value : this.lastBackupAt,
    pendingPickKind: pendingPickKind.present
        ? pendingPickKind.value
        : this.pendingPickKind,
    pendingPickRef: pendingPickRef.present
        ? pendingPickRef.value
        : this.pendingPickRef,
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    exercisesSeeded: exercisesSeeded ?? this.exercisesSeeded,
    barWeightKg: barWeightKg ?? this.barWeightKg,
    availablePlatesKg: availablePlatesKg ?? this.availablePlatesKg,
    defaultWarmupSets: defaultWarmupSets ?? this.defaultWarmupSets,
    prDefaultWarmupSets: prDefaultWarmupSets ?? this.prDefaultWarmupSets,
    prDefaultExtraAttempts:
        prDefaultExtraAttempts ?? this.prDefaultExtraAttempts,
    autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSettingsRow copyWithCompanion(AppSettingsTableCompanion data) {
    return AppSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      unitWeight: data.unitWeight.present
          ? data.unitWeight.value
          : this.unitWeight,
      unitLength: data.unitLength.present
          ? data.unitLength.value
          : this.unitLength,
      unitDistance: data.unitDistance.present
          ? data.unitDistance.value
          : this.unitDistance,
      defaultRestSeconds: data.defaultRestSeconds.present
          ? data.defaultRestSeconds.value
          : this.defaultRestSeconds,
      restSoundEnabled: data.restSoundEnabled.present
          ? data.restSoundEnabled.value
          : this.restSoundEnabled,
      setCheckSoundEnabled: data.setCheckSoundEnabled.present
          ? data.setCheckSoundEnabled.value
          : this.setCheckSoundEnabled,
      prAlertEnabled: data.prAlertEnabled.present
          ? data.prAlertEnabled.value
          : this.prAlertEnabled,
      lastBackupAt: data.lastBackupAt.present
          ? data.lastBackupAt.value
          : this.lastBackupAt,
      pendingPickKind: data.pendingPickKind.present
          ? data.pendingPickKind.value
          : this.pendingPickKind,
      pendingPickRef: data.pendingPickRef.present
          ? data.pendingPickRef.value
          : this.pendingPickRef,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      locale: data.locale.present ? data.locale.value : this.locale,
      onboardingDone: data.onboardingDone.present
          ? data.onboardingDone.value
          : this.onboardingDone,
      exercisesSeeded: data.exercisesSeeded.present
          ? data.exercisesSeeded.value
          : this.exercisesSeeded,
      barWeightKg: data.barWeightKg.present
          ? data.barWeightKg.value
          : this.barWeightKg,
      availablePlatesKg: data.availablePlatesKg.present
          ? data.availablePlatesKg.value
          : this.availablePlatesKg,
      defaultWarmupSets: data.defaultWarmupSets.present
          ? data.defaultWarmupSets.value
          : this.defaultWarmupSets,
      prDefaultWarmupSets: data.prDefaultWarmupSets.present
          ? data.prDefaultWarmupSets.value
          : this.prDefaultWarmupSets,
      prDefaultExtraAttempts: data.prDefaultExtraAttempts.present
          ? data.prDefaultExtraAttempts.value
          : this.prDefaultExtraAttempts,
      autoLockSeconds: data.autoLockSeconds.present
          ? data.autoLockSeconds.value
          : this.autoLockSeconds,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsRow(')
          ..write('id: $id, ')
          ..write('unitWeight: $unitWeight, ')
          ..write('unitLength: $unitLength, ')
          ..write('unitDistance: $unitDistance, ')
          ..write('defaultRestSeconds: $defaultRestSeconds, ')
          ..write('restSoundEnabled: $restSoundEnabled, ')
          ..write('setCheckSoundEnabled: $setCheckSoundEnabled, ')
          ..write('prAlertEnabled: $prAlertEnabled, ')
          ..write('lastBackupAt: $lastBackupAt, ')
          ..write('pendingPickKind: $pendingPickKind, ')
          ..write('pendingPickRef: $pendingPickRef, ')
          ..write('themeMode: $themeMode, ')
          ..write('locale: $locale, ')
          ..write('onboardingDone: $onboardingDone, ')
          ..write('exercisesSeeded: $exercisesSeeded, ')
          ..write('barWeightKg: $barWeightKg, ')
          ..write('availablePlatesKg: $availablePlatesKg, ')
          ..write('defaultWarmupSets: $defaultWarmupSets, ')
          ..write('prDefaultWarmupSets: $prDefaultWarmupSets, ')
          ..write('prDefaultExtraAttempts: $prDefaultExtraAttempts, ')
          ..write('autoLockSeconds: $autoLockSeconds, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    unitWeight,
    unitLength,
    unitDistance,
    defaultRestSeconds,
    restSoundEnabled,
    setCheckSoundEnabled,
    prAlertEnabled,
    lastBackupAt,
    pendingPickKind,
    pendingPickRef,
    themeMode,
    locale,
    onboardingDone,
    exercisesSeeded,
    barWeightKg,
    availablePlatesKg,
    defaultWarmupSets,
    prDefaultWarmupSets,
    prDefaultExtraAttempts,
    autoLockSeconds,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsRow &&
          other.id == this.id &&
          other.unitWeight == this.unitWeight &&
          other.unitLength == this.unitLength &&
          other.unitDistance == this.unitDistance &&
          other.defaultRestSeconds == this.defaultRestSeconds &&
          other.restSoundEnabled == this.restSoundEnabled &&
          other.setCheckSoundEnabled == this.setCheckSoundEnabled &&
          other.prAlertEnabled == this.prAlertEnabled &&
          other.lastBackupAt == this.lastBackupAt &&
          other.pendingPickKind == this.pendingPickKind &&
          other.pendingPickRef == this.pendingPickRef &&
          other.themeMode == this.themeMode &&
          other.locale == this.locale &&
          other.onboardingDone == this.onboardingDone &&
          other.exercisesSeeded == this.exercisesSeeded &&
          other.barWeightKg == this.barWeightKg &&
          other.availablePlatesKg == this.availablePlatesKg &&
          other.defaultWarmupSets == this.defaultWarmupSets &&
          other.prDefaultWarmupSets == this.prDefaultWarmupSets &&
          other.prDefaultExtraAttempts == this.prDefaultExtraAttempts &&
          other.autoLockSeconds == this.autoLockSeconds &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsTableCompanion extends UpdateCompanion<AppSettingsRow> {
  final Value<String> id;
  final Value<String> unitWeight;
  final Value<String> unitLength;
  final Value<String> unitDistance;
  final Value<int> defaultRestSeconds;
  final Value<bool> restSoundEnabled;
  final Value<bool> setCheckSoundEnabled;
  final Value<bool> prAlertEnabled;
  final Value<int?> lastBackupAt;
  final Value<String?> pendingPickKind;
  final Value<String?> pendingPickRef;
  final Value<String> themeMode;
  final Value<String> locale;
  final Value<bool> onboardingDone;
  final Value<bool> exercisesSeeded;
  final Value<double> barWeightKg;
  final Value<String> availablePlatesKg;
  final Value<int> defaultWarmupSets;
  final Value<int> prDefaultWarmupSets;
  final Value<int> prDefaultExtraAttempts;
  final Value<int> autoLockSeconds;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AppSettingsTableCompanion({
    this.id = const Value.absent(),
    this.unitWeight = const Value.absent(),
    this.unitLength = const Value.absent(),
    this.unitDistance = const Value.absent(),
    this.defaultRestSeconds = const Value.absent(),
    this.restSoundEnabled = const Value.absent(),
    this.setCheckSoundEnabled = const Value.absent(),
    this.prAlertEnabled = const Value.absent(),
    this.lastBackupAt = const Value.absent(),
    this.pendingPickKind = const Value.absent(),
    this.pendingPickRef = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.locale = const Value.absent(),
    this.onboardingDone = const Value.absent(),
    this.exercisesSeeded = const Value.absent(),
    this.barWeightKg = const Value.absent(),
    this.availablePlatesKg = const Value.absent(),
    this.defaultWarmupSets = const Value.absent(),
    this.prDefaultWarmupSets = const Value.absent(),
    this.prDefaultExtraAttempts = const Value.absent(),
    this.autoLockSeconds = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsTableCompanion.insert({
    required String id,
    this.unitWeight = const Value.absent(),
    this.unitLength = const Value.absent(),
    this.unitDistance = const Value.absent(),
    this.defaultRestSeconds = const Value.absent(),
    this.restSoundEnabled = const Value.absent(),
    this.setCheckSoundEnabled = const Value.absent(),
    this.prAlertEnabled = const Value.absent(),
    this.lastBackupAt = const Value.absent(),
    this.pendingPickKind = const Value.absent(),
    this.pendingPickRef = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.locale = const Value.absent(),
    this.onboardingDone = const Value.absent(),
    this.exercisesSeeded = const Value.absent(),
    this.barWeightKg = const Value.absent(),
    this.availablePlatesKg = const Value.absent(),
    this.defaultWarmupSets = const Value.absent(),
    this.prDefaultWarmupSets = const Value.absent(),
    this.prDefaultExtraAttempts = const Value.absent(),
    this.autoLockSeconds = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<AppSettingsRow> custom({
    Expression<String>? id,
    Expression<String>? unitWeight,
    Expression<String>? unitLength,
    Expression<String>? unitDistance,
    Expression<int>? defaultRestSeconds,
    Expression<bool>? restSoundEnabled,
    Expression<bool>? setCheckSoundEnabled,
    Expression<bool>? prAlertEnabled,
    Expression<int>? lastBackupAt,
    Expression<String>? pendingPickKind,
    Expression<String>? pendingPickRef,
    Expression<String>? themeMode,
    Expression<String>? locale,
    Expression<bool>? onboardingDone,
    Expression<bool>? exercisesSeeded,
    Expression<double>? barWeightKg,
    Expression<String>? availablePlatesKg,
    Expression<int>? defaultWarmupSets,
    Expression<int>? prDefaultWarmupSets,
    Expression<int>? prDefaultExtraAttempts,
    Expression<int>? autoLockSeconds,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (unitWeight != null) 'unit_weight': unitWeight,
      if (unitLength != null) 'unit_length': unitLength,
      if (unitDistance != null) 'unit_distance': unitDistance,
      if (defaultRestSeconds != null)
        'default_rest_seconds': defaultRestSeconds,
      if (restSoundEnabled != null) 'rest_sound_enabled': restSoundEnabled,
      if (setCheckSoundEnabled != null)
        'set_check_sound_enabled': setCheckSoundEnabled,
      if (prAlertEnabled != null) 'pr_alert_enabled': prAlertEnabled,
      if (lastBackupAt != null) 'last_backup_at': lastBackupAt,
      if (pendingPickKind != null) 'pending_pick_kind': pendingPickKind,
      if (pendingPickRef != null) 'pending_pick_ref': pendingPickRef,
      if (themeMode != null) 'theme_mode': themeMode,
      if (locale != null) 'locale': locale,
      if (onboardingDone != null) 'onboarding_done': onboardingDone,
      if (exercisesSeeded != null) 'exercises_seeded': exercisesSeeded,
      if (barWeightKg != null) 'bar_weight_kg': barWeightKg,
      if (availablePlatesKg != null) 'available_plates_kg': availablePlatesKg,
      if (defaultWarmupSets != null) 'default_warmup_sets': defaultWarmupSets,
      if (prDefaultWarmupSets != null)
        'pr_default_warmup_sets': prDefaultWarmupSets,
      if (prDefaultExtraAttempts != null)
        'pr_default_extra_attempts': prDefaultExtraAttempts,
      if (autoLockSeconds != null) 'auto_lock_seconds': autoLockSeconds,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? unitWeight,
    Value<String>? unitLength,
    Value<String>? unitDistance,
    Value<int>? defaultRestSeconds,
    Value<bool>? restSoundEnabled,
    Value<bool>? setCheckSoundEnabled,
    Value<bool>? prAlertEnabled,
    Value<int?>? lastBackupAt,
    Value<String?>? pendingPickKind,
    Value<String?>? pendingPickRef,
    Value<String>? themeMode,
    Value<String>? locale,
    Value<bool>? onboardingDone,
    Value<bool>? exercisesSeeded,
    Value<double>? barWeightKg,
    Value<String>? availablePlatesKg,
    Value<int>? defaultWarmupSets,
    Value<int>? prDefaultWarmupSets,
    Value<int>? prDefaultExtraAttempts,
    Value<int>? autoLockSeconds,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsTableCompanion(
      id: id ?? this.id,
      unitWeight: unitWeight ?? this.unitWeight,
      unitLength: unitLength ?? this.unitLength,
      unitDistance: unitDistance ?? this.unitDistance,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      restSoundEnabled: restSoundEnabled ?? this.restSoundEnabled,
      setCheckSoundEnabled: setCheckSoundEnabled ?? this.setCheckSoundEnabled,
      prAlertEnabled: prAlertEnabled ?? this.prAlertEnabled,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      pendingPickKind: pendingPickKind ?? this.pendingPickKind,
      pendingPickRef: pendingPickRef ?? this.pendingPickRef,
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      exercisesSeeded: exercisesSeeded ?? this.exercisesSeeded,
      barWeightKg: barWeightKg ?? this.barWeightKg,
      availablePlatesKg: availablePlatesKg ?? this.availablePlatesKg,
      defaultWarmupSets: defaultWarmupSets ?? this.defaultWarmupSets,
      prDefaultWarmupSets: prDefaultWarmupSets ?? this.prDefaultWarmupSets,
      prDefaultExtraAttempts:
          prDefaultExtraAttempts ?? this.prDefaultExtraAttempts,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (unitWeight.present) {
      map['unit_weight'] = Variable<String>(unitWeight.value);
    }
    if (unitLength.present) {
      map['unit_length'] = Variable<String>(unitLength.value);
    }
    if (unitDistance.present) {
      map['unit_distance'] = Variable<String>(unitDistance.value);
    }
    if (defaultRestSeconds.present) {
      map['default_rest_seconds'] = Variable<int>(defaultRestSeconds.value);
    }
    if (restSoundEnabled.present) {
      map['rest_sound_enabled'] = Variable<bool>(restSoundEnabled.value);
    }
    if (setCheckSoundEnabled.present) {
      map['set_check_sound_enabled'] = Variable<bool>(
        setCheckSoundEnabled.value,
      );
    }
    if (prAlertEnabled.present) {
      map['pr_alert_enabled'] = Variable<bool>(prAlertEnabled.value);
    }
    if (lastBackupAt.present) {
      map['last_backup_at'] = Variable<int>(lastBackupAt.value);
    }
    if (pendingPickKind.present) {
      map['pending_pick_kind'] = Variable<String>(pendingPickKind.value);
    }
    if (pendingPickRef.present) {
      map['pending_pick_ref'] = Variable<String>(pendingPickRef.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (locale.present) {
      map['locale'] = Variable<String>(locale.value);
    }
    if (onboardingDone.present) {
      map['onboarding_done'] = Variable<bool>(onboardingDone.value);
    }
    if (exercisesSeeded.present) {
      map['exercises_seeded'] = Variable<bool>(exercisesSeeded.value);
    }
    if (barWeightKg.present) {
      map['bar_weight_kg'] = Variable<double>(barWeightKg.value);
    }
    if (availablePlatesKg.present) {
      map['available_plates_kg'] = Variable<String>(availablePlatesKg.value);
    }
    if (defaultWarmupSets.present) {
      map['default_warmup_sets'] = Variable<int>(defaultWarmupSets.value);
    }
    if (prDefaultWarmupSets.present) {
      map['pr_default_warmup_sets'] = Variable<int>(prDefaultWarmupSets.value);
    }
    if (prDefaultExtraAttempts.present) {
      map['pr_default_extra_attempts'] = Variable<int>(
        prDefaultExtraAttempts.value,
      );
    }
    if (autoLockSeconds.present) {
      map['auto_lock_seconds'] = Variable<int>(autoLockSeconds.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsTableCompanion(')
          ..write('id: $id, ')
          ..write('unitWeight: $unitWeight, ')
          ..write('unitLength: $unitLength, ')
          ..write('unitDistance: $unitDistance, ')
          ..write('defaultRestSeconds: $defaultRestSeconds, ')
          ..write('restSoundEnabled: $restSoundEnabled, ')
          ..write('setCheckSoundEnabled: $setCheckSoundEnabled, ')
          ..write('prAlertEnabled: $prAlertEnabled, ')
          ..write('lastBackupAt: $lastBackupAt, ')
          ..write('pendingPickKind: $pendingPickKind, ')
          ..write('pendingPickRef: $pendingPickRef, ')
          ..write('themeMode: $themeMode, ')
          ..write('locale: $locale, ')
          ..write('onboardingDone: $onboardingDone, ')
          ..write('exercisesSeeded: $exercisesSeeded, ')
          ..write('barWeightKg: $barWeightKg, ')
          ..write('availablePlatesKg: $availablePlatesKg, ')
          ..write('defaultWarmupSets: $defaultWarmupSets, ')
          ..write('prDefaultWarmupSets: $prDefaultWarmupSets, ')
          ..write('prDefaultExtraAttempts: $prDefaultExtraAttempts, ')
          ..write('autoLockSeconds: $autoLockSeconds, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTableTable extends ExercisesTable
    with TableInfo<$ExercisesTableTable, ExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _primaryMuscleMeta = const VerificationMeta(
    'primaryMuscle',
  );
  @override
  late final GeneratedColumn<String> primaryMuscle = GeneratedColumn<String>(
    'primary_muscle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secondaryMusclesMeta = const VerificationMeta(
    'secondaryMuscles',
  );
  @override
  late final GeneratedColumn<String> secondaryMuscles = GeneratedColumn<String>(
    'secondary_muscles',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _equipmentMeta = const VerificationMeta(
    'equipment',
  );
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
    'equipment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instructionsMeta = const VerificationMeta(
    'instructions',
  );
  @override
  late final GeneratedColumn<String> instructions = GeneratedColumn<String>(
    'instructions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageAssetMeta = const VerificationMeta(
    'imageAsset',
  );
  @override
  late final GeneratedColumn<String> imageAsset = GeneratedColumn<String>(
    'image_asset',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startImageFileMeta = const VerificationMeta(
    'startImageFile',
  );
  @override
  late final GeneratedColumn<String> startImageFile = GeneratedColumn<String>(
    'start_image_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endImageFileMeta = const VerificationMeta(
    'endImageFile',
  );
  @override
  late final GeneratedColumn<String> endImageFile = GeneratedColumn<String>(
    'end_image_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    primaryMuscle,
    secondaryMuscles,
    equipment,
    category,
    instructions,
    imageAsset,
    startImageFile,
    endImageFile,
    isCustom,
    isArchived,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('primary_muscle')) {
      context.handle(
        _primaryMuscleMeta,
        primaryMuscle.isAcceptableOrUnknown(
          data['primary_muscle']!,
          _primaryMuscleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_primaryMuscleMeta);
    }
    if (data.containsKey('secondary_muscles')) {
      context.handle(
        _secondaryMusclesMeta,
        secondaryMuscles.isAcceptableOrUnknown(
          data['secondary_muscles']!,
          _secondaryMusclesMeta,
        ),
      );
    }
    if (data.containsKey('equipment')) {
      context.handle(
        _equipmentMeta,
        equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('instructions')) {
      context.handle(
        _instructionsMeta,
        instructions.isAcceptableOrUnknown(
          data['instructions']!,
          _instructionsMeta,
        ),
      );
    }
    if (data.containsKey('image_asset')) {
      context.handle(
        _imageAssetMeta,
        imageAsset.isAcceptableOrUnknown(data['image_asset']!, _imageAssetMeta),
      );
    }
    if (data.containsKey('start_image_file')) {
      context.handle(
        _startImageFileMeta,
        startImageFile.isAcceptableOrUnknown(
          data['start_image_file']!,
          _startImageFileMeta,
        ),
      );
    }
    if (data.containsKey('end_image_file')) {
      context.handle(
        _endImageFileMeta,
        endImageFile.isAcceptableOrUnknown(
          data['end_image_file']!,
          _endImageFileMeta,
        ),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      primaryMuscle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_muscle'],
      )!,
      secondaryMuscles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_muscles'],
      )!,
      equipment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      instructions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instructions'],
      ),
      imageAsset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_asset'],
      ),
      startImageFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_image_file'],
      ),
      endImageFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_image_file'],
      ),
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExercisesTableTable createAlias(String alias) {
    return $ExercisesTableTable(attachedDatabase, alias);
  }
}

class ExerciseRow extends DataClass implements Insertable<ExerciseRow> {
  final String id;
  final String name;
  final String primaryMuscle;

  /// JSON array of muscle names.
  final String secondaryMuscles;
  final String? equipment;

  /// One of [ExerciseCategory].
  final String category;
  final String? instructions;
  final String? imageAsset;

  /// The two frames of a user-made exercise, as file names in the photo
  /// directory. Only the name is stored, for the same reason progress photos
  /// do it that way: the container path changes underneath an absolute one.
  final String? startImageFile;
  final String? endImageFile;
  final bool isCustom;
  final bool isArchived;
  final int createdAt;
  const ExerciseRow({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    this.equipment,
    required this.category,
    this.instructions,
    this.imageAsset,
    this.startImageFile,
    this.endImageFile,
    required this.isCustom,
    required this.isArchived,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['primary_muscle'] = Variable<String>(primaryMuscle);
    map['secondary_muscles'] = Variable<String>(secondaryMuscles);
    if (!nullToAbsent || equipment != null) {
      map['equipment'] = Variable<String>(equipment);
    }
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || instructions != null) {
      map['instructions'] = Variable<String>(instructions);
    }
    if (!nullToAbsent || imageAsset != null) {
      map['image_asset'] = Variable<String>(imageAsset);
    }
    if (!nullToAbsent || startImageFile != null) {
      map['start_image_file'] = Variable<String>(startImageFile);
    }
    if (!nullToAbsent || endImageFile != null) {
      map['end_image_file'] = Variable<String>(endImageFile);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ExercisesTableCompanion toCompanion(bool nullToAbsent) {
    return ExercisesTableCompanion(
      id: Value(id),
      name: Value(name),
      primaryMuscle: Value(primaryMuscle),
      secondaryMuscles: Value(secondaryMuscles),
      equipment: equipment == null && nullToAbsent
          ? const Value.absent()
          : Value(equipment),
      category: Value(category),
      instructions: instructions == null && nullToAbsent
          ? const Value.absent()
          : Value(instructions),
      imageAsset: imageAsset == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAsset),
      startImageFile: startImageFile == null && nullToAbsent
          ? const Value.absent()
          : Value(startImageFile),
      endImageFile: endImageFile == null && nullToAbsent
          ? const Value.absent()
          : Value(endImageFile),
      isCustom: Value(isCustom),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
    );
  }

  factory ExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      primaryMuscle: serializer.fromJson<String>(json['primaryMuscle']),
      secondaryMuscles: serializer.fromJson<String>(json['secondaryMuscles']),
      equipment: serializer.fromJson<String?>(json['equipment']),
      category: serializer.fromJson<String>(json['category']),
      instructions: serializer.fromJson<String?>(json['instructions']),
      imageAsset: serializer.fromJson<String?>(json['imageAsset']),
      startImageFile: serializer.fromJson<String?>(json['startImageFile']),
      endImageFile: serializer.fromJson<String?>(json['endImageFile']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'primaryMuscle': serializer.toJson<String>(primaryMuscle),
      'secondaryMuscles': serializer.toJson<String>(secondaryMuscles),
      'equipment': serializer.toJson<String?>(equipment),
      'category': serializer.toJson<String>(category),
      'instructions': serializer.toJson<String?>(instructions),
      'imageAsset': serializer.toJson<String?>(imageAsset),
      'startImageFile': serializer.toJson<String?>(startImageFile),
      'endImageFile': serializer.toJson<String?>(endImageFile),
      'isCustom': serializer.toJson<bool>(isCustom),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ExerciseRow copyWith({
    String? id,
    String? name,
    String? primaryMuscle,
    String? secondaryMuscles,
    Value<String?> equipment = const Value.absent(),
    String? category,
    Value<String?> instructions = const Value.absent(),
    Value<String?> imageAsset = const Value.absent(),
    Value<String?> startImageFile = const Value.absent(),
    Value<String?> endImageFile = const Value.absent(),
    bool? isCustom,
    bool? isArchived,
    int? createdAt,
  }) => ExerciseRow(
    id: id ?? this.id,
    name: name ?? this.name,
    primaryMuscle: primaryMuscle ?? this.primaryMuscle,
    secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
    equipment: equipment.present ? equipment.value : this.equipment,
    category: category ?? this.category,
    instructions: instructions.present ? instructions.value : this.instructions,
    imageAsset: imageAsset.present ? imageAsset.value : this.imageAsset,
    startImageFile: startImageFile.present
        ? startImageFile.value
        : this.startImageFile,
    endImageFile: endImageFile.present ? endImageFile.value : this.endImageFile,
    isCustom: isCustom ?? this.isCustom,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
  );
  ExerciseRow copyWithCompanion(ExercisesTableCompanion data) {
    return ExerciseRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      primaryMuscle: data.primaryMuscle.present
          ? data.primaryMuscle.value
          : this.primaryMuscle,
      secondaryMuscles: data.secondaryMuscles.present
          ? data.secondaryMuscles.value
          : this.secondaryMuscles,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      category: data.category.present ? data.category.value : this.category,
      instructions: data.instructions.present
          ? data.instructions.value
          : this.instructions,
      imageAsset: data.imageAsset.present
          ? data.imageAsset.value
          : this.imageAsset,
      startImageFile: data.startImageFile.present
          ? data.startImageFile.value
          : this.startImageFile,
      endImageFile: data.endImageFile.present
          ? data.endImageFile.value
          : this.endImageFile,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('primaryMuscle: $primaryMuscle, ')
          ..write('secondaryMuscles: $secondaryMuscles, ')
          ..write('equipment: $equipment, ')
          ..write('category: $category, ')
          ..write('instructions: $instructions, ')
          ..write('imageAsset: $imageAsset, ')
          ..write('startImageFile: $startImageFile, ')
          ..write('endImageFile: $endImageFile, ')
          ..write('isCustom: $isCustom, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    primaryMuscle,
    secondaryMuscles,
    equipment,
    category,
    instructions,
    imageAsset,
    startImageFile,
    endImageFile,
    isCustom,
    isArchived,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.primaryMuscle == this.primaryMuscle &&
          other.secondaryMuscles == this.secondaryMuscles &&
          other.equipment == this.equipment &&
          other.category == this.category &&
          other.instructions == this.instructions &&
          other.imageAsset == this.imageAsset &&
          other.startImageFile == this.startImageFile &&
          other.endImageFile == this.endImageFile &&
          other.isCustom == this.isCustom &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt);
}

class ExercisesTableCompanion extends UpdateCompanion<ExerciseRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> primaryMuscle;
  final Value<String> secondaryMuscles;
  final Value<String?> equipment;
  final Value<String> category;
  final Value<String?> instructions;
  final Value<String?> imageAsset;
  final Value<String?> startImageFile;
  final Value<String?> endImageFile;
  final Value<bool> isCustom;
  final Value<bool> isArchived;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ExercisesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.primaryMuscle = const Value.absent(),
    this.secondaryMuscles = const Value.absent(),
    this.equipment = const Value.absent(),
    this.category = const Value.absent(),
    this.instructions = const Value.absent(),
    this.imageAsset = const Value.absent(),
    this.startImageFile = const Value.absent(),
    this.endImageFile = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExercisesTableCompanion.insert({
    required String id,
    required String name,
    required String primaryMuscle,
    this.secondaryMuscles = const Value.absent(),
    this.equipment = const Value.absent(),
    required String category,
    this.instructions = const Value.absent(),
    this.imageAsset = const Value.absent(),
    this.startImageFile = const Value.absent(),
    this.endImageFile = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isArchived = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       primaryMuscle = Value(primaryMuscle),
       category = Value(category),
       createdAt = Value(createdAt);
  static Insertable<ExerciseRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? primaryMuscle,
    Expression<String>? secondaryMuscles,
    Expression<String>? equipment,
    Expression<String>? category,
    Expression<String>? instructions,
    Expression<String>? imageAsset,
    Expression<String>? startImageFile,
    Expression<String>? endImageFile,
    Expression<bool>? isCustom,
    Expression<bool>? isArchived,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (primaryMuscle != null) 'primary_muscle': primaryMuscle,
      if (secondaryMuscles != null) 'secondary_muscles': secondaryMuscles,
      if (equipment != null) 'equipment': equipment,
      if (category != null) 'category': category,
      if (instructions != null) 'instructions': instructions,
      if (imageAsset != null) 'image_asset': imageAsset,
      if (startImageFile != null) 'start_image_file': startImageFile,
      if (endImageFile != null) 'end_image_file': endImageFile,
      if (isCustom != null) 'is_custom': isCustom,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExercisesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? primaryMuscle,
    Value<String>? secondaryMuscles,
    Value<String?>? equipment,
    Value<String>? category,
    Value<String?>? instructions,
    Value<String?>? imageAsset,
    Value<String?>? startImageFile,
    Value<String?>? endImageFile,
    Value<bool>? isCustom,
    Value<bool>? isArchived,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ExercisesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryMuscle: primaryMuscle ?? this.primaryMuscle,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipment: equipment ?? this.equipment,
      category: category ?? this.category,
      instructions: instructions ?? this.instructions,
      imageAsset: imageAsset ?? this.imageAsset,
      startImageFile: startImageFile ?? this.startImageFile,
      endImageFile: endImageFile ?? this.endImageFile,
      isCustom: isCustom ?? this.isCustom,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (primaryMuscle.present) {
      map['primary_muscle'] = Variable<String>(primaryMuscle.value);
    }
    if (secondaryMuscles.present) {
      map['secondary_muscles'] = Variable<String>(secondaryMuscles.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (instructions.present) {
      map['instructions'] = Variable<String>(instructions.value);
    }
    if (imageAsset.present) {
      map['image_asset'] = Variable<String>(imageAsset.value);
    }
    if (startImageFile.present) {
      map['start_image_file'] = Variable<String>(startImageFile.value);
    }
    if (endImageFile.present) {
      map['end_image_file'] = Variable<String>(endImageFile.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('primaryMuscle: $primaryMuscle, ')
          ..write('secondaryMuscles: $secondaryMuscles, ')
          ..write('equipment: $equipment, ')
          ..write('category: $category, ')
          ..write('instructions: $instructions, ')
          ..write('imageAsset: $imageAsset, ')
          ..write('startImageFile: $startImageFile, ')
          ..write('endImageFile: $endImageFile, ')
          ..write('isCustom: $isCustom, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutineFoldersTableTable extends RoutineFoldersTable
    with TableInfo<$RoutineFoldersTableTable, RoutineFolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineFoldersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutineFolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineFolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineFolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $RoutineFoldersTableTable createAlias(String alias) {
    return $RoutineFoldersTableTable(attachedDatabase, alias);
  }
}

class RoutineFolderRow extends DataClass
    implements Insertable<RoutineFolderRow> {
  final String id;
  final String name;
  final int sortOrder;
  const RoutineFolderRow({
    required this.id,
    required this.name,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  RoutineFoldersTableCompanion toCompanion(bool nullToAbsent) {
    return RoutineFoldersTableCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
    );
  }

  factory RoutineFolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineFolderRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  RoutineFolderRow copyWith({String? id, String? name, int? sortOrder}) =>
      RoutineFolderRow(
        id: id ?? this.id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  RoutineFolderRow copyWithCompanion(RoutineFoldersTableCompanion data) {
    return RoutineFolderRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineFolderRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineFolderRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class RoutineFoldersTableCompanion extends UpdateCompanion<RoutineFolderRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const RoutineFoldersTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutineFoldersTableCompanion.insert({
    required String id,
    required String name,
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sortOrder = Value(sortOrder);
  static Insertable<RoutineFolderRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutineFoldersTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return RoutineFoldersTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineFoldersTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutinesTableTable extends RoutinesTable
    with TableInfo<$RoutinesTableTable, RoutineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutinesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES routine_folders (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPerformedAtMeta = const VerificationMeta(
    'lastPerformedAt',
  );
  @override
  late final GeneratedColumn<int> lastPerformedAt = GeneratedColumn<int>(
    'last_performed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    notes,
    folderId,
    sortOrder,
    createdAt,
    updatedAt,
    lastPerformedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routines';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_performed_at')) {
      context.handle(
        _lastPerformedAtMeta,
        lastPerformedAt.isAcceptableOrUnknown(
          data['last_performed_at']!,
          _lastPerformedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      lastPerformedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_performed_at'],
      ),
    );
  }

  @override
  $RoutinesTableTable createAlias(String alias) {
    return $RoutinesTableTable(attachedDatabase, alias);
  }
}

class RoutineRow extends DataClass implements Insertable<RoutineRow> {
  final String id;
  final String name;
  final String? notes;
  final String? folderId;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final int? lastPerformedAt;
  const RoutineRow({
    required this.id,
    required this.name,
    this.notes,
    this.folderId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.lastPerformedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || lastPerformedAt != null) {
      map['last_performed_at'] = Variable<int>(lastPerformedAt);
    }
    return map;
  }

  RoutinesTableCompanion toCompanion(bool nullToAbsent) {
    return RoutinesTableCompanion(
      id: Value(id),
      name: Value(name),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastPerformedAt: lastPerformedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPerformedAt),
    );
  }

  factory RoutineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String?>(json['notes']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      lastPerformedAt: serializer.fromJson<int?>(json['lastPerformedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String?>(notes),
      'folderId': serializer.toJson<String?>(folderId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'lastPerformedAt': serializer.toJson<int?>(lastPerformedAt),
    };
  }

  RoutineRow copyWith({
    String? id,
    String? name,
    Value<String?> notes = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    Value<int?> lastPerformedAt = const Value.absent(),
  }) => RoutineRow(
    id: id ?? this.id,
    name: name ?? this.name,
    notes: notes.present ? notes.value : this.notes,
    folderId: folderId.present ? folderId.value : this.folderId,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastPerformedAt: lastPerformedAt.present
        ? lastPerformedAt.value
        : this.lastPerformedAt,
  );
  RoutineRow copyWithCompanion(RoutinesTableCompanion data) {
    return RoutineRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastPerformedAt: data.lastPerformedAt.present
          ? data.lastPerformedAt.value
          : this.lastPerformedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastPerformedAt: $lastPerformedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    notes,
    folderId,
    sortOrder,
    createdAt,
    updatedAt,
    lastPerformedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.folderId == this.folderId &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastPerformedAt == this.lastPerformedAt);
}

class RoutinesTableCompanion extends UpdateCompanion<RoutineRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> notes;
  final Value<String?> folderId;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> lastPerformedAt;
  final Value<int> rowid;
  const RoutinesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastPerformedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutinesTableCompanion.insert({
    required String id,
    required String name,
    this.notes = const Value.absent(),
    this.folderId = const Value.absent(),
    required int sortOrder,
    required int createdAt,
    required int updatedAt,
    this.lastPerformedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RoutineRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<String>? folderId,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? lastPerformedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (folderId != null) 'folder_id': folderId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastPerformedAt != null) 'last_performed_at': lastPerformedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutinesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? notes,
    Value<String?>? folderId,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? lastPerformedAt,
    Value<int>? rowid,
  }) {
    return RoutinesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      folderId: folderId ?? this.folderId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastPerformedAt: lastPerformedAt ?? this.lastPerformedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (lastPerformedAt.present) {
      map['last_performed_at'] = Variable<int>(lastPerformedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutinesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastPerformedAt: $lastPerformedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutineExercisesTableTable extends RoutineExercisesTable
    with TableInfo<$RoutineExercisesTableTable, RoutineExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineExercisesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
    'routine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES routines (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercises (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _supersetGroupMeta = const VerificationMeta(
    'supersetGroup',
  );
  @override
  late final GeneratedColumn<int> supersetGroup = GeneratedColumn<int>(
    'superset_group',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    exerciseId,
    sortOrder,
    restSeconds,
    supersetGroup,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutineExerciseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    if (data.containsKey('superset_group')) {
      context.handle(
        _supersetGroupMeta,
        supersetGroup.isAcceptableOrUnknown(
          data['superset_group']!,
          _supersetGroupMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineExerciseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      ),
      supersetGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}superset_group'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $RoutineExercisesTableTable createAlias(String alias) {
    return $RoutineExercisesTableTable(attachedDatabase, alias);
  }
}

class RoutineExerciseRow extends DataClass
    implements Insertable<RoutineExerciseRow> {
  final String id;
  final String routineId;
  final String exerciseId;
  final int sortOrder;
  final int? restSeconds;
  final int? supersetGroup;
  final String? notes;
  const RoutineExerciseRow({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    required this.sortOrder,
    this.restSeconds,
    this.supersetGroup,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['routine_id'] = Variable<String>(routineId);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || restSeconds != null) {
      map['rest_seconds'] = Variable<int>(restSeconds);
    }
    if (!nullToAbsent || supersetGroup != null) {
      map['superset_group'] = Variable<int>(supersetGroup);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  RoutineExercisesTableCompanion toCompanion(bool nullToAbsent) {
    return RoutineExercisesTableCompanion(
      id: Value(id),
      routineId: Value(routineId),
      exerciseId: Value(exerciseId),
      sortOrder: Value(sortOrder),
      restSeconds: restSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(restSeconds),
      supersetGroup: supersetGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(supersetGroup),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory RoutineExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineExerciseRow(
      id: serializer.fromJson<String>(json['id']),
      routineId: serializer.fromJson<String>(json['routineId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      restSeconds: serializer.fromJson<int?>(json['restSeconds']),
      supersetGroup: serializer.fromJson<int?>(json['supersetGroup']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routineId': serializer.toJson<String>(routineId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'restSeconds': serializer.toJson<int?>(restSeconds),
      'supersetGroup': serializer.toJson<int?>(supersetGroup),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  RoutineExerciseRow copyWith({
    String? id,
    String? routineId,
    String? exerciseId,
    int? sortOrder,
    Value<int?> restSeconds = const Value.absent(),
    Value<int?> supersetGroup = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => RoutineExerciseRow(
    id: id ?? this.id,
    routineId: routineId ?? this.routineId,
    exerciseId: exerciseId ?? this.exerciseId,
    sortOrder: sortOrder ?? this.sortOrder,
    restSeconds: restSeconds.present ? restSeconds.value : this.restSeconds,
    supersetGroup: supersetGroup.present
        ? supersetGroup.value
        : this.supersetGroup,
    notes: notes.present ? notes.value : this.notes,
  );
  RoutineExerciseRow copyWithCompanion(RoutineExercisesTableCompanion data) {
    return RoutineExerciseRow(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
      supersetGroup: data.supersetGroup.present
          ? data.supersetGroup.value
          : this.supersetGroup,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineExerciseRow(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('supersetGroup: $supersetGroup, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    routineId,
    exerciseId,
    sortOrder,
    restSeconds,
    supersetGroup,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineExerciseRow &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.exerciseId == this.exerciseId &&
          other.sortOrder == this.sortOrder &&
          other.restSeconds == this.restSeconds &&
          other.supersetGroup == this.supersetGroup &&
          other.notes == this.notes);
}

class RoutineExercisesTableCompanion
    extends UpdateCompanion<RoutineExerciseRow> {
  final Value<String> id;
  final Value<String> routineId;
  final Value<String> exerciseId;
  final Value<int> sortOrder;
  final Value<int?> restSeconds;
  final Value<int?> supersetGroup;
  final Value<String?> notes;
  final Value<int> rowid;
  const RoutineExercisesTableCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.supersetGroup = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutineExercisesTableCompanion.insert({
    required String id,
    required String routineId,
    required String exerciseId,
    required int sortOrder,
    this.restSeconds = const Value.absent(),
    this.supersetGroup = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       routineId = Value(routineId),
       exerciseId = Value(exerciseId),
       sortOrder = Value(sortOrder);
  static Insertable<RoutineExerciseRow> custom({
    Expression<String>? id,
    Expression<String>? routineId,
    Expression<String>? exerciseId,
    Expression<int>? sortOrder,
    Expression<int>? restSeconds,
    Expression<int>? supersetGroup,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (supersetGroup != null) 'superset_group': supersetGroup,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutineExercisesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? routineId,
    Value<String>? exerciseId,
    Value<int>? sortOrder,
    Value<int?>? restSeconds,
    Value<int?>? supersetGroup,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return RoutineExercisesTableCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      exerciseId: exerciseId ?? this.exerciseId,
      sortOrder: sortOrder ?? this.sortOrder,
      restSeconds: restSeconds ?? this.restSeconds,
      supersetGroup: supersetGroup ?? this.supersetGroup,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    if (supersetGroup.present) {
      map['superset_group'] = Variable<int>(supersetGroup.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineExercisesTableCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('supersetGroup: $supersetGroup, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutineSetsTableTable extends RoutineSetsTable
    with TableInfo<$RoutineSetsTableTable, RoutineSetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineSetsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineExerciseIdMeta = const VerificationMeta(
    'routineExerciseId',
  );
  @override
  late final GeneratedColumn<String> routineExerciseId =
      GeneratedColumn<String>(
        'routine_exercise_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES routine_exercises (id) ON DELETE CASCADE',
        ),
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setTypeMeta = const VerificationMeta(
    'setType',
  );
  @override
  late final GeneratedColumn<String> setType = GeneratedColumn<String>(
    'set_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  static const VerificationMeta _targetRepsMeta = const VerificationMeta(
    'targetReps',
  );
  @override
  late final GeneratedColumn<int> targetReps = GeneratedColumn<int>(
    'target_reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetWeightKgMeta = const VerificationMeta(
    'targetWeightKg',
  );
  @override
  late final GeneratedColumn<double> targetWeightKg = GeneratedColumn<double>(
    'target_weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetDurationSecondsMeta =
      const VerificationMeta('targetDurationSeconds');
  @override
  late final GeneratedColumn<int> targetDurationSeconds = GeneratedColumn<int>(
    'target_duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineExerciseId,
    sortOrder,
    setType,
    targetReps,
    targetWeightKg,
    targetDurationSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutineSetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('routine_exercise_id')) {
      context.handle(
        _routineExerciseIdMeta,
        routineExerciseId.isAcceptableOrUnknown(
          data['routine_exercise_id']!,
          _routineExerciseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_routineExerciseIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('set_type')) {
      context.handle(
        _setTypeMeta,
        setType.isAcceptableOrUnknown(data['set_type']!, _setTypeMeta),
      );
    }
    if (data.containsKey('target_reps')) {
      context.handle(
        _targetRepsMeta,
        targetReps.isAcceptableOrUnknown(data['target_reps']!, _targetRepsMeta),
      );
    }
    if (data.containsKey('target_weight_kg')) {
      context.handle(
        _targetWeightKgMeta,
        targetWeightKg.isAcceptableOrUnknown(
          data['target_weight_kg']!,
          _targetWeightKgMeta,
        ),
      );
    }
    if (data.containsKey('target_duration_seconds')) {
      context.handle(
        _targetDurationSecondsMeta,
        targetDurationSeconds.isAcceptableOrUnknown(
          data['target_duration_seconds']!,
          _targetDurationSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineSetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineSetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routineExerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_exercise_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      setType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_type'],
      )!,
      targetReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_reps'],
      ),
      targetWeightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_weight_kg'],
      ),
      targetDurationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_duration_seconds'],
      ),
    );
  }

  @override
  $RoutineSetsTableTable createAlias(String alias) {
    return $RoutineSetsTableTable(attachedDatabase, alias);
  }
}

class RoutineSetRow extends DataClass implements Insertable<RoutineSetRow> {
  final String id;
  final String routineExerciseId;
  final int sortOrder;

  /// One of [SetType].
  final String setType;
  final int? targetReps;
  final double? targetWeightKg;
  final int? targetDurationSeconds;
  const RoutineSetRow({
    required this.id,
    required this.routineExerciseId,
    required this.sortOrder,
    required this.setType,
    this.targetReps,
    this.targetWeightKg,
    this.targetDurationSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['routine_exercise_id'] = Variable<String>(routineExerciseId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['set_type'] = Variable<String>(setType);
    if (!nullToAbsent || targetReps != null) {
      map['target_reps'] = Variable<int>(targetReps);
    }
    if (!nullToAbsent || targetWeightKg != null) {
      map['target_weight_kg'] = Variable<double>(targetWeightKg);
    }
    if (!nullToAbsent || targetDurationSeconds != null) {
      map['target_duration_seconds'] = Variable<int>(targetDurationSeconds);
    }
    return map;
  }

  RoutineSetsTableCompanion toCompanion(bool nullToAbsent) {
    return RoutineSetsTableCompanion(
      id: Value(id),
      routineExerciseId: Value(routineExerciseId),
      sortOrder: Value(sortOrder),
      setType: Value(setType),
      targetReps: targetReps == null && nullToAbsent
          ? const Value.absent()
          : Value(targetReps),
      targetWeightKg: targetWeightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(targetWeightKg),
      targetDurationSeconds: targetDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDurationSeconds),
    );
  }

  factory RoutineSetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineSetRow(
      id: serializer.fromJson<String>(json['id']),
      routineExerciseId: serializer.fromJson<String>(json['routineExerciseId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      setType: serializer.fromJson<String>(json['setType']),
      targetReps: serializer.fromJson<int?>(json['targetReps']),
      targetWeightKg: serializer.fromJson<double?>(json['targetWeightKg']),
      targetDurationSeconds: serializer.fromJson<int?>(
        json['targetDurationSeconds'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routineExerciseId': serializer.toJson<String>(routineExerciseId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'setType': serializer.toJson<String>(setType),
      'targetReps': serializer.toJson<int?>(targetReps),
      'targetWeightKg': serializer.toJson<double?>(targetWeightKg),
      'targetDurationSeconds': serializer.toJson<int?>(targetDurationSeconds),
    };
  }

  RoutineSetRow copyWith({
    String? id,
    String? routineExerciseId,
    int? sortOrder,
    String? setType,
    Value<int?> targetReps = const Value.absent(),
    Value<double?> targetWeightKg = const Value.absent(),
    Value<int?> targetDurationSeconds = const Value.absent(),
  }) => RoutineSetRow(
    id: id ?? this.id,
    routineExerciseId: routineExerciseId ?? this.routineExerciseId,
    sortOrder: sortOrder ?? this.sortOrder,
    setType: setType ?? this.setType,
    targetReps: targetReps.present ? targetReps.value : this.targetReps,
    targetWeightKg: targetWeightKg.present
        ? targetWeightKg.value
        : this.targetWeightKg,
    targetDurationSeconds: targetDurationSeconds.present
        ? targetDurationSeconds.value
        : this.targetDurationSeconds,
  );
  RoutineSetRow copyWithCompanion(RoutineSetsTableCompanion data) {
    return RoutineSetRow(
      id: data.id.present ? data.id.value : this.id,
      routineExerciseId: data.routineExerciseId.present
          ? data.routineExerciseId.value
          : this.routineExerciseId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      setType: data.setType.present ? data.setType.value : this.setType,
      targetReps: data.targetReps.present
          ? data.targetReps.value
          : this.targetReps,
      targetWeightKg: data.targetWeightKg.present
          ? data.targetWeightKg.value
          : this.targetWeightKg,
      targetDurationSeconds: data.targetDurationSeconds.present
          ? data.targetDurationSeconds.value
          : this.targetDurationSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineSetRow(')
          ..write('id: $id, ')
          ..write('routineExerciseId: $routineExerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('setType: $setType, ')
          ..write('targetReps: $targetReps, ')
          ..write('targetWeightKg: $targetWeightKg, ')
          ..write('targetDurationSeconds: $targetDurationSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    routineExerciseId,
    sortOrder,
    setType,
    targetReps,
    targetWeightKg,
    targetDurationSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineSetRow &&
          other.id == this.id &&
          other.routineExerciseId == this.routineExerciseId &&
          other.sortOrder == this.sortOrder &&
          other.setType == this.setType &&
          other.targetReps == this.targetReps &&
          other.targetWeightKg == this.targetWeightKg &&
          other.targetDurationSeconds == this.targetDurationSeconds);
}

class RoutineSetsTableCompanion extends UpdateCompanion<RoutineSetRow> {
  final Value<String> id;
  final Value<String> routineExerciseId;
  final Value<int> sortOrder;
  final Value<String> setType;
  final Value<int?> targetReps;
  final Value<double?> targetWeightKg;
  final Value<int?> targetDurationSeconds;
  final Value<int> rowid;
  const RoutineSetsTableCompanion({
    this.id = const Value.absent(),
    this.routineExerciseId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.setType = const Value.absent(),
    this.targetReps = const Value.absent(),
    this.targetWeightKg = const Value.absent(),
    this.targetDurationSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutineSetsTableCompanion.insert({
    required String id,
    required String routineExerciseId,
    required int sortOrder,
    this.setType = const Value.absent(),
    this.targetReps = const Value.absent(),
    this.targetWeightKg = const Value.absent(),
    this.targetDurationSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       routineExerciseId = Value(routineExerciseId),
       sortOrder = Value(sortOrder);
  static Insertable<RoutineSetRow> custom({
    Expression<String>? id,
    Expression<String>? routineExerciseId,
    Expression<int>? sortOrder,
    Expression<String>? setType,
    Expression<int>? targetReps,
    Expression<double>? targetWeightKg,
    Expression<int>? targetDurationSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineExerciseId != null) 'routine_exercise_id': routineExerciseId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (setType != null) 'set_type': setType,
      if (targetReps != null) 'target_reps': targetReps,
      if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
      if (targetDurationSeconds != null)
        'target_duration_seconds': targetDurationSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutineSetsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? routineExerciseId,
    Value<int>? sortOrder,
    Value<String>? setType,
    Value<int?>? targetReps,
    Value<double?>? targetWeightKg,
    Value<int?>? targetDurationSeconds,
    Value<int>? rowid,
  }) {
    return RoutineSetsTableCompanion(
      id: id ?? this.id,
      routineExerciseId: routineExerciseId ?? this.routineExerciseId,
      sortOrder: sortOrder ?? this.sortOrder,
      setType: setType ?? this.setType,
      targetReps: targetReps ?? this.targetReps,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      targetDurationSeconds:
          targetDurationSeconds ?? this.targetDurationSeconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routineExerciseId.present) {
      map['routine_exercise_id'] = Variable<String>(routineExerciseId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (setType.present) {
      map['set_type'] = Variable<String>(setType.value);
    }
    if (targetReps.present) {
      map['target_reps'] = Variable<int>(targetReps.value);
    }
    if (targetWeightKg.present) {
      map['target_weight_kg'] = Variable<double>(targetWeightKg.value);
    }
    if (targetDurationSeconds.present) {
      map['target_duration_seconds'] = Variable<int>(
        targetDurationSeconds.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineSetsTableCompanion(')
          ..write('id: $id, ')
          ..write('routineExerciseId: $routineExerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('setType: $setType, ')
          ..write('targetReps: $targetReps, ')
          ..write('targetWeightKg: $targetWeightKg, ')
          ..write('targetDurationSeconds: $targetDurationSeconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutsTableTable extends WorkoutsTable
    with TableInfo<$WorkoutsTableTable, WorkoutRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
    'routine_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES routines (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalVolumeKgMeta = const VerificationMeta(
    'totalVolumeKg',
  );
  @override
  late final GeneratedColumn<double> totalVolumeKg = GeneratedColumn<double>(
    'total_volume_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalSetsMeta = const VerificationMeta(
    'totalSets',
  );
  @override
  late final GeneratedColumn<int> totalSets = GeneratedColumn<int>(
    'total_sets',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _perceivedEffortMeta = const VerificationMeta(
    'perceivedEffort',
  );
  @override
  late final GeneratedColumn<String> perceivedEffort = GeneratedColumn<String>(
    'perceived_effort',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    name,
    startedAt,
    endedAt,
    notes,
    totalVolumeKg,
    totalSets,
    perceivedEffort,
    durationSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workouts';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('total_volume_kg')) {
      context.handle(
        _totalVolumeKgMeta,
        totalVolumeKg.isAcceptableOrUnknown(
          data['total_volume_kg']!,
          _totalVolumeKgMeta,
        ),
      );
    }
    if (data.containsKey('total_sets')) {
      context.handle(
        _totalSetsMeta,
        totalSets.isAcceptableOrUnknown(data['total_sets']!, _totalSetsMeta),
      );
    }
    if (data.containsKey('perceived_effort')) {
      context.handle(
        _perceivedEffortMeta,
        perceivedEffort.isAcceptableOrUnknown(
          data['perceived_effort']!,
          _perceivedEffortMeta,
        ),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      totalVolumeKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_volume_kg'],
      )!,
      totalSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_sets'],
      )!,
      perceivedEffort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}perceived_effort'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
    );
  }

  @override
  $WorkoutsTableTable createAlias(String alias) {
    return $WorkoutsTableTable(attachedDatabase, alias);
  }
}

class WorkoutRow extends DataClass implements Insertable<WorkoutRow> {
  final String id;
  final String? routineId;
  final String name;
  final int startedAt;

  /// `NULL` marks the one and only running session.
  final int? endedAt;
  final String? notes;
  final double totalVolumeKg;
  final int totalSets;

  /// One of [PerceivedEffort], or null while the session has not been rated.
  final String? perceivedEffort;
  final int durationSeconds;
  const WorkoutRow({
    required this.id,
    this.routineId,
    required this.name,
    required this.startedAt,
    this.endedAt,
    this.notes,
    required this.totalVolumeKg,
    required this.totalSets,
    this.perceivedEffort,
    required this.durationSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || routineId != null) {
      map['routine_id'] = Variable<String>(routineId);
    }
    map['name'] = Variable<String>(name);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<int>(endedAt);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['total_volume_kg'] = Variable<double>(totalVolumeKg);
    map['total_sets'] = Variable<int>(totalSets);
    if (!nullToAbsent || perceivedEffort != null) {
      map['perceived_effort'] = Variable<String>(perceivedEffort);
    }
    map['duration_seconds'] = Variable<int>(durationSeconds);
    return map;
  }

  WorkoutsTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutsTableCompanion(
      id: Value(id),
      routineId: routineId == null && nullToAbsent
          ? const Value.absent()
          : Value(routineId),
      name: Value(name),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      totalVolumeKg: Value(totalVolumeKg),
      totalSets: Value(totalSets),
      perceivedEffort: perceivedEffort == null && nullToAbsent
          ? const Value.absent()
          : Value(perceivedEffort),
      durationSeconds: Value(durationSeconds),
    );
  }

  factory WorkoutRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutRow(
      id: serializer.fromJson<String>(json['id']),
      routineId: serializer.fromJson<String?>(json['routineId']),
      name: serializer.fromJson<String>(json['name']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int?>(json['endedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      totalVolumeKg: serializer.fromJson<double>(json['totalVolumeKg']),
      totalSets: serializer.fromJson<int>(json['totalSets']),
      perceivedEffort: serializer.fromJson<String?>(json['perceivedEffort']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routineId': serializer.toJson<String?>(routineId),
      'name': serializer.toJson<String>(name),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int?>(endedAt),
      'notes': serializer.toJson<String?>(notes),
      'totalVolumeKg': serializer.toJson<double>(totalVolumeKg),
      'totalSets': serializer.toJson<int>(totalSets),
      'perceivedEffort': serializer.toJson<String?>(perceivedEffort),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
    };
  }

  WorkoutRow copyWith({
    String? id,
    Value<String?> routineId = const Value.absent(),
    String? name,
    int? startedAt,
    Value<int?> endedAt = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    double? totalVolumeKg,
    int? totalSets,
    Value<String?> perceivedEffort = const Value.absent(),
    int? durationSeconds,
  }) => WorkoutRow(
    id: id ?? this.id,
    routineId: routineId.present ? routineId.value : this.routineId,
    name: name ?? this.name,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    notes: notes.present ? notes.value : this.notes,
    totalVolumeKg: totalVolumeKg ?? this.totalVolumeKg,
    totalSets: totalSets ?? this.totalSets,
    perceivedEffort: perceivedEffort.present
        ? perceivedEffort.value
        : this.perceivedEffort,
    durationSeconds: durationSeconds ?? this.durationSeconds,
  );
  WorkoutRow copyWithCompanion(WorkoutsTableCompanion data) {
    return WorkoutRow(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      name: data.name.present ? data.name.value : this.name,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      totalVolumeKg: data.totalVolumeKg.present
          ? data.totalVolumeKg.value
          : this.totalVolumeKg,
      totalSets: data.totalSets.present ? data.totalSets.value : this.totalSets,
      perceivedEffort: data.perceivedEffort.present
          ? data.perceivedEffort.value
          : this.perceivedEffort,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutRow(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('notes: $notes, ')
          ..write('totalVolumeKg: $totalVolumeKg, ')
          ..write('totalSets: $totalSets, ')
          ..write('perceivedEffort: $perceivedEffort, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    routineId,
    name,
    startedAt,
    endedAt,
    notes,
    totalVolumeKg,
    totalSets,
    perceivedEffort,
    durationSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutRow &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.name == this.name &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.notes == this.notes &&
          other.totalVolumeKg == this.totalVolumeKg &&
          other.totalSets == this.totalSets &&
          other.perceivedEffort == this.perceivedEffort &&
          other.durationSeconds == this.durationSeconds);
}

class WorkoutsTableCompanion extends UpdateCompanion<WorkoutRow> {
  final Value<String> id;
  final Value<String?> routineId;
  final Value<String> name;
  final Value<int> startedAt;
  final Value<int?> endedAt;
  final Value<String?> notes;
  final Value<double> totalVolumeKg;
  final Value<int> totalSets;
  final Value<String?> perceivedEffort;
  final Value<int> durationSeconds;
  final Value<int> rowid;
  const WorkoutsTableCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.name = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.totalVolumeKg = const Value.absent(),
    this.totalSets = const Value.absent(),
    this.perceivedEffort = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutsTableCompanion.insert({
    required String id,
    this.routineId = const Value.absent(),
    required String name,
    required int startedAt,
    this.endedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.totalVolumeKg = const Value.absent(),
    this.totalSets = const Value.absent(),
    this.perceivedEffort = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       startedAt = Value(startedAt);
  static Insertable<WorkoutRow> custom({
    Expression<String>? id,
    Expression<String>? routineId,
    Expression<String>? name,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<String>? notes,
    Expression<double>? totalVolumeKg,
    Expression<int>? totalSets,
    Expression<String>? perceivedEffort,
    Expression<int>? durationSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (name != null) 'name': name,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (notes != null) 'notes': notes,
      if (totalVolumeKg != null) 'total_volume_kg': totalVolumeKg,
      if (totalSets != null) 'total_sets': totalSets,
      if (perceivedEffort != null) 'perceived_effort': perceivedEffort,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? routineId,
    Value<String>? name,
    Value<int>? startedAt,
    Value<int?>? endedAt,
    Value<String?>? notes,
    Value<double>? totalVolumeKg,
    Value<int>? totalSets,
    Value<String?>? perceivedEffort,
    Value<int>? durationSeconds,
    Value<int>? rowid,
  }) {
    return WorkoutsTableCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      notes: notes ?? this.notes,
      totalVolumeKg: totalVolumeKg ?? this.totalVolumeKg,
      totalSets: totalSets ?? this.totalSets,
      perceivedEffort: perceivedEffort ?? this.perceivedEffort,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (totalVolumeKg.present) {
      map['total_volume_kg'] = Variable<double>(totalVolumeKg.value);
    }
    if (totalSets.present) {
      map['total_sets'] = Variable<int>(totalSets.value);
    }
    if (perceivedEffort.present) {
      map['perceived_effort'] = Variable<String>(perceivedEffort.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutsTableCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('notes: $notes, ')
          ..write('totalVolumeKg: $totalVolumeKg, ')
          ..write('totalSets: $totalSets, ')
          ..write('perceivedEffort: $perceivedEffort, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutExercisesTableTable extends WorkoutExercisesTable
    with TableInfo<$WorkoutExercisesTableTable, WorkoutExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutExercisesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workoutIdMeta = const VerificationMeta(
    'workoutId',
  );
  @override
  late final GeneratedColumn<String> workoutId = GeneratedColumn<String>(
    'workout_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workouts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercises (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(90),
  );
  static const VerificationMeta _supersetGroupMeta = const VerificationMeta(
    'supersetGroup',
  );
  @override
  late final GeneratedColumn<int> supersetGroup = GeneratedColumn<int>(
    'superset_group',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPrAttemptMeta = const VerificationMeta(
    'isPrAttempt',
  );
  @override
  late final GeneratedColumn<bool> isPrAttempt = GeneratedColumn<bool>(
    'is_pr_attempt',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pr_attempt" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _prTargetWeightKgMeta = const VerificationMeta(
    'prTargetWeightKg',
  );
  @override
  late final GeneratedColumn<double> prTargetWeightKg = GeneratedColumn<double>(
    'pr_target_weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prResultMeta = const VerificationMeta(
    'prResult',
  );
  @override
  late final GeneratedColumn<String> prResult = GeneratedColumn<String>(
    'pr_result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workoutId,
    exerciseId,
    sortOrder,
    restSeconds,
    supersetGroup,
    notes,
    isPrAttempt,
    prTargetWeightKg,
    prResult,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutExerciseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workout_id')) {
      context.handle(
        _workoutIdMeta,
        workoutId.isAcceptableOrUnknown(data['workout_id']!, _workoutIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workoutIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    if (data.containsKey('superset_group')) {
      context.handle(
        _supersetGroupMeta,
        supersetGroup.isAcceptableOrUnknown(
          data['superset_group']!,
          _supersetGroupMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_pr_attempt')) {
      context.handle(
        _isPrAttemptMeta,
        isPrAttempt.isAcceptableOrUnknown(
          data['is_pr_attempt']!,
          _isPrAttemptMeta,
        ),
      );
    }
    if (data.containsKey('pr_target_weight_kg')) {
      context.handle(
        _prTargetWeightKgMeta,
        prTargetWeightKg.isAcceptableOrUnknown(
          data['pr_target_weight_kg']!,
          _prTargetWeightKgMeta,
        ),
      );
    }
    if (data.containsKey('pr_result')) {
      context.handle(
        _prResultMeta,
        prResult.isAcceptableOrUnknown(data['pr_result']!, _prResultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutExerciseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workoutId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      )!,
      supersetGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}superset_group'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      isPrAttempt: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pr_attempt'],
      )!,
      prTargetWeightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pr_target_weight_kg'],
      ),
      prResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pr_result'],
      ),
    );
  }

  @override
  $WorkoutExercisesTableTable createAlias(String alias) {
    return $WorkoutExercisesTableTable(attachedDatabase, alias);
  }
}

class WorkoutExerciseRow extends DataClass
    implements Insertable<WorkoutExerciseRow> {
  final String id;
  final String workoutId;
  final String exerciseId;
  final int sortOrder;
  final int restSeconds;
  final int? supersetGroup;
  final String? notes;

  /// Marks this exercise as a one-rep-max attempt with its own warm-up ladder.
  final bool isPrAttempt;

  /// The weight the attempt was aiming for.
  final double? prTargetWeightKg;

  /// `success` | `failed` | `abandoned`, or null while it is still running.
  final String? prResult;
  const WorkoutExerciseRow({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.sortOrder,
    required this.restSeconds,
    this.supersetGroup,
    this.notes,
    required this.isPrAttempt,
    this.prTargetWeightKg,
    this.prResult,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workout_id'] = Variable<String>(workoutId);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['rest_seconds'] = Variable<int>(restSeconds);
    if (!nullToAbsent || supersetGroup != null) {
      map['superset_group'] = Variable<int>(supersetGroup);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_pr_attempt'] = Variable<bool>(isPrAttempt);
    if (!nullToAbsent || prTargetWeightKg != null) {
      map['pr_target_weight_kg'] = Variable<double>(prTargetWeightKg);
    }
    if (!nullToAbsent || prResult != null) {
      map['pr_result'] = Variable<String>(prResult);
    }
    return map;
  }

  WorkoutExercisesTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutExercisesTableCompanion(
      id: Value(id),
      workoutId: Value(workoutId),
      exerciseId: Value(exerciseId),
      sortOrder: Value(sortOrder),
      restSeconds: Value(restSeconds),
      supersetGroup: supersetGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(supersetGroup),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      isPrAttempt: Value(isPrAttempt),
      prTargetWeightKg: prTargetWeightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(prTargetWeightKg),
      prResult: prResult == null && nullToAbsent
          ? const Value.absent()
          : Value(prResult),
    );
  }

  factory WorkoutExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutExerciseRow(
      id: serializer.fromJson<String>(json['id']),
      workoutId: serializer.fromJson<String>(json['workoutId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      restSeconds: serializer.fromJson<int>(json['restSeconds']),
      supersetGroup: serializer.fromJson<int?>(json['supersetGroup']),
      notes: serializer.fromJson<String?>(json['notes']),
      isPrAttempt: serializer.fromJson<bool>(json['isPrAttempt']),
      prTargetWeightKg: serializer.fromJson<double?>(json['prTargetWeightKg']),
      prResult: serializer.fromJson<String?>(json['prResult']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workoutId': serializer.toJson<String>(workoutId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'restSeconds': serializer.toJson<int>(restSeconds),
      'supersetGroup': serializer.toJson<int?>(supersetGroup),
      'notes': serializer.toJson<String?>(notes),
      'isPrAttempt': serializer.toJson<bool>(isPrAttempt),
      'prTargetWeightKg': serializer.toJson<double?>(prTargetWeightKg),
      'prResult': serializer.toJson<String?>(prResult),
    };
  }

  WorkoutExerciseRow copyWith({
    String? id,
    String? workoutId,
    String? exerciseId,
    int? sortOrder,
    int? restSeconds,
    Value<int?> supersetGroup = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    bool? isPrAttempt,
    Value<double?> prTargetWeightKg = const Value.absent(),
    Value<String?> prResult = const Value.absent(),
  }) => WorkoutExerciseRow(
    id: id ?? this.id,
    workoutId: workoutId ?? this.workoutId,
    exerciseId: exerciseId ?? this.exerciseId,
    sortOrder: sortOrder ?? this.sortOrder,
    restSeconds: restSeconds ?? this.restSeconds,
    supersetGroup: supersetGroup.present
        ? supersetGroup.value
        : this.supersetGroup,
    notes: notes.present ? notes.value : this.notes,
    isPrAttempt: isPrAttempt ?? this.isPrAttempt,
    prTargetWeightKg: prTargetWeightKg.present
        ? prTargetWeightKg.value
        : this.prTargetWeightKg,
    prResult: prResult.present ? prResult.value : this.prResult,
  );
  WorkoutExerciseRow copyWithCompanion(WorkoutExercisesTableCompanion data) {
    return WorkoutExerciseRow(
      id: data.id.present ? data.id.value : this.id,
      workoutId: data.workoutId.present ? data.workoutId.value : this.workoutId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
      supersetGroup: data.supersetGroup.present
          ? data.supersetGroup.value
          : this.supersetGroup,
      notes: data.notes.present ? data.notes.value : this.notes,
      isPrAttempt: data.isPrAttempt.present
          ? data.isPrAttempt.value
          : this.isPrAttempt,
      prTargetWeightKg: data.prTargetWeightKg.present
          ? data.prTargetWeightKg.value
          : this.prTargetWeightKg,
      prResult: data.prResult.present ? data.prResult.value : this.prResult,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutExerciseRow(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('supersetGroup: $supersetGroup, ')
          ..write('notes: $notes, ')
          ..write('isPrAttempt: $isPrAttempt, ')
          ..write('prTargetWeightKg: $prTargetWeightKg, ')
          ..write('prResult: $prResult')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workoutId,
    exerciseId,
    sortOrder,
    restSeconds,
    supersetGroup,
    notes,
    isPrAttempt,
    prTargetWeightKg,
    prResult,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutExerciseRow &&
          other.id == this.id &&
          other.workoutId == this.workoutId &&
          other.exerciseId == this.exerciseId &&
          other.sortOrder == this.sortOrder &&
          other.restSeconds == this.restSeconds &&
          other.supersetGroup == this.supersetGroup &&
          other.notes == this.notes &&
          other.isPrAttempt == this.isPrAttempt &&
          other.prTargetWeightKg == this.prTargetWeightKg &&
          other.prResult == this.prResult);
}

class WorkoutExercisesTableCompanion
    extends UpdateCompanion<WorkoutExerciseRow> {
  final Value<String> id;
  final Value<String> workoutId;
  final Value<String> exerciseId;
  final Value<int> sortOrder;
  final Value<int> restSeconds;
  final Value<int?> supersetGroup;
  final Value<String?> notes;
  final Value<bool> isPrAttempt;
  final Value<double?> prTargetWeightKg;
  final Value<String?> prResult;
  final Value<int> rowid;
  const WorkoutExercisesTableCompanion({
    this.id = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.supersetGroup = const Value.absent(),
    this.notes = const Value.absent(),
    this.isPrAttempt = const Value.absent(),
    this.prTargetWeightKg = const Value.absent(),
    this.prResult = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutExercisesTableCompanion.insert({
    required String id,
    required String workoutId,
    required String exerciseId,
    required int sortOrder,
    this.restSeconds = const Value.absent(),
    this.supersetGroup = const Value.absent(),
    this.notes = const Value.absent(),
    this.isPrAttempt = const Value.absent(),
    this.prTargetWeightKg = const Value.absent(),
    this.prResult = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workoutId = Value(workoutId),
       exerciseId = Value(exerciseId),
       sortOrder = Value(sortOrder);
  static Insertable<WorkoutExerciseRow> custom({
    Expression<String>? id,
    Expression<String>? workoutId,
    Expression<String>? exerciseId,
    Expression<int>? sortOrder,
    Expression<int>? restSeconds,
    Expression<int>? supersetGroup,
    Expression<String>? notes,
    Expression<bool>? isPrAttempt,
    Expression<double>? prTargetWeightKg,
    Expression<String>? prResult,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workoutId != null) 'workout_id': workoutId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (supersetGroup != null) 'superset_group': supersetGroup,
      if (notes != null) 'notes': notes,
      if (isPrAttempt != null) 'is_pr_attempt': isPrAttempt,
      if (prTargetWeightKg != null) 'pr_target_weight_kg': prTargetWeightKg,
      if (prResult != null) 'pr_result': prResult,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutExercisesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? workoutId,
    Value<String>? exerciseId,
    Value<int>? sortOrder,
    Value<int>? restSeconds,
    Value<int?>? supersetGroup,
    Value<String?>? notes,
    Value<bool>? isPrAttempt,
    Value<double?>? prTargetWeightKg,
    Value<String?>? prResult,
    Value<int>? rowid,
  }) {
    return WorkoutExercisesTableCompanion(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      sortOrder: sortOrder ?? this.sortOrder,
      restSeconds: restSeconds ?? this.restSeconds,
      supersetGroup: supersetGroup ?? this.supersetGroup,
      notes: notes ?? this.notes,
      isPrAttempt: isPrAttempt ?? this.isPrAttempt,
      prTargetWeightKg: prTargetWeightKg ?? this.prTargetWeightKg,
      prResult: prResult ?? this.prResult,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workoutId.present) {
      map['workout_id'] = Variable<String>(workoutId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    if (supersetGroup.present) {
      map['superset_group'] = Variable<int>(supersetGroup.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isPrAttempt.present) {
      map['is_pr_attempt'] = Variable<bool>(isPrAttempt.value);
    }
    if (prTargetWeightKg.present) {
      map['pr_target_weight_kg'] = Variable<double>(prTargetWeightKg.value);
    }
    if (prResult.present) {
      map['pr_result'] = Variable<String>(prResult.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutExercisesTableCompanion(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('supersetGroup: $supersetGroup, ')
          ..write('notes: $notes, ')
          ..write('isPrAttempt: $isPrAttempt, ')
          ..write('prTargetWeightKg: $prTargetWeightKg, ')
          ..write('prResult: $prResult, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetsTableTable extends WorkoutSetsTable
    with TableInfo<$WorkoutSetsTableTable, WorkoutSetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workoutExerciseIdMeta = const VerificationMeta(
    'workoutExerciseId',
  );
  @override
  late final GeneratedColumn<String> workoutExerciseId =
      GeneratedColumn<String>(
        'workout_exercise_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES workout_exercises (id) ON DELETE CASCADE',
        ),
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setTypeMeta = const VerificationMeta(
    'setType',
  );
  @override
  late final GeneratedColumn<String> setType = GeneratedColumn<String>(
    'set_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<double> distanceM = GeneratedColumn<double>(
    'distance_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rpeMeta = const VerificationMeta('rpe');
  @override
  late final GeneratedColumn<double> rpe = GeneratedColumn<double>(
    'rpe',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workoutExerciseId,
    sortOrder,
    setType,
    weightKg,
    reps,
    durationSeconds,
    distanceM,
    rpe,
    isCompleted,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workout_exercise_id')) {
      context.handle(
        _workoutExerciseIdMeta,
        workoutExerciseId.isAcceptableOrUnknown(
          data['workout_exercise_id']!,
          _workoutExerciseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workoutExerciseIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('set_type')) {
      context.handle(
        _setTypeMeta,
        setType.isAcceptableOrUnknown(data['set_type']!, _setTypeMeta),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    }
    if (data.containsKey('rpe')) {
      context.handle(
        _rpeMeta,
        rpe.isAcceptableOrUnknown(data['rpe']!, _rpeMeta),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workoutExerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout_exercise_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      setType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_type'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      ),
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_m'],
      ),
      rpe: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rpe'],
      ),
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $WorkoutSetsTableTable createAlias(String alias) {
    return $WorkoutSetsTableTable(attachedDatabase, alias);
  }
}

class WorkoutSetRow extends DataClass implements Insertable<WorkoutSetRow> {
  final String id;
  final String workoutExerciseId;
  final int sortOrder;

  /// One of [SetType]: `warmup` | `normal` | `drop` | `failure`.
  final String setType;
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final double? distanceM;
  final double? rpe;
  final bool isCompleted;
  final int? completedAt;
  const WorkoutSetRow({
    required this.id,
    required this.workoutExerciseId,
    required this.sortOrder,
    required this.setType,
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.distanceM,
    this.rpe,
    required this.isCompleted,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workout_exercise_id'] = Variable<String>(workoutExerciseId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['set_type'] = Variable<String>(setType);
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || distanceM != null) {
      map['distance_m'] = Variable<double>(distanceM);
    }
    if (!nullToAbsent || rpe != null) {
      map['rpe'] = Variable<double>(rpe);
    }
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    return map;
  }

  WorkoutSetsTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetsTableCompanion(
      id: Value(id),
      workoutExerciseId: Value(workoutExerciseId),
      sortOrder: Value(sortOrder),
      setType: Value(setType),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      distanceM: distanceM == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceM),
      rpe: rpe == null && nullToAbsent ? const Value.absent() : Value(rpe),
      isCompleted: Value(isCompleted),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory WorkoutSetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSetRow(
      id: serializer.fromJson<String>(json['id']),
      workoutExerciseId: serializer.fromJson<String>(json['workoutExerciseId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      setType: serializer.fromJson<String>(json['setType']),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      reps: serializer.fromJson<int?>(json['reps']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      distanceM: serializer.fromJson<double?>(json['distanceM']),
      rpe: serializer.fromJson<double?>(json['rpe']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workoutExerciseId': serializer.toJson<String>(workoutExerciseId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'setType': serializer.toJson<String>(setType),
      'weightKg': serializer.toJson<double?>(weightKg),
      'reps': serializer.toJson<int?>(reps),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'distanceM': serializer.toJson<double?>(distanceM),
      'rpe': serializer.toJson<double?>(rpe),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'completedAt': serializer.toJson<int?>(completedAt),
    };
  }

  WorkoutSetRow copyWith({
    String? id,
    String? workoutExerciseId,
    int? sortOrder,
    String? setType,
    Value<double?> weightKg = const Value.absent(),
    Value<int?> reps = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<double?> distanceM = const Value.absent(),
    Value<double?> rpe = const Value.absent(),
    bool? isCompleted,
    Value<int?> completedAt = const Value.absent(),
  }) => WorkoutSetRow(
    id: id ?? this.id,
    workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
    sortOrder: sortOrder ?? this.sortOrder,
    setType: setType ?? this.setType,
    weightKg: weightKg.present ? weightKg.value : this.weightKg,
    reps: reps.present ? reps.value : this.reps,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    distanceM: distanceM.present ? distanceM.value : this.distanceM,
    rpe: rpe.present ? rpe.value : this.rpe,
    isCompleted: isCompleted ?? this.isCompleted,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  WorkoutSetRow copyWithCompanion(WorkoutSetsTableCompanion data) {
    return WorkoutSetRow(
      id: data.id.present ? data.id.value : this.id,
      workoutExerciseId: data.workoutExerciseId.present
          ? data.workoutExerciseId.value
          : this.workoutExerciseId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      setType: data.setType.present ? data.setType.value : this.setType,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      reps: data.reps.present ? data.reps.value : this.reps,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      rpe: data.rpe.present ? data.rpe.value : this.rpe,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetRow(')
          ..write('id: $id, ')
          ..write('workoutExerciseId: $workoutExerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('setType: $setType, ')
          ..write('weightKg: $weightKg, ')
          ..write('reps: $reps, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('distanceM: $distanceM, ')
          ..write('rpe: $rpe, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workoutExerciseId,
    sortOrder,
    setType,
    weightKg,
    reps,
    durationSeconds,
    distanceM,
    rpe,
    isCompleted,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSetRow &&
          other.id == this.id &&
          other.workoutExerciseId == this.workoutExerciseId &&
          other.sortOrder == this.sortOrder &&
          other.setType == this.setType &&
          other.weightKg == this.weightKg &&
          other.reps == this.reps &&
          other.durationSeconds == this.durationSeconds &&
          other.distanceM == this.distanceM &&
          other.rpe == this.rpe &&
          other.isCompleted == this.isCompleted &&
          other.completedAt == this.completedAt);
}

class WorkoutSetsTableCompanion extends UpdateCompanion<WorkoutSetRow> {
  final Value<String> id;
  final Value<String> workoutExerciseId;
  final Value<int> sortOrder;
  final Value<String> setType;
  final Value<double?> weightKg;
  final Value<int?> reps;
  final Value<int?> durationSeconds;
  final Value<double?> distanceM;
  final Value<double?> rpe;
  final Value<bool> isCompleted;
  final Value<int?> completedAt;
  final Value<int> rowid;
  const WorkoutSetsTableCompanion({
    this.id = const Value.absent(),
    this.workoutExerciseId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.setType = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.reps = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.rpe = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutSetsTableCompanion.insert({
    required String id,
    required String workoutExerciseId,
    required int sortOrder,
    this.setType = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.reps = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.rpe = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workoutExerciseId = Value(workoutExerciseId),
       sortOrder = Value(sortOrder);
  static Insertable<WorkoutSetRow> custom({
    Expression<String>? id,
    Expression<String>? workoutExerciseId,
    Expression<int>? sortOrder,
    Expression<String>? setType,
    Expression<double>? weightKg,
    Expression<int>? reps,
    Expression<int>? durationSeconds,
    Expression<double>? distanceM,
    Expression<double>? rpe,
    Expression<bool>? isCompleted,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workoutExerciseId != null) 'workout_exercise_id': workoutExerciseId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (setType != null) 'set_type': setType,
      if (weightKg != null) 'weight_kg': weightKg,
      if (reps != null) 'reps': reps,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (distanceM != null) 'distance_m': distanceM,
      if (rpe != null) 'rpe': rpe,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutSetsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? workoutExerciseId,
    Value<int>? sortOrder,
    Value<String>? setType,
    Value<double?>? weightKg,
    Value<int?>? reps,
    Value<int?>? durationSeconds,
    Value<double?>? distanceM,
    Value<double?>? rpe,
    Value<bool>? isCompleted,
    Value<int?>? completedAt,
    Value<int>? rowid,
  }) {
    return WorkoutSetsTableCompanion(
      id: id ?? this.id,
      workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
      sortOrder: sortOrder ?? this.sortOrder,
      setType: setType ?? this.setType,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceM: distanceM ?? this.distanceM,
      rpe: rpe ?? this.rpe,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workoutExerciseId.present) {
      map['workout_exercise_id'] = Variable<String>(workoutExerciseId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (setType.present) {
      map['set_type'] = Variable<String>(setType.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<double>(distanceM.value);
    }
    if (rpe.present) {
      map['rpe'] = Variable<double>(rpe.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetsTableCompanion(')
          ..write('id: $id, ')
          ..write('workoutExerciseId: $workoutExerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('setType: $setType, ')
          ..write('weightKg: $weightKg, ')
          ..write('reps: $reps, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('distanceM: $distanceM, ')
          ..write('rpe: $rpe, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonalRecordsTableTable extends PersonalRecordsTable
    with TableInfo<$PersonalRecordsTableTable, PersonalRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonalRecordsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercises (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _recordTypeMeta = const VerificationMeta(
    'recordType',
  );
  @override
  late final GeneratedColumn<String> recordType = GeneratedColumn<String>(
    'record_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workoutSetIdMeta = const VerificationMeta(
    'workoutSetId',
  );
  @override
  late final GeneratedColumn<String> workoutSetId = GeneratedColumn<String>(
    'workout_set_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_sets (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _achievedAtMeta = const VerificationMeta(
    'achievedAt',
  );
  @override
  late final GeneratedColumn<int> achievedAt = GeneratedColumn<int>(
    'achieved_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    exerciseId,
    recordType,
    value,
    workoutSetId,
    achievedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'personal_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonalRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('record_type')) {
      context.handle(
        _recordTypeMeta,
        recordType.isAcceptableOrUnknown(data['record_type']!, _recordTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_recordTypeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('workout_set_id')) {
      context.handle(
        _workoutSetIdMeta,
        workoutSetId.isAcceptableOrUnknown(
          data['workout_set_id']!,
          _workoutSetIdMeta,
        ),
      );
    }
    if (data.containsKey('achieved_at')) {
      context.handle(
        _achievedAtMeta,
        achievedAt.isAcceptableOrUnknown(data['achieved_at']!, _achievedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_achievedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonalRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonalRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      recordType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_type'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      workoutSetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout_set_id'],
      ),
      achievedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}achieved_at'],
      )!,
    );
  }

  @override
  $PersonalRecordsTableTable createAlias(String alias) {
    return $PersonalRecordsTableTable(attachedDatabase, alias);
  }
}

class PersonalRecordRow extends DataClass
    implements Insertable<PersonalRecordRow> {
  final String id;
  final String exerciseId;

  /// One of [PrType]: `max_weight` | `est_1rm` | `max_set_volume` | `max_reps`.
  final String recordType;
  final double value;

  /// The set that produced this record.
  ///
  /// `ON DELETE SET NULL`: deleting a workout takes its sets with it, and a
  /// record that outlives its set must lose the reference rather than keep a
  /// dangling id. Without this constraint the row simply pointed at nothing.
  final String? workoutSetId;
  final int achievedAt;
  const PersonalRecordRow({
    required this.id,
    required this.exerciseId,
    required this.recordType,
    required this.value,
    this.workoutSetId,
    required this.achievedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['record_type'] = Variable<String>(recordType);
    map['value'] = Variable<double>(value);
    if (!nullToAbsent || workoutSetId != null) {
      map['workout_set_id'] = Variable<String>(workoutSetId);
    }
    map['achieved_at'] = Variable<int>(achievedAt);
    return map;
  }

  PersonalRecordsTableCompanion toCompanion(bool nullToAbsent) {
    return PersonalRecordsTableCompanion(
      id: Value(id),
      exerciseId: Value(exerciseId),
      recordType: Value(recordType),
      value: Value(value),
      workoutSetId: workoutSetId == null && nullToAbsent
          ? const Value.absent()
          : Value(workoutSetId),
      achievedAt: Value(achievedAt),
    );
  }

  factory PersonalRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonalRecordRow(
      id: serializer.fromJson<String>(json['id']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      recordType: serializer.fromJson<String>(json['recordType']),
      value: serializer.fromJson<double>(json['value']),
      workoutSetId: serializer.fromJson<String?>(json['workoutSetId']),
      achievedAt: serializer.fromJson<int>(json['achievedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'recordType': serializer.toJson<String>(recordType),
      'value': serializer.toJson<double>(value),
      'workoutSetId': serializer.toJson<String?>(workoutSetId),
      'achievedAt': serializer.toJson<int>(achievedAt),
    };
  }

  PersonalRecordRow copyWith({
    String? id,
    String? exerciseId,
    String? recordType,
    double? value,
    Value<String?> workoutSetId = const Value.absent(),
    int? achievedAt,
  }) => PersonalRecordRow(
    id: id ?? this.id,
    exerciseId: exerciseId ?? this.exerciseId,
    recordType: recordType ?? this.recordType,
    value: value ?? this.value,
    workoutSetId: workoutSetId.present ? workoutSetId.value : this.workoutSetId,
    achievedAt: achievedAt ?? this.achievedAt,
  );
  PersonalRecordRow copyWithCompanion(PersonalRecordsTableCompanion data) {
    return PersonalRecordRow(
      id: data.id.present ? data.id.value : this.id,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      recordType: data.recordType.present
          ? data.recordType.value
          : this.recordType,
      value: data.value.present ? data.value.value : this.value,
      workoutSetId: data.workoutSetId.present
          ? data.workoutSetId.value
          : this.workoutSetId,
      achievedAt: data.achievedAt.present
          ? data.achievedAt.value
          : this.achievedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonalRecordRow(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('recordType: $recordType, ')
          ..write('value: $value, ')
          ..write('workoutSetId: $workoutSetId, ')
          ..write('achievedAt: $achievedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, exerciseId, recordType, value, workoutSetId, achievedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonalRecordRow &&
          other.id == this.id &&
          other.exerciseId == this.exerciseId &&
          other.recordType == this.recordType &&
          other.value == this.value &&
          other.workoutSetId == this.workoutSetId &&
          other.achievedAt == this.achievedAt);
}

class PersonalRecordsTableCompanion extends UpdateCompanion<PersonalRecordRow> {
  final Value<String> id;
  final Value<String> exerciseId;
  final Value<String> recordType;
  final Value<double> value;
  final Value<String?> workoutSetId;
  final Value<int> achievedAt;
  final Value<int> rowid;
  const PersonalRecordsTableCompanion({
    this.id = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.recordType = const Value.absent(),
    this.value = const Value.absent(),
    this.workoutSetId = const Value.absent(),
    this.achievedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonalRecordsTableCompanion.insert({
    required String id,
    required String exerciseId,
    required String recordType,
    required double value,
    this.workoutSetId = const Value.absent(),
    required int achievedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       exerciseId = Value(exerciseId),
       recordType = Value(recordType),
       value = Value(value),
       achievedAt = Value(achievedAt);
  static Insertable<PersonalRecordRow> custom({
    Expression<String>? id,
    Expression<String>? exerciseId,
    Expression<String>? recordType,
    Expression<double>? value,
    Expression<String>? workoutSetId,
    Expression<int>? achievedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (recordType != null) 'record_type': recordType,
      if (value != null) 'value': value,
      if (workoutSetId != null) 'workout_set_id': workoutSetId,
      if (achievedAt != null) 'achieved_at': achievedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonalRecordsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? exerciseId,
    Value<String>? recordType,
    Value<double>? value,
    Value<String?>? workoutSetId,
    Value<int>? achievedAt,
    Value<int>? rowid,
  }) {
    return PersonalRecordsTableCompanion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      recordType: recordType ?? this.recordType,
      value: value ?? this.value,
      workoutSetId: workoutSetId ?? this.workoutSetId,
      achievedAt: achievedAt ?? this.achievedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (recordType.present) {
      map['record_type'] = Variable<String>(recordType.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (workoutSetId.present) {
      map['workout_set_id'] = Variable<String>(workoutSetId.value);
    }
    if (achievedAt.present) {
      map['achieved_at'] = Variable<int>(achievedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonalRecordsTableCompanion(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('recordType: $recordType, ')
          ..write('value: $value, ')
          ..write('workoutSetId: $workoutSetId, ')
          ..write('achievedAt: $achievedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BodyMeasurementsTableTable extends BodyMeasurementsTable
    with TableInfo<$BodyMeasurementsTableTable, BodyMeasurementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BodyMeasurementsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _measuredAtMeta = const VerificationMeta(
    'measuredAt',
  );
  @override
  late final GeneratedColumn<int> measuredAt = GeneratedColumn<int>(
    'measured_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, measuredAt, type, value, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'body_measurements';
  @override
  VerificationContext validateIntegrity(
    Insertable<BodyMeasurementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('measured_at')) {
      context.handle(
        _measuredAtMeta,
        measuredAt.isAcceptableOrUnknown(data['measured_at']!, _measuredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_measuredAtMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BodyMeasurementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BodyMeasurementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      measuredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}measured_at'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $BodyMeasurementsTableTable createAlias(String alias) {
    return $BodyMeasurementsTableTable(attachedDatabase, alias);
  }
}

class BodyMeasurementRow extends DataClass
    implements Insertable<BodyMeasurementRow> {
  final String id;
  final int measuredAt;

  /// One of [MeasurementType].
  final String type;

  /// Always metric: kilograms for weight, percent for body fat, centimetres
  /// for every circumference.
  final double value;
  final String? note;
  const BodyMeasurementRow({
    required this.id,
    required this.measuredAt,
    required this.type,
    required this.value,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['measured_at'] = Variable<int>(measuredAt);
    map['type'] = Variable<String>(type);
    map['value'] = Variable<double>(value);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  BodyMeasurementsTableCompanion toCompanion(bool nullToAbsent) {
    return BodyMeasurementsTableCompanion(
      id: Value(id),
      measuredAt: Value(measuredAt),
      type: Value(type),
      value: Value(value),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory BodyMeasurementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BodyMeasurementRow(
      id: serializer.fromJson<String>(json['id']),
      measuredAt: serializer.fromJson<int>(json['measuredAt']),
      type: serializer.fromJson<String>(json['type']),
      value: serializer.fromJson<double>(json['value']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'measuredAt': serializer.toJson<int>(measuredAt),
      'type': serializer.toJson<String>(type),
      'value': serializer.toJson<double>(value),
      'note': serializer.toJson<String?>(note),
    };
  }

  BodyMeasurementRow copyWith({
    String? id,
    int? measuredAt,
    String? type,
    double? value,
    Value<String?> note = const Value.absent(),
  }) => BodyMeasurementRow(
    id: id ?? this.id,
    measuredAt: measuredAt ?? this.measuredAt,
    type: type ?? this.type,
    value: value ?? this.value,
    note: note.present ? note.value : this.note,
  );
  BodyMeasurementRow copyWithCompanion(BodyMeasurementsTableCompanion data) {
    return BodyMeasurementRow(
      id: data.id.present ? data.id.value : this.id,
      measuredAt: data.measuredAt.present
          ? data.measuredAt.value
          : this.measuredAt,
      type: data.type.present ? data.type.value : this.type,
      value: data.value.present ? data.value.value : this.value,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BodyMeasurementRow(')
          ..write('id: $id, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('type: $type, ')
          ..write('value: $value, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, measuredAt, type, value, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BodyMeasurementRow &&
          other.id == this.id &&
          other.measuredAt == this.measuredAt &&
          other.type == this.type &&
          other.value == this.value &&
          other.note == this.note);
}

class BodyMeasurementsTableCompanion
    extends UpdateCompanion<BodyMeasurementRow> {
  final Value<String> id;
  final Value<int> measuredAt;
  final Value<String> type;
  final Value<double> value;
  final Value<String?> note;
  final Value<int> rowid;
  const BodyMeasurementsTableCompanion({
    this.id = const Value.absent(),
    this.measuredAt = const Value.absent(),
    this.type = const Value.absent(),
    this.value = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BodyMeasurementsTableCompanion.insert({
    required String id,
    required int measuredAt,
    required String type,
    required double value,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       measuredAt = Value(measuredAt),
       type = Value(type),
       value = Value(value);
  static Insertable<BodyMeasurementRow> custom({
    Expression<String>? id,
    Expression<int>? measuredAt,
    Expression<String>? type,
    Expression<double>? value,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (measuredAt != null) 'measured_at': measuredAt,
      if (type != null) 'type': type,
      if (value != null) 'value': value,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BodyMeasurementsTableCompanion copyWith({
    Value<String>? id,
    Value<int>? measuredAt,
    Value<String>? type,
    Value<double>? value,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return BodyMeasurementsTableCompanion(
      id: id ?? this.id,
      measuredAt: measuredAt ?? this.measuredAt,
      type: type ?? this.type,
      value: value ?? this.value,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (measuredAt.present) {
      map['measured_at'] = Variable<int>(measuredAt.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BodyMeasurementsTableCompanion(')
          ..write('id: $id, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('type: $type, ')
          ..write('value: $value, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressPhotosTableTable extends ProgressPhotosTable
    with TableInfo<$ProgressPhotosTableTable, ProgressPhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressPhotosTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<int> takenAt = GeneratedColumn<int>(
    'taken_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _poseMeta = const VerificationMeta('pose');
  @override
  late final GeneratedColumn<String> pose = GeneratedColumn<String>(
    'pose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, takenAt, fileName, pose, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressPhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_takenAtMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('pose')) {
      context.handle(
        _poseMeta,
        pose.isAcceptableOrUnknown(data['pose']!, _poseMeta),
      );
    } else if (isInserting) {
      context.missing(_poseMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProgressPhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressPhotoRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}taken_at'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      pose: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pose'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $ProgressPhotosTableTable createAlias(String alias) {
    return $ProgressPhotosTableTable(attachedDatabase, alias);
  }
}

class ProgressPhotoRow extends DataClass
    implements Insertable<ProgressPhotoRow> {
  final String id;
  final int takenAt;

  /// File name inside `<app documents>/photos/`. The bytes never live in the
  /// database.
  final String fileName;

  /// `front` | `side` | `back`.
  final String pose;
  final String? note;
  const ProgressPhotoRow({
    required this.id,
    required this.takenAt,
    required this.fileName,
    required this.pose,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['taken_at'] = Variable<int>(takenAt);
    map['file_name'] = Variable<String>(fileName);
    map['pose'] = Variable<String>(pose);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  ProgressPhotosTableCompanion toCompanion(bool nullToAbsent) {
    return ProgressPhotosTableCompanion(
      id: Value(id),
      takenAt: Value(takenAt),
      fileName: Value(fileName),
      pose: Value(pose),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory ProgressPhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressPhotoRow(
      id: serializer.fromJson<String>(json['id']),
      takenAt: serializer.fromJson<int>(json['takenAt']),
      fileName: serializer.fromJson<String>(json['fileName']),
      pose: serializer.fromJson<String>(json['pose']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'takenAt': serializer.toJson<int>(takenAt),
      'fileName': serializer.toJson<String>(fileName),
      'pose': serializer.toJson<String>(pose),
      'note': serializer.toJson<String?>(note),
    };
  }

  ProgressPhotoRow copyWith({
    String? id,
    int? takenAt,
    String? fileName,
    String? pose,
    Value<String?> note = const Value.absent(),
  }) => ProgressPhotoRow(
    id: id ?? this.id,
    takenAt: takenAt ?? this.takenAt,
    fileName: fileName ?? this.fileName,
    pose: pose ?? this.pose,
    note: note.present ? note.value : this.note,
  );
  ProgressPhotoRow copyWithCompanion(ProgressPhotosTableCompanion data) {
    return ProgressPhotoRow(
      id: data.id.present ? data.id.value : this.id,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      pose: data.pose.present ? data.pose.value : this.pose,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressPhotoRow(')
          ..write('id: $id, ')
          ..write('takenAt: $takenAt, ')
          ..write('fileName: $fileName, ')
          ..write('pose: $pose, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, takenAt, fileName, pose, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressPhotoRow &&
          other.id == this.id &&
          other.takenAt == this.takenAt &&
          other.fileName == this.fileName &&
          other.pose == this.pose &&
          other.note == this.note);
}

class ProgressPhotosTableCompanion extends UpdateCompanion<ProgressPhotoRow> {
  final Value<String> id;
  final Value<int> takenAt;
  final Value<String> fileName;
  final Value<String> pose;
  final Value<String?> note;
  final Value<int> rowid;
  const ProgressPhotosTableCompanion({
    this.id = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.fileName = const Value.absent(),
    this.pose = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressPhotosTableCompanion.insert({
    required String id,
    required int takenAt,
    required String fileName,
    required String pose,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       takenAt = Value(takenAt),
       fileName = Value(fileName),
       pose = Value(pose);
  static Insertable<ProgressPhotoRow> custom({
    Expression<String>? id,
    Expression<int>? takenAt,
    Expression<String>? fileName,
    Expression<String>? pose,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (takenAt != null) 'taken_at': takenAt,
      if (fileName != null) 'file_name': fileName,
      if (pose != null) 'pose': pose,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressPhotosTableCompanion copyWith({
    Value<String>? id,
    Value<int>? takenAt,
    Value<String>? fileName,
    Value<String>? pose,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return ProgressPhotosTableCompanion(
      id: id ?? this.id,
      takenAt: takenAt ?? this.takenAt,
      fileName: fileName ?? this.fileName,
      pose: pose ?? this.pose,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<int>(takenAt.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (pose.present) {
      map['pose'] = Variable<String>(pose.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressPhotosTableCompanion(')
          ..write('id: $id, ')
          ..write('takenAt: $takenAt, ')
          ..write('fileName: $fileName, ')
          ..write('pose: $pose, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserProfileTableTable userProfileTable = $UserProfileTableTable(
    this,
  );
  late final $AppSettingsTableTable appSettingsTable = $AppSettingsTableTable(
    this,
  );
  late final $ExercisesTableTable exercisesTable = $ExercisesTableTable(this);
  late final $RoutineFoldersTableTable routineFoldersTable =
      $RoutineFoldersTableTable(this);
  late final $RoutinesTableTable routinesTable = $RoutinesTableTable(this);
  late final $RoutineExercisesTableTable routineExercisesTable =
      $RoutineExercisesTableTable(this);
  late final $RoutineSetsTableTable routineSetsTable = $RoutineSetsTableTable(
    this,
  );
  late final $WorkoutsTableTable workoutsTable = $WorkoutsTableTable(this);
  late final $WorkoutExercisesTableTable workoutExercisesTable =
      $WorkoutExercisesTableTable(this);
  late final $WorkoutSetsTableTable workoutSetsTable = $WorkoutSetsTableTable(
    this,
  );
  late final $PersonalRecordsTableTable personalRecordsTable =
      $PersonalRecordsTableTable(this);
  late final $BodyMeasurementsTableTable bodyMeasurementsTable =
      $BodyMeasurementsTableTable(this);
  late final $ProgressPhotosTableTable progressPhotosTable =
      $ProgressPhotosTableTable(this);
  late final Index idxRoutineExercisesRoutine = Index(
    'idx_routine_exercises_routine',
    'CREATE INDEX idx_routine_exercises_routine ON routine_exercises (routine_id)',
  );
  late final Index idxRoutineSetsRoutineExercise = Index(
    'idx_routine_sets_routine_exercise',
    'CREATE INDEX idx_routine_sets_routine_exercise ON routine_sets (routine_exercise_id)',
  );
  late final Index idxWorkoutsStartedAt = Index(
    'idx_workouts_started_at',
    'CREATE INDEX idx_workouts_started_at ON workouts (started_at)',
  );
  late final Index idxWorkoutExercisesWorkout = Index(
    'idx_workout_exercises_workout',
    'CREATE INDEX idx_workout_exercises_workout ON workout_exercises (workout_id)',
  );
  late final Index idxWorkoutExercisesExercise = Index(
    'idx_workout_exercises_exercise',
    'CREATE INDEX idx_workout_exercises_exercise ON workout_exercises (exercise_id)',
  );
  late final Index idxWorkoutSetsWorkoutExercise = Index(
    'idx_workout_sets_workout_exercise',
    'CREATE INDEX idx_workout_sets_workout_exercise ON workout_sets (workout_exercise_id)',
  );
  late final Index idxPersonalRecordsExerciseType = Index(
    'idx_personal_records_exercise_type',
    'CREATE INDEX idx_personal_records_exercise_type ON personal_records (exercise_id, record_type)',
  );
  late final Index idxBodyMeasurementsTypeDate = Index(
    'idx_body_measurements_type_date',
    'CREATE INDEX idx_body_measurements_type_date ON body_measurements (type, measured_at)',
  );
  late final Index idxProgressPhotosTakenAt = Index(
    'idx_progress_photos_taken_at',
    'CREATE INDEX idx_progress_photos_taken_at ON progress_photos (taken_at)',
  );
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final ExercisesDao exercisesDao = ExercisesDao(this as AppDatabase);
  late final RoutinesDao routinesDao = RoutinesDao(this as AppDatabase);
  late final WorkoutsDao workoutsDao = WorkoutsDao(this as AppDatabase);
  late final RecordsDao recordsDao = RecordsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userProfileTable,
    appSettingsTable,
    exercisesTable,
    routineFoldersTable,
    routinesTable,
    routineExercisesTable,
    routineSetsTable,
    workoutsTable,
    workoutExercisesTable,
    workoutSetsTable,
    personalRecordsTable,
    bodyMeasurementsTable,
    progressPhotosTable,
    idxRoutineExercisesRoutine,
    idxRoutineSetsRoutineExercise,
    idxWorkoutsStartedAt,
    idxWorkoutExercisesWorkout,
    idxWorkoutExercisesExercise,
    idxWorkoutSetsWorkoutExercise,
    idxPersonalRecordsExerciseType,
    idxBodyMeasurementsTypeDate,
    idxProgressPhotosTakenAt,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'routine_folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('routines', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'routines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('routine_exercises', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'routine_exercises',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('routine_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'routines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workouts', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workouts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workout_exercises', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workout_exercises',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workout_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'exercises',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('personal_records', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workout_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('personal_records', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$UserProfileTableTableCreateCompanionBuilder =
    UserProfileTableCompanion Function({
      required String id,
      Value<String?> displayName,
      Value<int?> birthDate,
      Value<String?> sex,
      Value<double?> heightCm,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$UserProfileTableTableUpdateCompanionBuilder =
    UserProfileTableCompanion Function({
      Value<String> id,
      Value<String?> displayName,
      Value<int?> birthDate,
      Value<String?> sex,
      Value<double?> heightCm,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$UserProfileTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfileTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfileTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserProfileTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfileTableTable,
          UserProfileRow,
          $$UserProfileTableTableFilterComposer,
          $$UserProfileTableTableOrderingComposer,
          $$UserProfileTableTableAnnotationComposer,
          $$UserProfileTableTableCreateCompanionBuilder,
          $$UserProfileTableTableUpdateCompanionBuilder,
          (
            UserProfileRow,
            BaseReferences<
              _$AppDatabase,
              $UserProfileTableTable,
              UserProfileRow
            >,
          ),
          UserProfileRow,
          PrefetchHooks Function()
        > {
  $$UserProfileTableTableTableManager(
    _$AppDatabase db,
    $UserProfileTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<int?> birthDate = const Value.absent(),
                Value<String?> sex = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfileTableCompanion(
                id: id,
                displayName: displayName,
                birthDate: birthDate,
                sex: sex,
                heightCm: heightCm,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> displayName = const Value.absent(),
                Value<int?> birthDate = const Value.absent(),
                Value<String?> sex = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserProfileTableCompanion.insert(
                id: id,
                displayName: displayName,
                birthDate: birthDate,
                sex: sex,
                heightCm: heightCm,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfileTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfileTableTable,
      UserProfileRow,
      $$UserProfileTableTableFilterComposer,
      $$UserProfileTableTableOrderingComposer,
      $$UserProfileTableTableAnnotationComposer,
      $$UserProfileTableTableCreateCompanionBuilder,
      $$UserProfileTableTableUpdateCompanionBuilder,
      (
        UserProfileRow,
        BaseReferences<_$AppDatabase, $UserProfileTableTable, UserProfileRow>,
      ),
      UserProfileRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableTableCreateCompanionBuilder =
    AppSettingsTableCompanion Function({
      required String id,
      Value<String> unitWeight,
      Value<String> unitLength,
      Value<String> unitDistance,
      Value<int> defaultRestSeconds,
      Value<bool> restSoundEnabled,
      Value<bool> setCheckSoundEnabled,
      Value<bool> prAlertEnabled,
      Value<int?> lastBackupAt,
      Value<String?> pendingPickKind,
      Value<String?> pendingPickRef,
      Value<String> themeMode,
      Value<String> locale,
      Value<bool> onboardingDone,
      Value<bool> exercisesSeeded,
      Value<double> barWeightKg,
      Value<String> availablePlatesKg,
      Value<int> defaultWarmupSets,
      Value<int> prDefaultWarmupSets,
      Value<int> prDefaultExtraAttempts,
      Value<int> autoLockSeconds,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableTableUpdateCompanionBuilder =
    AppSettingsTableCompanion Function({
      Value<String> id,
      Value<String> unitWeight,
      Value<String> unitLength,
      Value<String> unitDistance,
      Value<int> defaultRestSeconds,
      Value<bool> restSoundEnabled,
      Value<bool> setCheckSoundEnabled,
      Value<bool> prAlertEnabled,
      Value<int?> lastBackupAt,
      Value<String?> pendingPickKind,
      Value<String?> pendingPickRef,
      Value<String> themeMode,
      Value<String> locale,
      Value<bool> onboardingDone,
      Value<bool> exercisesSeeded,
      Value<double> barWeightKg,
      Value<String> availablePlatesKg,
      Value<int> defaultWarmupSets,
      Value<int> prDefaultWarmupSets,
      Value<int> prDefaultExtraAttempts,
      Value<int> autoLockSeconds,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitWeight => $composableBuilder(
    column: $table.unitWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitLength => $composableBuilder(
    column: $table.unitLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitDistance => $composableBuilder(
    column: $table.unitDistance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultRestSeconds => $composableBuilder(
    column: $table.defaultRestSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get restSoundEnabled => $composableBuilder(
    column: $table.restSoundEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get setCheckSoundEnabled => $composableBuilder(
    column: $table.setCheckSoundEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get prAlertEnabled => $composableBuilder(
    column: $table.prAlertEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastBackupAt => $composableBuilder(
    column: $table.lastBackupAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingPickKind => $composableBuilder(
    column: $table.pendingPickKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingPickRef => $composableBuilder(
    column: $table.pendingPickRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get exercisesSeeded => $composableBuilder(
    column: $table.exercisesSeeded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get barWeightKg => $composableBuilder(
    column: $table.barWeightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availablePlatesKg => $composableBuilder(
    column: $table.availablePlatesKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultWarmupSets => $composableBuilder(
    column: $table.defaultWarmupSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get prDefaultWarmupSets => $composableBuilder(
    column: $table.prDefaultWarmupSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get prDefaultExtraAttempts => $composableBuilder(
    column: $table.prDefaultExtraAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoLockSeconds => $composableBuilder(
    column: $table.autoLockSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitWeight => $composableBuilder(
    column: $table.unitWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitLength => $composableBuilder(
    column: $table.unitLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitDistance => $composableBuilder(
    column: $table.unitDistance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultRestSeconds => $composableBuilder(
    column: $table.defaultRestSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get restSoundEnabled => $composableBuilder(
    column: $table.restSoundEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get setCheckSoundEnabled => $composableBuilder(
    column: $table.setCheckSoundEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get prAlertEnabled => $composableBuilder(
    column: $table.prAlertEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastBackupAt => $composableBuilder(
    column: $table.lastBackupAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingPickKind => $composableBuilder(
    column: $table.pendingPickKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingPickRef => $composableBuilder(
    column: $table.pendingPickRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get exercisesSeeded => $composableBuilder(
    column: $table.exercisesSeeded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get barWeightKg => $composableBuilder(
    column: $table.barWeightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availablePlatesKg => $composableBuilder(
    column: $table.availablePlatesKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultWarmupSets => $composableBuilder(
    column: $table.defaultWarmupSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get prDefaultWarmupSets => $composableBuilder(
    column: $table.prDefaultWarmupSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get prDefaultExtraAttempts => $composableBuilder(
    column: $table.prDefaultExtraAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoLockSeconds => $composableBuilder(
    column: $table.autoLockSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get unitWeight => $composableBuilder(
    column: $table.unitWeight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unitLength => $composableBuilder(
    column: $table.unitLength,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unitDistance => $composableBuilder(
    column: $table.unitDistance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultRestSeconds => $composableBuilder(
    column: $table.defaultRestSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get restSoundEnabled => $composableBuilder(
    column: $table.restSoundEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get setCheckSoundEnabled => $composableBuilder(
    column: $table.setCheckSoundEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get prAlertEnabled => $composableBuilder(
    column: $table.prAlertEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastBackupAt => $composableBuilder(
    column: $table.lastBackupAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pendingPickKind => $composableBuilder(
    column: $table.pendingPickKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pendingPickRef => $composableBuilder(
    column: $table.pendingPickRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<String> get locale =>
      $composableBuilder(column: $table.locale, builder: (column) => column);

  GeneratedColumn<bool> get onboardingDone => $composableBuilder(
    column: $table.onboardingDone,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get exercisesSeeded => $composableBuilder(
    column: $table.exercisesSeeded,
    builder: (column) => column,
  );

  GeneratedColumn<double> get barWeightKg => $composableBuilder(
    column: $table.barWeightKg,
    builder: (column) => column,
  );

  GeneratedColumn<String> get availablePlatesKg => $composableBuilder(
    column: $table.availablePlatesKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultWarmupSets => $composableBuilder(
    column: $table.defaultWarmupSets,
    builder: (column) => column,
  );

  GeneratedColumn<int> get prDefaultWarmupSets => $composableBuilder(
    column: $table.prDefaultWarmupSets,
    builder: (column) => column,
  );

  GeneratedColumn<int> get prDefaultExtraAttempts => $composableBuilder(
    column: $table.prDefaultExtraAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoLockSeconds => $composableBuilder(
    column: $table.autoLockSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTableTable,
          AppSettingsRow,
          $$AppSettingsTableTableFilterComposer,
          $$AppSettingsTableTableOrderingComposer,
          $$AppSettingsTableTableAnnotationComposer,
          $$AppSettingsTableTableCreateCompanionBuilder,
          $$AppSettingsTableTableUpdateCompanionBuilder,
          (
            AppSettingsRow,
            BaseReferences<
              _$AppDatabase,
              $AppSettingsTableTable,
              AppSettingsRow
            >,
          ),
          AppSettingsRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableTableManager(
    _$AppDatabase db,
    $AppSettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> unitWeight = const Value.absent(),
                Value<String> unitLength = const Value.absent(),
                Value<String> unitDistance = const Value.absent(),
                Value<int> defaultRestSeconds = const Value.absent(),
                Value<bool> restSoundEnabled = const Value.absent(),
                Value<bool> setCheckSoundEnabled = const Value.absent(),
                Value<bool> prAlertEnabled = const Value.absent(),
                Value<int?> lastBackupAt = const Value.absent(),
                Value<String?> pendingPickKind = const Value.absent(),
                Value<String?> pendingPickRef = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<bool> onboardingDone = const Value.absent(),
                Value<bool> exercisesSeeded = const Value.absent(),
                Value<double> barWeightKg = const Value.absent(),
                Value<String> availablePlatesKg = const Value.absent(),
                Value<int> defaultWarmupSets = const Value.absent(),
                Value<int> prDefaultWarmupSets = const Value.absent(),
                Value<int> prDefaultExtraAttempts = const Value.absent(),
                Value<int> autoLockSeconds = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsTableCompanion(
                id: id,
                unitWeight: unitWeight,
                unitLength: unitLength,
                unitDistance: unitDistance,
                defaultRestSeconds: defaultRestSeconds,
                restSoundEnabled: restSoundEnabled,
                setCheckSoundEnabled: setCheckSoundEnabled,
                prAlertEnabled: prAlertEnabled,
                lastBackupAt: lastBackupAt,
                pendingPickKind: pendingPickKind,
                pendingPickRef: pendingPickRef,
                themeMode: themeMode,
                locale: locale,
                onboardingDone: onboardingDone,
                exercisesSeeded: exercisesSeeded,
                barWeightKg: barWeightKg,
                availablePlatesKg: availablePlatesKg,
                defaultWarmupSets: defaultWarmupSets,
                prDefaultWarmupSets: prDefaultWarmupSets,
                prDefaultExtraAttempts: prDefaultExtraAttempts,
                autoLockSeconds: autoLockSeconds,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> unitWeight = const Value.absent(),
                Value<String> unitLength = const Value.absent(),
                Value<String> unitDistance = const Value.absent(),
                Value<int> defaultRestSeconds = const Value.absent(),
                Value<bool> restSoundEnabled = const Value.absent(),
                Value<bool> setCheckSoundEnabled = const Value.absent(),
                Value<bool> prAlertEnabled = const Value.absent(),
                Value<int?> lastBackupAt = const Value.absent(),
                Value<String?> pendingPickKind = const Value.absent(),
                Value<String?> pendingPickRef = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<bool> onboardingDone = const Value.absent(),
                Value<bool> exercisesSeeded = const Value.absent(),
                Value<double> barWeightKg = const Value.absent(),
                Value<String> availablePlatesKg = const Value.absent(),
                Value<int> defaultWarmupSets = const Value.absent(),
                Value<int> prDefaultWarmupSets = const Value.absent(),
                Value<int> prDefaultExtraAttempts = const Value.absent(),
                Value<int> autoLockSeconds = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsTableCompanion.insert(
                id: id,
                unitWeight: unitWeight,
                unitLength: unitLength,
                unitDistance: unitDistance,
                defaultRestSeconds: defaultRestSeconds,
                restSoundEnabled: restSoundEnabled,
                setCheckSoundEnabled: setCheckSoundEnabled,
                prAlertEnabled: prAlertEnabled,
                lastBackupAt: lastBackupAt,
                pendingPickKind: pendingPickKind,
                pendingPickRef: pendingPickRef,
                themeMode: themeMode,
                locale: locale,
                onboardingDone: onboardingDone,
                exercisesSeeded: exercisesSeeded,
                barWeightKg: barWeightKg,
                availablePlatesKg: availablePlatesKg,
                defaultWarmupSets: defaultWarmupSets,
                prDefaultWarmupSets: prDefaultWarmupSets,
                prDefaultExtraAttempts: prDefaultExtraAttempts,
                autoLockSeconds: autoLockSeconds,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTableTable,
      AppSettingsRow,
      $$AppSettingsTableTableFilterComposer,
      $$AppSettingsTableTableOrderingComposer,
      $$AppSettingsTableTableAnnotationComposer,
      $$AppSettingsTableTableCreateCompanionBuilder,
      $$AppSettingsTableTableUpdateCompanionBuilder,
      (
        AppSettingsRow,
        BaseReferences<_$AppDatabase, $AppSettingsTableTable, AppSettingsRow>,
      ),
      AppSettingsRow,
      PrefetchHooks Function()
    >;
typedef $$ExercisesTableTableCreateCompanionBuilder =
    ExercisesTableCompanion Function({
      required String id,
      required String name,
      required String primaryMuscle,
      Value<String> secondaryMuscles,
      Value<String?> equipment,
      required String category,
      Value<String?> instructions,
      Value<String?> imageAsset,
      Value<String?> startImageFile,
      Value<String?> endImageFile,
      Value<bool> isCustom,
      Value<bool> isArchived,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$ExercisesTableTableUpdateCompanionBuilder =
    ExercisesTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> primaryMuscle,
      Value<String> secondaryMuscles,
      Value<String?> equipment,
      Value<String> category,
      Value<String?> instructions,
      Value<String?> imageAsset,
      Value<String?> startImageFile,
      Value<String?> endImageFile,
      Value<bool> isCustom,
      Value<bool> isArchived,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$ExercisesTableTableReferences
    extends BaseReferences<_$AppDatabase, $ExercisesTableTable, ExerciseRow> {
  $$ExercisesTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $RoutineExercisesTableTable,
    List<RoutineExerciseRow>
  >
  _routineExercisesTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.routineExercisesTable,
        aliasName: 'exercises__id__routine_exercises__exercise_id',
      );

  $$RoutineExercisesTableTableProcessedTableManager
  get routineExercisesTableRefs {
    final manager = $$RoutineExercisesTableTableTableManager(
      $_db,
      $_db.routineExercisesTable,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _routineExercisesTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WorkoutExercisesTableTable,
    List<WorkoutExerciseRow>
  >
  _workoutExercisesTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workoutExercisesTable,
        aliasName: 'exercises__id__workout_exercises__exercise_id',
      );

  $$WorkoutExercisesTableTableProcessedTableManager
  get workoutExercisesTableRefs {
    final manager = $$WorkoutExercisesTableTableTableManager(
      $_db,
      $_db.workoutExercisesTable,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workoutExercisesTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PersonalRecordsTableTable,
    List<PersonalRecordRow>
  >
  _personalRecordsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.personalRecordsTable,
        aliasName: 'exercises__id__personal_records__exercise_id',
      );

  $$PersonalRecordsTableTableProcessedTableManager
  get personalRecordsTableRefs {
    final manager = $$PersonalRecordsTableTableTableManager(
      $_db,
      $_db.personalRecordsTable,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _personalRecordsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExercisesTableTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTableTable> {
  $$ExercisesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryMuscle => $composableBuilder(
    column: $table.primaryMuscle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryMuscles => $composableBuilder(
    column: $table.secondaryMuscles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageAsset => $composableBuilder(
    column: $table.imageAsset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startImageFile => $composableBuilder(
    column: $table.startImageFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endImageFile => $composableBuilder(
    column: $table.endImageFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> routineExercisesTableRefs(
    Expression<bool> Function($$RoutineExercisesTableTableFilterComposer f) f,
  ) {
    final $$RoutineExercisesTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.routineExercisesTable,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoutineExercisesTableTableFilterComposer(
                $db: $db,
                $table: $db.routineExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> workoutExercisesTableRefs(
    Expression<bool> Function($$WorkoutExercisesTableTableFilterComposer f) f,
  ) {
    final $$WorkoutExercisesTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutExercisesTable,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExercisesTableTableFilterComposer(
                $db: $db,
                $table: $db.workoutExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> personalRecordsTableRefs(
    Expression<bool> Function($$PersonalRecordsTableTableFilterComposer f) f,
  ) {
    final $$PersonalRecordsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personalRecordsTable,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonalRecordsTableTableFilterComposer(
            $db: $db,
            $table: $db.personalRecordsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExercisesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTableTable> {
  $$ExercisesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryMuscle => $composableBuilder(
    column: $table.primaryMuscle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryMuscles => $composableBuilder(
    column: $table.secondaryMuscles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageAsset => $composableBuilder(
    column: $table.imageAsset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startImageFile => $composableBuilder(
    column: $table.startImageFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endImageFile => $composableBuilder(
    column: $table.endImageFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExercisesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTableTable> {
  $$ExercisesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get primaryMuscle => $composableBuilder(
    column: $table.primaryMuscle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryMuscles => $composableBuilder(
    column: $table.secondaryMuscles,
    builder: (column) => column,
  );

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageAsset => $composableBuilder(
    column: $table.imageAsset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startImageFile => $composableBuilder(
    column: $table.startImageFile,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endImageFile => $composableBuilder(
    column: $table.endImageFile,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> routineExercisesTableRefs<T extends Object>(
    Expression<T> Function($$RoutineExercisesTableTableAnnotationComposer a) f,
  ) {
    final $$RoutineExercisesTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.routineExercisesTable,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoutineExercisesTableTableAnnotationComposer(
                $db: $db,
                $table: $db.routineExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> workoutExercisesTableRefs<T extends Object>(
    Expression<T> Function($$WorkoutExercisesTableTableAnnotationComposer a) f,
  ) {
    final $$WorkoutExercisesTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutExercisesTable,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExercisesTableTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> personalRecordsTableRefs<T extends Object>(
    Expression<T> Function($$PersonalRecordsTableTableAnnotationComposer a) f,
  ) {
    final $$PersonalRecordsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.personalRecordsTable,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PersonalRecordsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.personalRecordsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ExercisesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTableTable,
          ExerciseRow,
          $$ExercisesTableTableFilterComposer,
          $$ExercisesTableTableOrderingComposer,
          $$ExercisesTableTableAnnotationComposer,
          $$ExercisesTableTableCreateCompanionBuilder,
          $$ExercisesTableTableUpdateCompanionBuilder,
          (ExerciseRow, $$ExercisesTableTableReferences),
          ExerciseRow,
          PrefetchHooks Function({
            bool routineExercisesTableRefs,
            bool workoutExercisesTableRefs,
            bool personalRecordsTableRefs,
          })
        > {
  $$ExercisesTableTableTableManager(
    _$AppDatabase db,
    $ExercisesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> primaryMuscle = const Value.absent(),
                Value<String> secondaryMuscles = const Value.absent(),
                Value<String?> equipment = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> instructions = const Value.absent(),
                Value<String?> imageAsset = const Value.absent(),
                Value<String?> startImageFile = const Value.absent(),
                Value<String?> endImageFile = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExercisesTableCompanion(
                id: id,
                name: name,
                primaryMuscle: primaryMuscle,
                secondaryMuscles: secondaryMuscles,
                equipment: equipment,
                category: category,
                instructions: instructions,
                imageAsset: imageAsset,
                startImageFile: startImageFile,
                endImageFile: endImageFile,
                isCustom: isCustom,
                isArchived: isArchived,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String primaryMuscle,
                Value<String> secondaryMuscles = const Value.absent(),
                Value<String?> equipment = const Value.absent(),
                required String category,
                Value<String?> instructions = const Value.absent(),
                Value<String?> imageAsset = const Value.absent(),
                Value<String?> startImageFile = const Value.absent(),
                Value<String?> endImageFile = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ExercisesTableCompanion.insert(
                id: id,
                name: name,
                primaryMuscle: primaryMuscle,
                secondaryMuscles: secondaryMuscles,
                equipment: equipment,
                category: category,
                instructions: instructions,
                imageAsset: imageAsset,
                startImageFile: startImageFile,
                endImageFile: endImageFile,
                isCustom: isCustom,
                isArchived: isArchived,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExercisesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                routineExercisesTableRefs = false,
                workoutExercisesTableRefs = false,
                personalRecordsTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (routineExercisesTableRefs) db.routineExercisesTable,
                    if (workoutExercisesTableRefs) db.workoutExercisesTable,
                    if (personalRecordsTableRefs) db.personalRecordsTable,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (routineExercisesTableRefs)
                        await $_getPrefetchedData<
                          ExerciseRow,
                          $ExercisesTableTable,
                          RoutineExerciseRow
                        >(
                          currentTable: table,
                          referencedTable: $$ExercisesTableTableReferences
                              ._routineExercisesTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExercisesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).routineExercisesTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.exerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workoutExercisesTableRefs)
                        await $_getPrefetchedData<
                          ExerciseRow,
                          $ExercisesTableTable,
                          WorkoutExerciseRow
                        >(
                          currentTable: table,
                          referencedTable: $$ExercisesTableTableReferences
                              ._workoutExercisesTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExercisesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutExercisesTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.exerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (personalRecordsTableRefs)
                        await $_getPrefetchedData<
                          ExerciseRow,
                          $ExercisesTableTable,
                          PersonalRecordRow
                        >(
                          currentTable: table,
                          referencedTable: $$ExercisesTableTableReferences
                              ._personalRecordsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExercisesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).personalRecordsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.exerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ExercisesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTableTable,
      ExerciseRow,
      $$ExercisesTableTableFilterComposer,
      $$ExercisesTableTableOrderingComposer,
      $$ExercisesTableTableAnnotationComposer,
      $$ExercisesTableTableCreateCompanionBuilder,
      $$ExercisesTableTableUpdateCompanionBuilder,
      (ExerciseRow, $$ExercisesTableTableReferences),
      ExerciseRow,
      PrefetchHooks Function({
        bool routineExercisesTableRefs,
        bool workoutExercisesTableRefs,
        bool personalRecordsTableRefs,
      })
    >;
typedef $$RoutineFoldersTableTableCreateCompanionBuilder =
    RoutineFoldersTableCompanion Function({
      required String id,
      required String name,
      required int sortOrder,
      Value<int> rowid,
    });
typedef $$RoutineFoldersTableTableUpdateCompanionBuilder =
    RoutineFoldersTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$RoutineFoldersTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RoutineFoldersTableTable,
          RoutineFolderRow
        > {
  $$RoutineFoldersTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$RoutinesTableTable, List<RoutineRow>>
  _routinesTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.routinesTable,
    aliasName: 'routine_folders__id__routines__folder_id',
  );

  $$RoutinesTableTableProcessedTableManager get routinesTableRefs {
    final manager = $$RoutinesTableTableTableManager(
      $_db,
      $_db.routinesTable,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_routinesTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RoutineFoldersTableTableFilterComposer
    extends Composer<_$AppDatabase, $RoutineFoldersTableTable> {
  $$RoutineFoldersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> routinesTableRefs(
    Expression<bool> Function($$RoutinesTableTableFilterComposer f) f,
  ) {
    final $$RoutinesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routinesTable,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableTableFilterComposer(
            $db: $db,
            $table: $db.routinesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutineFoldersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutineFoldersTableTable> {
  $$RoutineFoldersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutineFoldersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutineFoldersTableTable> {
  $$RoutineFoldersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> routinesTableRefs<T extends Object>(
    Expression<T> Function($$RoutinesTableTableAnnotationComposer a) f,
  ) {
    final $$RoutinesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routinesTable,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.routinesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutineFoldersTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutineFoldersTableTable,
          RoutineFolderRow,
          $$RoutineFoldersTableTableFilterComposer,
          $$RoutineFoldersTableTableOrderingComposer,
          $$RoutineFoldersTableTableAnnotationComposer,
          $$RoutineFoldersTableTableCreateCompanionBuilder,
          $$RoutineFoldersTableTableUpdateCompanionBuilder,
          (RoutineFolderRow, $$RoutineFoldersTableTableReferences),
          RoutineFolderRow,
          PrefetchHooks Function({bool routinesTableRefs})
        > {
  $$RoutineFoldersTableTableTableManager(
    _$AppDatabase db,
    $RoutineFoldersTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutineFoldersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutineFoldersTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RoutineFoldersTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineFoldersTableCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => RoutineFoldersTableCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RoutineFoldersTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({routinesTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (routinesTableRefs) db.routinesTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (routinesTableRefs)
                    await $_getPrefetchedData<
                      RoutineFolderRow,
                      $RoutineFoldersTableTable,
                      RoutineRow
                    >(
                      currentTable: table,
                      referencedTable: $$RoutineFoldersTableTableReferences
                          ._routinesTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RoutineFoldersTableTableReferences(
                            db,
                            table,
                            p0,
                          ).routinesTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RoutineFoldersTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutineFoldersTableTable,
      RoutineFolderRow,
      $$RoutineFoldersTableTableFilterComposer,
      $$RoutineFoldersTableTableOrderingComposer,
      $$RoutineFoldersTableTableAnnotationComposer,
      $$RoutineFoldersTableTableCreateCompanionBuilder,
      $$RoutineFoldersTableTableUpdateCompanionBuilder,
      (RoutineFolderRow, $$RoutineFoldersTableTableReferences),
      RoutineFolderRow,
      PrefetchHooks Function({bool routinesTableRefs})
    >;
typedef $$RoutinesTableTableCreateCompanionBuilder =
    RoutinesTableCompanion Function({
      required String id,
      required String name,
      Value<String?> notes,
      Value<String?> folderId,
      required int sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int?> lastPerformedAt,
      Value<int> rowid,
    });
typedef $$RoutinesTableTableUpdateCompanionBuilder =
    RoutinesTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> notes,
      Value<String?> folderId,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> lastPerformedAt,
      Value<int> rowid,
    });

final class $$RoutinesTableTableReferences
    extends BaseReferences<_$AppDatabase, $RoutinesTableTable, RoutineRow> {
  $$RoutinesTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RoutineFoldersTableTable _folderIdTable(_$AppDatabase db) => db
      .routineFoldersTable
      .createAlias('routines__folder_id__routine_folders__id');

  $$RoutineFoldersTableTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<String>('folder_id');
    if ($_column == null) return null;
    final manager = $$RoutineFoldersTableTableTableManager(
      $_db,
      $_db.routineFoldersTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $RoutineExercisesTableTable,
    List<RoutineExerciseRow>
  >
  _routineExercisesTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.routineExercisesTable,
        aliasName: 'routines__id__routine_exercises__routine_id',
      );

  $$RoutineExercisesTableTableProcessedTableManager
  get routineExercisesTableRefs {
    final manager = $$RoutineExercisesTableTableTableManager(
      $_db,
      $_db.routineExercisesTable,
    ).filter((f) => f.routineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _routineExercisesTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkoutsTableTable, List<WorkoutRow>>
  _workoutsTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutsTable,
    aliasName: 'routines__id__workouts__routine_id',
  );

  $$WorkoutsTableTableProcessedTableManager get workoutsTableRefs {
    final manager = $$WorkoutsTableTableTableManager(
      $_db,
      $_db.workoutsTable,
    ).filter((f) => f.routineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutsTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RoutinesTableTableFilterComposer
    extends Composer<_$AppDatabase, $RoutinesTableTable> {
  $$RoutinesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPerformedAt => $composableBuilder(
    column: $table.lastPerformedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RoutineFoldersTableTableFilterComposer get folderId {
    final $$RoutineFoldersTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.routineFoldersTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutineFoldersTableTableFilterComposer(
            $db: $db,
            $table: $db.routineFoldersTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> routineExercisesTableRefs(
    Expression<bool> Function($$RoutineExercisesTableTableFilterComposer f) f,
  ) {
    final $$RoutineExercisesTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.routineExercisesTable,
          getReferencedColumn: (t) => t.routineId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoutineExercisesTableTableFilterComposer(
                $db: $db,
                $table: $db.routineExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> workoutsTableRefs(
    Expression<bool> Function($$WorkoutsTableTableFilterComposer f) f,
  ) {
    final $$WorkoutsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutsTable,
      getReferencedColumn: (t) => t.routineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutinesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutinesTableTable> {
  $$RoutinesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPerformedAt => $composableBuilder(
    column: $table.lastPerformedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoutineFoldersTableTableOrderingComposer get folderId {
    final $$RoutineFoldersTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.folderId,
          referencedTable: $db.routineFoldersTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoutineFoldersTableTableOrderingComposer(
                $db: $db,
                $table: $db.routineFoldersTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$RoutinesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutinesTableTable> {
  $$RoutinesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get lastPerformedAt => $composableBuilder(
    column: $table.lastPerformedAt,
    builder: (column) => column,
  );

  $$RoutineFoldersTableTableAnnotationComposer get folderId {
    final $$RoutineFoldersTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.folderId,
          referencedTable: $db.routineFoldersTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoutineFoldersTableTableAnnotationComposer(
                $db: $db,
                $table: $db.routineFoldersTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> routineExercisesTableRefs<T extends Object>(
    Expression<T> Function($$RoutineExercisesTableTableAnnotationComposer a) f,
  ) {
    final $$RoutineExercisesTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.routineExercisesTable,
          getReferencedColumn: (t) => t.routineId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoutineExercisesTableTableAnnotationComposer(
                $db: $db,
                $table: $db.routineExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> workoutsTableRefs<T extends Object>(
    Expression<T> Function($$WorkoutsTableTableAnnotationComposer a) f,
  ) {
    final $$WorkoutsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutsTable,
      getReferencedColumn: (t) => t.routineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutinesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutinesTableTable,
          RoutineRow,
          $$RoutinesTableTableFilterComposer,
          $$RoutinesTableTableOrderingComposer,
          $$RoutinesTableTableAnnotationComposer,
          $$RoutinesTableTableCreateCompanionBuilder,
          $$RoutinesTableTableUpdateCompanionBuilder,
          (RoutineRow, $$RoutinesTableTableReferences),
          RoutineRow,
          PrefetchHooks Function({
            bool folderId,
            bool routineExercisesTableRefs,
            bool workoutsTableRefs,
          })
        > {
  $$RoutinesTableTableTableManager(_$AppDatabase db, $RoutinesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutinesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutinesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutinesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> lastPerformedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutinesTableCompanion(
                id: id,
                name: name,
                notes: notes,
                folderId: folderId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastPerformedAt: lastPerformedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> notes = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                required int sortOrder,
                required int createdAt,
                required int updatedAt,
                Value<int?> lastPerformedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutinesTableCompanion.insert(
                id: id,
                name: name,
                notes: notes,
                folderId: folderId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastPerformedAt: lastPerformedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RoutinesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                folderId = false,
                routineExercisesTableRefs = false,
                workoutsTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (routineExercisesTableRefs) db.routineExercisesTable,
                    if (workoutsTableRefs) db.workoutsTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (folderId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.folderId,
                            referencedTable: $$RoutinesTableTableReferences
                                ._folderIdTable(db),
                            referencedColumn: $$RoutinesTableTableReferences
                                ._folderIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (routineExercisesTableRefs)
                        await $_getPrefetchedData<
                          RoutineRow,
                          $RoutinesTableTable,
                          RoutineExerciseRow
                        >(
                          currentTable: table,
                          referencedTable: $$RoutinesTableTableReferences
                              ._routineExercisesTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RoutinesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).routineExercisesTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.routineId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workoutsTableRefs)
                        await $_getPrefetchedData<
                          RoutineRow,
                          $RoutinesTableTable,
                          WorkoutRow
                        >(
                          currentTable: table,
                          referencedTable: $$RoutinesTableTableReferences
                              ._workoutsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RoutinesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.routineId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RoutinesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutinesTableTable,
      RoutineRow,
      $$RoutinesTableTableFilterComposer,
      $$RoutinesTableTableOrderingComposer,
      $$RoutinesTableTableAnnotationComposer,
      $$RoutinesTableTableCreateCompanionBuilder,
      $$RoutinesTableTableUpdateCompanionBuilder,
      (RoutineRow, $$RoutinesTableTableReferences),
      RoutineRow,
      PrefetchHooks Function({
        bool folderId,
        bool routineExercisesTableRefs,
        bool workoutsTableRefs,
      })
    >;
typedef $$RoutineExercisesTableTableCreateCompanionBuilder =
    RoutineExercisesTableCompanion Function({
      required String id,
      required String routineId,
      required String exerciseId,
      required int sortOrder,
      Value<int?> restSeconds,
      Value<int?> supersetGroup,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$RoutineExercisesTableTableUpdateCompanionBuilder =
    RoutineExercisesTableCompanion Function({
      Value<String> id,
      Value<String> routineId,
      Value<String> exerciseId,
      Value<int> sortOrder,
      Value<int?> restSeconds,
      Value<int?> supersetGroup,
      Value<String?> notes,
      Value<int> rowid,
    });

final class $$RoutineExercisesTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RoutineExercisesTableTable,
          RoutineExerciseRow
        > {
  $$RoutineExercisesTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RoutinesTableTable _routineIdTable(_$AppDatabase db) => db
      .routinesTable
      .createAlias('routine_exercises__routine_id__routines__id');

  $$RoutinesTableTableProcessedTableManager get routineId {
    final $_column = $_itemColumn<String>('routine_id')!;

    final manager = $$RoutinesTableTableTableManager(
      $_db,
      $_db.routinesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_routineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExercisesTableTable _exerciseIdTable(_$AppDatabase db) => db
      .exercisesTable
      .createAlias('routine_exercises__exercise_id__exercises__id');

  $$ExercisesTableTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<String>('exercise_id')!;

    final manager = $$ExercisesTableTableTableManager(
      $_db,
      $_db.exercisesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RoutineSetsTableTable, List<RoutineSetRow>>
  _routineSetsTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.routineSetsTable,
    aliasName: 'routine_exercises__id__routine_sets__routine_exercise_id',
  );

  $$RoutineSetsTableTableProcessedTableManager get routineSetsTableRefs {
    final manager =
        $$RoutineSetsTableTableTableManager($_db, $_db.routineSetsTable).filter(
          (f) => f.routineExerciseId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _routineSetsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RoutineExercisesTableTableFilterComposer
    extends Composer<_$AppDatabase, $RoutineExercisesTableTable> {
  $$RoutineExercisesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get supersetGroup => $composableBuilder(
    column: $table.supersetGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$RoutinesTableTableFilterComposer get routineId {
    final $$RoutinesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routinesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableTableFilterComposer(
            $db: $db,
            $table: $db.routinesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableTableFilterComposer get exerciseId {
    final $$ExercisesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercisesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableTableFilterComposer(
            $db: $db,
            $table: $db.exercisesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> routineSetsTableRefs(
    Expression<bool> Function($$RoutineSetsTableTableFilterComposer f) f,
  ) {
    final $$RoutineSetsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routineSetsTable,
      getReferencedColumn: (t) => t.routineExerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutineSetsTableTableFilterComposer(
            $db: $db,
            $table: $db.routineSetsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutineExercisesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutineExercisesTableTable> {
  $$RoutineExercisesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get supersetGroup => $composableBuilder(
    column: $table.supersetGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoutinesTableTableOrderingComposer get routineId {
    final $$RoutinesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routinesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableTableOrderingComposer(
            $db: $db,
            $table: $db.routinesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableTableOrderingComposer get exerciseId {
    final $$ExercisesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercisesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableTableOrderingComposer(
            $db: $db,
            $table: $db.exercisesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutineExercisesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutineExercisesTableTable> {
  $$RoutineExercisesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get supersetGroup => $composableBuilder(
    column: $table.supersetGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$RoutinesTableTableAnnotationComposer get routineId {
    final $$RoutinesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routinesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.routinesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableTableAnnotationComposer get exerciseId {
    final $$ExercisesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercisesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.exercisesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> routineSetsTableRefs<T extends Object>(
    Expression<T> Function($$RoutineSetsTableTableAnnotationComposer a) f,
  ) {
    final $$RoutineSetsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routineSetsTable,
      getReferencedColumn: (t) => t.routineExerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutineSetsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.routineSetsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutineExercisesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutineExercisesTableTable,
          RoutineExerciseRow,
          $$RoutineExercisesTableTableFilterComposer,
          $$RoutineExercisesTableTableOrderingComposer,
          $$RoutineExercisesTableTableAnnotationComposer,
          $$RoutineExercisesTableTableCreateCompanionBuilder,
          $$RoutineExercisesTableTableUpdateCompanionBuilder,
          (RoutineExerciseRow, $$RoutineExercisesTableTableReferences),
          RoutineExerciseRow,
          PrefetchHooks Function({
            bool routineId,
            bool exerciseId,
            bool routineSetsTableRefs,
          })
        > {
  $$RoutineExercisesTableTableTableManager(
    _$AppDatabase db,
    $RoutineExercisesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutineExercisesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RoutineExercisesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RoutineExercisesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> routineId = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<int?> supersetGroup = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineExercisesTableCompanion(
                id: id,
                routineId: routineId,
                exerciseId: exerciseId,
                sortOrder: sortOrder,
                restSeconds: restSeconds,
                supersetGroup: supersetGroup,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String routineId,
                required String exerciseId,
                required int sortOrder,
                Value<int?> restSeconds = const Value.absent(),
                Value<int?> supersetGroup = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineExercisesTableCompanion.insert(
                id: id,
                routineId: routineId,
                exerciseId: exerciseId,
                sortOrder: sortOrder,
                restSeconds: restSeconds,
                supersetGroup: supersetGroup,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RoutineExercisesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                routineId = false,
                exerciseId = false,
                routineSetsTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (routineSetsTableRefs) db.routineSetsTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (routineId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.routineId,
                            referencedTable:
                                $$RoutineExercisesTableTableReferences
                                    ._routineIdTable(db),
                            referencedColumn:
                                $$RoutineExercisesTableTableReferences
                                    ._routineIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (exerciseId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.exerciseId,
                            referencedTable:
                                $$RoutineExercisesTableTableReferences
                                    ._exerciseIdTable(db),
                            referencedColumn:
                                $$RoutineExercisesTableTableReferences
                                    ._exerciseIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (routineSetsTableRefs)
                        await $_getPrefetchedData<
                          RoutineExerciseRow,
                          $RoutineExercisesTableTable,
                          RoutineSetRow
                        >(
                          currentTable: table,
                          referencedTable:
                              $$RoutineExercisesTableTableReferences
                                  ._routineSetsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RoutineExercisesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).routineSetsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.routineExerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RoutineExercisesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutineExercisesTableTable,
      RoutineExerciseRow,
      $$RoutineExercisesTableTableFilterComposer,
      $$RoutineExercisesTableTableOrderingComposer,
      $$RoutineExercisesTableTableAnnotationComposer,
      $$RoutineExercisesTableTableCreateCompanionBuilder,
      $$RoutineExercisesTableTableUpdateCompanionBuilder,
      (RoutineExerciseRow, $$RoutineExercisesTableTableReferences),
      RoutineExerciseRow,
      PrefetchHooks Function({
        bool routineId,
        bool exerciseId,
        bool routineSetsTableRefs,
      })
    >;
typedef $$RoutineSetsTableTableCreateCompanionBuilder =
    RoutineSetsTableCompanion Function({
      required String id,
      required String routineExerciseId,
      required int sortOrder,
      Value<String> setType,
      Value<int?> targetReps,
      Value<double?> targetWeightKg,
      Value<int?> targetDurationSeconds,
      Value<int> rowid,
    });
typedef $$RoutineSetsTableTableUpdateCompanionBuilder =
    RoutineSetsTableCompanion Function({
      Value<String> id,
      Value<String> routineExerciseId,
      Value<int> sortOrder,
      Value<String> setType,
      Value<int?> targetReps,
      Value<double?> targetWeightKg,
      Value<int?> targetDurationSeconds,
      Value<int> rowid,
    });

final class $$RoutineSetsTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $RoutineSetsTableTable, RoutineSetRow> {
  $$RoutineSetsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RoutineExercisesTableTable _routineExerciseIdTable(
    _$AppDatabase db,
  ) => db.routineExercisesTable.createAlias(
    'routine_sets__routine_exercise_id__routine_exercises__id',
  );

  $$RoutineExercisesTableTableProcessedTableManager get routineExerciseId {
    final $_column = $_itemColumn<String>('routine_exercise_id')!;

    final manager = $$RoutineExercisesTableTableTableManager(
      $_db,
      $_db.routineExercisesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_routineExerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RoutineSetsTableTableFilterComposer
    extends Composer<_$AppDatabase, $RoutineSetsTableTable> {
  $$RoutineSetsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setType => $composableBuilder(
    column: $table.setType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetDurationSeconds => $composableBuilder(
    column: $table.targetDurationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  $$RoutineExercisesTableTableFilterComposer get routineExerciseId {
    final $$RoutineExercisesTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.routineExerciseId,
          referencedTable: $db.routineExercisesTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoutineExercisesTableTableFilterComposer(
                $db: $db,
                $table: $db.routineExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$RoutineSetsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutineSetsTableTable> {
  $$RoutineSetsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setType => $composableBuilder(
    column: $table.setType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetDurationSeconds => $composableBuilder(
    column: $table.targetDurationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoutineExercisesTableTableOrderingComposer get routineExerciseId {
    final $$RoutineExercisesTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.routineExerciseId,
          referencedTable: $db.routineExercisesTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoutineExercisesTableTableOrderingComposer(
                $db: $db,
                $table: $db.routineExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$RoutineSetsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutineSetsTableTable> {
  $$RoutineSetsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get setType =>
      $composableBuilder(column: $table.setType, builder: (column) => column);

  GeneratedColumn<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetDurationSeconds => $composableBuilder(
    column: $table.targetDurationSeconds,
    builder: (column) => column,
  );

  $$RoutineExercisesTableTableAnnotationComposer get routineExerciseId {
    final $$RoutineExercisesTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.routineExerciseId,
          referencedTable: $db.routineExercisesTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoutineExercisesTableTableAnnotationComposer(
                $db: $db,
                $table: $db.routineExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$RoutineSetsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutineSetsTableTable,
          RoutineSetRow,
          $$RoutineSetsTableTableFilterComposer,
          $$RoutineSetsTableTableOrderingComposer,
          $$RoutineSetsTableTableAnnotationComposer,
          $$RoutineSetsTableTableCreateCompanionBuilder,
          $$RoutineSetsTableTableUpdateCompanionBuilder,
          (RoutineSetRow, $$RoutineSetsTableTableReferences),
          RoutineSetRow,
          PrefetchHooks Function({bool routineExerciseId})
        > {
  $$RoutineSetsTableTableTableManager(
    _$AppDatabase db,
    $RoutineSetsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutineSetsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutineSetsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutineSetsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> routineExerciseId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> setType = const Value.absent(),
                Value<int?> targetReps = const Value.absent(),
                Value<double?> targetWeightKg = const Value.absent(),
                Value<int?> targetDurationSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineSetsTableCompanion(
                id: id,
                routineExerciseId: routineExerciseId,
                sortOrder: sortOrder,
                setType: setType,
                targetReps: targetReps,
                targetWeightKg: targetWeightKg,
                targetDurationSeconds: targetDurationSeconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String routineExerciseId,
                required int sortOrder,
                Value<String> setType = const Value.absent(),
                Value<int?> targetReps = const Value.absent(),
                Value<double?> targetWeightKg = const Value.absent(),
                Value<int?> targetDurationSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineSetsTableCompanion.insert(
                id: id,
                routineExerciseId: routineExerciseId,
                sortOrder: sortOrder,
                setType: setType,
                targetReps: targetReps,
                targetWeightKg: targetWeightKg,
                targetDurationSeconds: targetDurationSeconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RoutineSetsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({routineExerciseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (routineExerciseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.routineExerciseId,
                        referencedTable: $$RoutineSetsTableTableReferences
                            ._routineExerciseIdTable(db),
                        referencedColumn: $$RoutineSetsTableTableReferences
                            ._routineExerciseIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RoutineSetsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutineSetsTableTable,
      RoutineSetRow,
      $$RoutineSetsTableTableFilterComposer,
      $$RoutineSetsTableTableOrderingComposer,
      $$RoutineSetsTableTableAnnotationComposer,
      $$RoutineSetsTableTableCreateCompanionBuilder,
      $$RoutineSetsTableTableUpdateCompanionBuilder,
      (RoutineSetRow, $$RoutineSetsTableTableReferences),
      RoutineSetRow,
      PrefetchHooks Function({bool routineExerciseId})
    >;
typedef $$WorkoutsTableTableCreateCompanionBuilder =
    WorkoutsTableCompanion Function({
      required String id,
      Value<String?> routineId,
      required String name,
      required int startedAt,
      Value<int?> endedAt,
      Value<String?> notes,
      Value<double> totalVolumeKg,
      Value<int> totalSets,
      Value<String?> perceivedEffort,
      Value<int> durationSeconds,
      Value<int> rowid,
    });
typedef $$WorkoutsTableTableUpdateCompanionBuilder =
    WorkoutsTableCompanion Function({
      Value<String> id,
      Value<String?> routineId,
      Value<String> name,
      Value<int> startedAt,
      Value<int?> endedAt,
      Value<String?> notes,
      Value<double> totalVolumeKg,
      Value<int> totalSets,
      Value<String?> perceivedEffort,
      Value<int> durationSeconds,
      Value<int> rowid,
    });

final class $$WorkoutsTableTableReferences
    extends BaseReferences<_$AppDatabase, $WorkoutsTableTable, WorkoutRow> {
  $$WorkoutsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RoutinesTableTable _routineIdTable(_$AppDatabase db) =>
      db.routinesTable.createAlias('workouts__routine_id__routines__id');

  $$RoutinesTableTableProcessedTableManager? get routineId {
    final $_column = $_itemColumn<String>('routine_id');
    if ($_column == null) return null;
    final manager = $$RoutinesTableTableTableManager(
      $_db,
      $_db.routinesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_routineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $WorkoutExercisesTableTable,
    List<WorkoutExerciseRow>
  >
  _workoutExercisesTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workoutExercisesTable,
        aliasName: 'workouts__id__workout_exercises__workout_id',
      );

  $$WorkoutExercisesTableTableProcessedTableManager
  get workoutExercisesTableRefs {
    final manager = $$WorkoutExercisesTableTableTableManager(
      $_db,
      $_db.workoutExercisesTable,
    ).filter((f) => f.workoutId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workoutExercisesTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutsTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutsTableTable> {
  $$WorkoutsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalVolumeKg => $composableBuilder(
    column: $table.totalVolumeKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalSets => $composableBuilder(
    column: $table.totalSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get perceivedEffort => $composableBuilder(
    column: $table.perceivedEffort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  $$RoutinesTableTableFilterComposer get routineId {
    final $$RoutinesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routinesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableTableFilterComposer(
            $db: $db,
            $table: $db.routinesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workoutExercisesTableRefs(
    Expression<bool> Function($$WorkoutExercisesTableTableFilterComposer f) f,
  ) {
    final $$WorkoutExercisesTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutExercisesTable,
          getReferencedColumn: (t) => t.workoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExercisesTableTableFilterComposer(
                $db: $db,
                $table: $db.workoutExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkoutsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutsTableTable> {
  $$WorkoutsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalVolumeKg => $composableBuilder(
    column: $table.totalVolumeKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalSets => $composableBuilder(
    column: $table.totalSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get perceivedEffort => $composableBuilder(
    column: $table.perceivedEffort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoutinesTableTableOrderingComposer get routineId {
    final $$RoutinesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routinesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableTableOrderingComposer(
            $db: $db,
            $table: $db.routinesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutsTableTable> {
  $$WorkoutsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<double> get totalVolumeKg => $composableBuilder(
    column: $table.totalVolumeKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalSets =>
      $composableBuilder(column: $table.totalSets, builder: (column) => column);

  GeneratedColumn<String> get perceivedEffort => $composableBuilder(
    column: $table.perceivedEffort,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  $$RoutinesTableTableAnnotationComposer get routineId {
    final $$RoutinesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routinesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.routinesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workoutExercisesTableRefs<T extends Object>(
    Expression<T> Function($$WorkoutExercisesTableTableAnnotationComposer a) f,
  ) {
    final $$WorkoutExercisesTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutExercisesTable,
          getReferencedColumn: (t) => t.workoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExercisesTableTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkoutsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutsTableTable,
          WorkoutRow,
          $$WorkoutsTableTableFilterComposer,
          $$WorkoutsTableTableOrderingComposer,
          $$WorkoutsTableTableAnnotationComposer,
          $$WorkoutsTableTableCreateCompanionBuilder,
          $$WorkoutsTableTableUpdateCompanionBuilder,
          (WorkoutRow, $$WorkoutsTableTableReferences),
          WorkoutRow,
          PrefetchHooks Function({
            bool routineId,
            bool workoutExercisesTableRefs,
          })
        > {
  $$WorkoutsTableTableTableManager(_$AppDatabase db, $WorkoutsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> routineId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int?> endedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double> totalVolumeKg = const Value.absent(),
                Value<int> totalSets = const Value.absent(),
                Value<String?> perceivedEffort = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutsTableCompanion(
                id: id,
                routineId: routineId,
                name: name,
                startedAt: startedAt,
                endedAt: endedAt,
                notes: notes,
                totalVolumeKg: totalVolumeKg,
                totalSets: totalSets,
                perceivedEffort: perceivedEffort,
                durationSeconds: durationSeconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> routineId = const Value.absent(),
                required String name,
                required int startedAt,
                Value<int?> endedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double> totalVolumeKg = const Value.absent(),
                Value<int> totalSets = const Value.absent(),
                Value<String?> perceivedEffort = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutsTableCompanion.insert(
                id: id,
                routineId: routineId,
                name: name,
                startedAt: startedAt,
                endedAt: endedAt,
                notes: notes,
                totalVolumeKg: totalVolumeKg,
                totalSets: totalSets,
                perceivedEffort: perceivedEffort,
                durationSeconds: durationSeconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({routineId = false, workoutExercisesTableRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workoutExercisesTableRefs) db.workoutExercisesTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (routineId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.routineId,
                            referencedTable: $$WorkoutsTableTableReferences
                                ._routineIdTable(db),
                            referencedColumn: $$WorkoutsTableTableReferences
                                ._routineIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workoutExercisesTableRefs)
                        await $_getPrefetchedData<
                          WorkoutRow,
                          $WorkoutsTableTable,
                          WorkoutExerciseRow
                        >(
                          currentTable: table,
                          referencedTable: $$WorkoutsTableTableReferences
                              ._workoutExercisesTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkoutsTableTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutExercisesTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workoutId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WorkoutsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutsTableTable,
      WorkoutRow,
      $$WorkoutsTableTableFilterComposer,
      $$WorkoutsTableTableOrderingComposer,
      $$WorkoutsTableTableAnnotationComposer,
      $$WorkoutsTableTableCreateCompanionBuilder,
      $$WorkoutsTableTableUpdateCompanionBuilder,
      (WorkoutRow, $$WorkoutsTableTableReferences),
      WorkoutRow,
      PrefetchHooks Function({bool routineId, bool workoutExercisesTableRefs})
    >;
typedef $$WorkoutExercisesTableTableCreateCompanionBuilder =
    WorkoutExercisesTableCompanion Function({
      required String id,
      required String workoutId,
      required String exerciseId,
      required int sortOrder,
      Value<int> restSeconds,
      Value<int?> supersetGroup,
      Value<String?> notes,
      Value<bool> isPrAttempt,
      Value<double?> prTargetWeightKg,
      Value<String?> prResult,
      Value<int> rowid,
    });
typedef $$WorkoutExercisesTableTableUpdateCompanionBuilder =
    WorkoutExercisesTableCompanion Function({
      Value<String> id,
      Value<String> workoutId,
      Value<String> exerciseId,
      Value<int> sortOrder,
      Value<int> restSeconds,
      Value<int?> supersetGroup,
      Value<String?> notes,
      Value<bool> isPrAttempt,
      Value<double?> prTargetWeightKg,
      Value<String?> prResult,
      Value<int> rowid,
    });

final class $$WorkoutExercisesTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorkoutExercisesTableTable,
          WorkoutExerciseRow
        > {
  $$WorkoutExercisesTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkoutsTableTable _workoutIdTable(_$AppDatabase db) => db
      .workoutsTable
      .createAlias('workout_exercises__workout_id__workouts__id');

  $$WorkoutsTableTableProcessedTableManager get workoutId {
    final $_column = $_itemColumn<String>('workout_id')!;

    final manager = $$WorkoutsTableTableTableManager(
      $_db,
      $_db.workoutsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExercisesTableTable _exerciseIdTable(_$AppDatabase db) => db
      .exercisesTable
      .createAlias('workout_exercises__exercise_id__exercises__id');

  $$ExercisesTableTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<String>('exercise_id')!;

    final manager = $$ExercisesTableTableTableManager(
      $_db,
      $_db.exercisesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WorkoutSetsTableTable, List<WorkoutSetRow>>
  _workoutSetsTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutSetsTable,
    aliasName: 'workout_exercises__id__workout_sets__workout_exercise_id',
  );

  $$WorkoutSetsTableTableProcessedTableManager get workoutSetsTableRefs {
    final manager =
        $$WorkoutSetsTableTableTableManager($_db, $_db.workoutSetsTable).filter(
          (f) => f.workoutExerciseId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _workoutSetsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutExercisesTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutExercisesTableTable> {
  $$WorkoutExercisesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get supersetGroup => $composableBuilder(
    column: $table.supersetGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrAttempt => $composableBuilder(
    column: $table.isPrAttempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get prTargetWeightKg => $composableBuilder(
    column: $table.prTargetWeightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prResult => $composableBuilder(
    column: $table.prResult,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutsTableTableFilterComposer get workoutId {
    final $$WorkoutsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableTableFilterComposer get exerciseId {
    final $$ExercisesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercisesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableTableFilterComposer(
            $db: $db,
            $table: $db.exercisesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workoutSetsTableRefs(
    Expression<bool> Function($$WorkoutSetsTableTableFilterComposer f) f,
  ) {
    final $$WorkoutSetsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSetsTable,
      getReferencedColumn: (t) => t.workoutExerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutSetsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutExercisesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutExercisesTableTable> {
  $$WorkoutExercisesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get supersetGroup => $composableBuilder(
    column: $table.supersetGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrAttempt => $composableBuilder(
    column: $table.isPrAttempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get prTargetWeightKg => $composableBuilder(
    column: $table.prTargetWeightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prResult => $composableBuilder(
    column: $table.prResult,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutsTableTableOrderingComposer get workoutId {
    final $$WorkoutsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableTableOrderingComposer(
            $db: $db,
            $table: $db.workoutsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableTableOrderingComposer get exerciseId {
    final $$ExercisesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercisesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableTableOrderingComposer(
            $db: $db,
            $table: $db.exercisesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutExercisesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutExercisesTableTable> {
  $$WorkoutExercisesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get supersetGroup => $composableBuilder(
    column: $table.supersetGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isPrAttempt => $composableBuilder(
    column: $table.isPrAttempt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get prTargetWeightKg => $composableBuilder(
    column: $table.prTargetWeightKg,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prResult =>
      $composableBuilder(column: $table.prResult, builder: (column) => column);

  $$WorkoutsTableTableAnnotationComposer get workoutId {
    final $$WorkoutsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableTableAnnotationComposer get exerciseId {
    final $$ExercisesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercisesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.exercisesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workoutSetsTableRefs<T extends Object>(
    Expression<T> Function($$WorkoutSetsTableTableAnnotationComposer a) f,
  ) {
    final $$WorkoutSetsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSetsTable,
      getReferencedColumn: (t) => t.workoutExerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSetsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutExercisesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutExercisesTableTable,
          WorkoutExerciseRow,
          $$WorkoutExercisesTableTableFilterComposer,
          $$WorkoutExercisesTableTableOrderingComposer,
          $$WorkoutExercisesTableTableAnnotationComposer,
          $$WorkoutExercisesTableTableCreateCompanionBuilder,
          $$WorkoutExercisesTableTableUpdateCompanionBuilder,
          (WorkoutExerciseRow, $$WorkoutExercisesTableTableReferences),
          WorkoutExerciseRow,
          PrefetchHooks Function({
            bool workoutId,
            bool exerciseId,
            bool workoutSetsTableRefs,
          })
        > {
  $$WorkoutExercisesTableTableTableManager(
    _$AppDatabase db,
    $WorkoutExercisesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutExercisesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$WorkoutExercisesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkoutExercisesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> workoutId = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> restSeconds = const Value.absent(),
                Value<int?> supersetGroup = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isPrAttempt = const Value.absent(),
                Value<double?> prTargetWeightKg = const Value.absent(),
                Value<String?> prResult = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutExercisesTableCompanion(
                id: id,
                workoutId: workoutId,
                exerciseId: exerciseId,
                sortOrder: sortOrder,
                restSeconds: restSeconds,
                supersetGroup: supersetGroup,
                notes: notes,
                isPrAttempt: isPrAttempt,
                prTargetWeightKg: prTargetWeightKg,
                prResult: prResult,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String workoutId,
                required String exerciseId,
                required int sortOrder,
                Value<int> restSeconds = const Value.absent(),
                Value<int?> supersetGroup = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isPrAttempt = const Value.absent(),
                Value<double?> prTargetWeightKg = const Value.absent(),
                Value<String?> prResult = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutExercisesTableCompanion.insert(
                id: id,
                workoutId: workoutId,
                exerciseId: exerciseId,
                sortOrder: sortOrder,
                restSeconds: restSeconds,
                supersetGroup: supersetGroup,
                notes: notes,
                isPrAttempt: isPrAttempt,
                prTargetWeightKg: prTargetWeightKg,
                prResult: prResult,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutExercisesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                workoutId = false,
                exerciseId = false,
                workoutSetsTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workoutSetsTableRefs) db.workoutSetsTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (workoutId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.workoutId,
                            referencedTable:
                                $$WorkoutExercisesTableTableReferences
                                    ._workoutIdTable(db),
                            referencedColumn:
                                $$WorkoutExercisesTableTableReferences
                                    ._workoutIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (exerciseId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.exerciseId,
                            referencedTable:
                                $$WorkoutExercisesTableTableReferences
                                    ._exerciseIdTable(db),
                            referencedColumn:
                                $$WorkoutExercisesTableTableReferences
                                    ._exerciseIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workoutSetsTableRefs)
                        await $_getPrefetchedData<
                          WorkoutExerciseRow,
                          $WorkoutExercisesTableTable,
                          WorkoutSetRow
                        >(
                          currentTable: table,
                          referencedTable:
                              $$WorkoutExercisesTableTableReferences
                                  ._workoutSetsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkoutExercisesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutSetsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workoutExerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WorkoutExercisesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutExercisesTableTable,
      WorkoutExerciseRow,
      $$WorkoutExercisesTableTableFilterComposer,
      $$WorkoutExercisesTableTableOrderingComposer,
      $$WorkoutExercisesTableTableAnnotationComposer,
      $$WorkoutExercisesTableTableCreateCompanionBuilder,
      $$WorkoutExercisesTableTableUpdateCompanionBuilder,
      (WorkoutExerciseRow, $$WorkoutExercisesTableTableReferences),
      WorkoutExerciseRow,
      PrefetchHooks Function({
        bool workoutId,
        bool exerciseId,
        bool workoutSetsTableRefs,
      })
    >;
typedef $$WorkoutSetsTableTableCreateCompanionBuilder =
    WorkoutSetsTableCompanion Function({
      required String id,
      required String workoutExerciseId,
      required int sortOrder,
      Value<String> setType,
      Value<double?> weightKg,
      Value<int?> reps,
      Value<int?> durationSeconds,
      Value<double?> distanceM,
      Value<double?> rpe,
      Value<bool> isCompleted,
      Value<int?> completedAt,
      Value<int> rowid,
    });
typedef $$WorkoutSetsTableTableUpdateCompanionBuilder =
    WorkoutSetsTableCompanion Function({
      Value<String> id,
      Value<String> workoutExerciseId,
      Value<int> sortOrder,
      Value<String> setType,
      Value<double?> weightKg,
      Value<int?> reps,
      Value<int?> durationSeconds,
      Value<double?> distanceM,
      Value<double?> rpe,
      Value<bool> isCompleted,
      Value<int?> completedAt,
      Value<int> rowid,
    });

final class $$WorkoutSetsTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $WorkoutSetsTableTable, WorkoutSetRow> {
  $$WorkoutSetsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkoutExercisesTableTable _workoutExerciseIdTable(
    _$AppDatabase db,
  ) => db.workoutExercisesTable.createAlias(
    'workout_sets__workout_exercise_id__workout_exercises__id',
  );

  $$WorkoutExercisesTableTableProcessedTableManager get workoutExerciseId {
    final $_column = $_itemColumn<String>('workout_exercise_id')!;

    final manager = $$WorkoutExercisesTableTableTableManager(
      $_db,
      $_db.workoutExercisesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutExerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $PersonalRecordsTableTable,
    List<PersonalRecordRow>
  >
  _personalRecordsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.personalRecordsTable,
        aliasName: 'workout_sets__id__personal_records__workout_set_id',
      );

  $$PersonalRecordsTableTableProcessedTableManager
  get personalRecordsTableRefs {
    final manager = $$PersonalRecordsTableTableTableManager(
      $_db,
      $_db.personalRecordsTable,
    ).filter((f) => f.workoutSetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _personalRecordsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutSetsTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTableTable> {
  $$WorkoutSetsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setType => $composableBuilder(
    column: $table.setType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutExercisesTableTableFilterComposer get workoutExerciseId {
    final $$WorkoutExercisesTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.workoutExerciseId,
          referencedTable: $db.workoutExercisesTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExercisesTableTableFilterComposer(
                $db: $db,
                $table: $db.workoutExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<bool> personalRecordsTableRefs(
    Expression<bool> Function($$PersonalRecordsTableTableFilterComposer f) f,
  ) {
    final $$PersonalRecordsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personalRecordsTable,
      getReferencedColumn: (t) => t.workoutSetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonalRecordsTableTableFilterComposer(
            $db: $db,
            $table: $db.personalRecordsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSetsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTableTable> {
  $$WorkoutSetsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setType => $composableBuilder(
    column: $table.setType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutExercisesTableTableOrderingComposer get workoutExerciseId {
    final $$WorkoutExercisesTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.workoutExerciseId,
          referencedTable: $db.workoutExercisesTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExercisesTableTableOrderingComposer(
                $db: $db,
                $table: $db.workoutExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$WorkoutSetsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTableTable> {
  $$WorkoutSetsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get setType =>
      $composableBuilder(column: $table.setType, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<double> get rpe =>
      $composableBuilder(column: $table.rpe, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$WorkoutExercisesTableTableAnnotationComposer get workoutExerciseId {
    final $$WorkoutExercisesTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.workoutExerciseId,
          referencedTable: $db.workoutExercisesTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExercisesTableTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutExercisesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> personalRecordsTableRefs<T extends Object>(
    Expression<T> Function($$PersonalRecordsTableTableAnnotationComposer a) f,
  ) {
    final $$PersonalRecordsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.personalRecordsTable,
          getReferencedColumn: (t) => t.workoutSetId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PersonalRecordsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.personalRecordsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkoutSetsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSetsTableTable,
          WorkoutSetRow,
          $$WorkoutSetsTableTableFilterComposer,
          $$WorkoutSetsTableTableOrderingComposer,
          $$WorkoutSetsTableTableAnnotationComposer,
          $$WorkoutSetsTableTableCreateCompanionBuilder,
          $$WorkoutSetsTableTableUpdateCompanionBuilder,
          (WorkoutSetRow, $$WorkoutSetsTableTableReferences),
          WorkoutSetRow,
          PrefetchHooks Function({
            bool workoutExerciseId,
            bool personalRecordsTableRefs,
          })
        > {
  $$WorkoutSetsTableTableTableManager(
    _$AppDatabase db,
    $WorkoutSetsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSetsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSetsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSetsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> workoutExerciseId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> setType = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<double?> distanceM = const Value.absent(),
                Value<double?> rpe = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSetsTableCompanion(
                id: id,
                workoutExerciseId: workoutExerciseId,
                sortOrder: sortOrder,
                setType: setType,
                weightKg: weightKg,
                reps: reps,
                durationSeconds: durationSeconds,
                distanceM: distanceM,
                rpe: rpe,
                isCompleted: isCompleted,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String workoutExerciseId,
                required int sortOrder,
                Value<String> setType = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<double?> distanceM = const Value.absent(),
                Value<double?> rpe = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSetsTableCompanion.insert(
                id: id,
                workoutExerciseId: workoutExerciseId,
                sortOrder: sortOrder,
                setType: setType,
                weightKg: weightKg,
                reps: reps,
                durationSeconds: durationSeconds,
                distanceM: distanceM,
                rpe: rpe,
                isCompleted: isCompleted,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutSetsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({workoutExerciseId = false, personalRecordsTableRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (personalRecordsTableRefs) db.personalRecordsTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (workoutExerciseId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.workoutExerciseId,
                            referencedTable: $$WorkoutSetsTableTableReferences
                                ._workoutExerciseIdTable(db),
                            referencedColumn: $$WorkoutSetsTableTableReferences
                                ._workoutExerciseIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (personalRecordsTableRefs)
                        await $_getPrefetchedData<
                          WorkoutSetRow,
                          $WorkoutSetsTableTable,
                          PersonalRecordRow
                        >(
                          currentTable: table,
                          referencedTable: $$WorkoutSetsTableTableReferences
                              ._personalRecordsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkoutSetsTableTableReferences(
                                db,
                                table,
                                p0,
                              ).personalRecordsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workoutSetId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WorkoutSetsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSetsTableTable,
      WorkoutSetRow,
      $$WorkoutSetsTableTableFilterComposer,
      $$WorkoutSetsTableTableOrderingComposer,
      $$WorkoutSetsTableTableAnnotationComposer,
      $$WorkoutSetsTableTableCreateCompanionBuilder,
      $$WorkoutSetsTableTableUpdateCompanionBuilder,
      (WorkoutSetRow, $$WorkoutSetsTableTableReferences),
      WorkoutSetRow,
      PrefetchHooks Function({
        bool workoutExerciseId,
        bool personalRecordsTableRefs,
      })
    >;
typedef $$PersonalRecordsTableTableCreateCompanionBuilder =
    PersonalRecordsTableCompanion Function({
      required String id,
      required String exerciseId,
      required String recordType,
      required double value,
      Value<String?> workoutSetId,
      required int achievedAt,
      Value<int> rowid,
    });
typedef $$PersonalRecordsTableTableUpdateCompanionBuilder =
    PersonalRecordsTableCompanion Function({
      Value<String> id,
      Value<String> exerciseId,
      Value<String> recordType,
      Value<double> value,
      Value<String?> workoutSetId,
      Value<int> achievedAt,
      Value<int> rowid,
    });

final class $$PersonalRecordsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PersonalRecordsTableTable,
          PersonalRecordRow
        > {
  $$PersonalRecordsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ExercisesTableTable _exerciseIdTable(_$AppDatabase db) => db
      .exercisesTable
      .createAlias('personal_records__exercise_id__exercises__id');

  $$ExercisesTableTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<String>('exercise_id')!;

    final manager = $$ExercisesTableTableTableManager(
      $_db,
      $_db.exercisesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkoutSetsTableTable _workoutSetIdTable(_$AppDatabase db) => db
      .workoutSetsTable
      .createAlias('personal_records__workout_set_id__workout_sets__id');

  $$WorkoutSetsTableTableProcessedTableManager? get workoutSetId {
    final $_column = $_itemColumn<String>('workout_set_id');
    if ($_column == null) return null;
    final manager = $$WorkoutSetsTableTableTableManager(
      $_db,
      $_db.workoutSetsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutSetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PersonalRecordsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PersonalRecordsTableTable> {
  $$PersonalRecordsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get achievedAt => $composableBuilder(
    column: $table.achievedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ExercisesTableTableFilterComposer get exerciseId {
    final $$ExercisesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercisesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableTableFilterComposer(
            $db: $db,
            $table: $db.exercisesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutSetsTableTableFilterComposer get workoutSetId {
    final $$WorkoutSetsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutSetId,
      referencedTable: $db.workoutSetsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutSetsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PersonalRecordsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonalRecordsTableTable> {
  $$PersonalRecordsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get achievedAt => $composableBuilder(
    column: $table.achievedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ExercisesTableTableOrderingComposer get exerciseId {
    final $$ExercisesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercisesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableTableOrderingComposer(
            $db: $db,
            $table: $db.exercisesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutSetsTableTableOrderingComposer get workoutSetId {
    final $$WorkoutSetsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutSetId,
      referencedTable: $db.workoutSetsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableTableOrderingComposer(
            $db: $db,
            $table: $db.workoutSetsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PersonalRecordsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonalRecordsTableTable> {
  $$PersonalRecordsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get achievedAt => $composableBuilder(
    column: $table.achievedAt,
    builder: (column) => column,
  );

  $$ExercisesTableTableAnnotationComposer get exerciseId {
    final $$ExercisesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercisesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.exercisesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutSetsTableTableAnnotationComposer get workoutSetId {
    final $$WorkoutSetsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutSetId,
      referencedTable: $db.workoutSetsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSetsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PersonalRecordsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonalRecordsTableTable,
          PersonalRecordRow,
          $$PersonalRecordsTableTableFilterComposer,
          $$PersonalRecordsTableTableOrderingComposer,
          $$PersonalRecordsTableTableAnnotationComposer,
          $$PersonalRecordsTableTableCreateCompanionBuilder,
          $$PersonalRecordsTableTableUpdateCompanionBuilder,
          (PersonalRecordRow, $$PersonalRecordsTableTableReferences),
          PersonalRecordRow,
          PrefetchHooks Function({bool exerciseId, bool workoutSetId})
        > {
  $$PersonalRecordsTableTableTableManager(
    _$AppDatabase db,
    $PersonalRecordsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonalRecordsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonalRecordsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PersonalRecordsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<String> recordType = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<String?> workoutSetId = const Value.absent(),
                Value<int> achievedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonalRecordsTableCompanion(
                id: id,
                exerciseId: exerciseId,
                recordType: recordType,
                value: value,
                workoutSetId: workoutSetId,
                achievedAt: achievedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String exerciseId,
                required String recordType,
                required double value,
                Value<String?> workoutSetId = const Value.absent(),
                required int achievedAt,
                Value<int> rowid = const Value.absent(),
              }) => PersonalRecordsTableCompanion.insert(
                id: id,
                exerciseId: exerciseId,
                recordType: recordType,
                value: value,
                workoutSetId: workoutSetId,
                achievedAt: achievedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PersonalRecordsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({exerciseId = false, workoutSetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (exerciseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.exerciseId,
                        referencedTable: $$PersonalRecordsTableTableReferences
                            ._exerciseIdTable(db),
                        referencedColumn: $$PersonalRecordsTableTableReferences
                            ._exerciseIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (workoutSetId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.workoutSetId,
                        referencedTable: $$PersonalRecordsTableTableReferences
                            ._workoutSetIdTable(db),
                        referencedColumn: $$PersonalRecordsTableTableReferences
                            ._workoutSetIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PersonalRecordsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonalRecordsTableTable,
      PersonalRecordRow,
      $$PersonalRecordsTableTableFilterComposer,
      $$PersonalRecordsTableTableOrderingComposer,
      $$PersonalRecordsTableTableAnnotationComposer,
      $$PersonalRecordsTableTableCreateCompanionBuilder,
      $$PersonalRecordsTableTableUpdateCompanionBuilder,
      (PersonalRecordRow, $$PersonalRecordsTableTableReferences),
      PersonalRecordRow,
      PrefetchHooks Function({bool exerciseId, bool workoutSetId})
    >;
typedef $$BodyMeasurementsTableTableCreateCompanionBuilder =
    BodyMeasurementsTableCompanion Function({
      required String id,
      required int measuredAt,
      required String type,
      required double value,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$BodyMeasurementsTableTableUpdateCompanionBuilder =
    BodyMeasurementsTableCompanion Function({
      Value<String> id,
      Value<int> measuredAt,
      Value<String> type,
      Value<double> value,
      Value<String?> note,
      Value<int> rowid,
    });

class $$BodyMeasurementsTableTableFilterComposer
    extends Composer<_$AppDatabase, $BodyMeasurementsTableTable> {
  $$BodyMeasurementsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BodyMeasurementsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BodyMeasurementsTableTable> {
  $$BodyMeasurementsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BodyMeasurementsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BodyMeasurementsTableTable> {
  $$BodyMeasurementsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$BodyMeasurementsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BodyMeasurementsTableTable,
          BodyMeasurementRow,
          $$BodyMeasurementsTableTableFilterComposer,
          $$BodyMeasurementsTableTableOrderingComposer,
          $$BodyMeasurementsTableTableAnnotationComposer,
          $$BodyMeasurementsTableTableCreateCompanionBuilder,
          $$BodyMeasurementsTableTableUpdateCompanionBuilder,
          (
            BodyMeasurementRow,
            BaseReferences<
              _$AppDatabase,
              $BodyMeasurementsTableTable,
              BodyMeasurementRow
            >,
          ),
          BodyMeasurementRow,
          PrefetchHooks Function()
        > {
  $$BodyMeasurementsTableTableTableManager(
    _$AppDatabase db,
    $BodyMeasurementsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BodyMeasurementsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$BodyMeasurementsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BodyMeasurementsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> measuredAt = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodyMeasurementsTableCompanion(
                id: id,
                measuredAt: measuredAt,
                type: type,
                value: value,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int measuredAt,
                required String type,
                required double value,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodyMeasurementsTableCompanion.insert(
                id: id,
                measuredAt: measuredAt,
                type: type,
                value: value,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BodyMeasurementsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BodyMeasurementsTableTable,
      BodyMeasurementRow,
      $$BodyMeasurementsTableTableFilterComposer,
      $$BodyMeasurementsTableTableOrderingComposer,
      $$BodyMeasurementsTableTableAnnotationComposer,
      $$BodyMeasurementsTableTableCreateCompanionBuilder,
      $$BodyMeasurementsTableTableUpdateCompanionBuilder,
      (
        BodyMeasurementRow,
        BaseReferences<
          _$AppDatabase,
          $BodyMeasurementsTableTable,
          BodyMeasurementRow
        >,
      ),
      BodyMeasurementRow,
      PrefetchHooks Function()
    >;
typedef $$ProgressPhotosTableTableCreateCompanionBuilder =
    ProgressPhotosTableCompanion Function({
      required String id,
      required int takenAt,
      required String fileName,
      required String pose,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$ProgressPhotosTableTableUpdateCompanionBuilder =
    ProgressPhotosTableCompanion Function({
      Value<String> id,
      Value<int> takenAt,
      Value<String> fileName,
      Value<String> pose,
      Value<String?> note,
      Value<int> rowid,
    });

class $$ProgressPhotosTableTableFilterComposer
    extends Composer<_$AppDatabase, $ProgressPhotosTableTable> {
  $$ProgressPhotosTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pose => $composableBuilder(
    column: $table.pose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgressPhotosTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgressPhotosTableTable> {
  $$ProgressPhotosTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pose => $composableBuilder(
    column: $table.pose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgressPhotosTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgressPhotosTableTable> {
  $$ProgressPhotosTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get pose =>
      $composableBuilder(column: $table.pose, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$ProgressPhotosTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgressPhotosTableTable,
          ProgressPhotoRow,
          $$ProgressPhotosTableTableFilterComposer,
          $$ProgressPhotosTableTableOrderingComposer,
          $$ProgressPhotosTableTableAnnotationComposer,
          $$ProgressPhotosTableTableCreateCompanionBuilder,
          $$ProgressPhotosTableTableUpdateCompanionBuilder,
          (
            ProgressPhotoRow,
            BaseReferences<
              _$AppDatabase,
              $ProgressPhotosTableTable,
              ProgressPhotoRow
            >,
          ),
          ProgressPhotoRow,
          PrefetchHooks Function()
        > {
  $$ProgressPhotosTableTableTableManager(
    _$AppDatabase db,
    $ProgressPhotosTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressPhotosTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressPhotosTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ProgressPhotosTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> takenAt = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> pose = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressPhotosTableCompanion(
                id: id,
                takenAt: takenAt,
                fileName: fileName,
                pose: pose,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int takenAt,
                required String fileName,
                required String pose,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressPhotosTableCompanion.insert(
                id: id,
                takenAt: takenAt,
                fileName: fileName,
                pose: pose,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressPhotosTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgressPhotosTableTable,
      ProgressPhotoRow,
      $$ProgressPhotosTableTableFilterComposer,
      $$ProgressPhotosTableTableOrderingComposer,
      $$ProgressPhotosTableTableAnnotationComposer,
      $$ProgressPhotosTableTableCreateCompanionBuilder,
      $$ProgressPhotosTableTableUpdateCompanionBuilder,
      (
        ProgressPhotoRow,
        BaseReferences<
          _$AppDatabase,
          $ProgressPhotosTableTable,
          ProgressPhotoRow
        >,
      ),
      ProgressPhotoRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfileTableTableTableManager get userProfileTable =>
      $$UserProfileTableTableTableManager(_db, _db.userProfileTable);
  $$AppSettingsTableTableTableManager get appSettingsTable =>
      $$AppSettingsTableTableTableManager(_db, _db.appSettingsTable);
  $$ExercisesTableTableTableManager get exercisesTable =>
      $$ExercisesTableTableTableManager(_db, _db.exercisesTable);
  $$RoutineFoldersTableTableTableManager get routineFoldersTable =>
      $$RoutineFoldersTableTableTableManager(_db, _db.routineFoldersTable);
  $$RoutinesTableTableTableManager get routinesTable =>
      $$RoutinesTableTableTableManager(_db, _db.routinesTable);
  $$RoutineExercisesTableTableTableManager get routineExercisesTable =>
      $$RoutineExercisesTableTableTableManager(_db, _db.routineExercisesTable);
  $$RoutineSetsTableTableTableManager get routineSetsTable =>
      $$RoutineSetsTableTableTableManager(_db, _db.routineSetsTable);
  $$WorkoutsTableTableTableManager get workoutsTable =>
      $$WorkoutsTableTableTableManager(_db, _db.workoutsTable);
  $$WorkoutExercisesTableTableTableManager get workoutExercisesTable =>
      $$WorkoutExercisesTableTableTableManager(_db, _db.workoutExercisesTable);
  $$WorkoutSetsTableTableTableManager get workoutSetsTable =>
      $$WorkoutSetsTableTableTableManager(_db, _db.workoutSetsTable);
  $$PersonalRecordsTableTableTableManager get personalRecordsTable =>
      $$PersonalRecordsTableTableTableManager(_db, _db.personalRecordsTable);
  $$BodyMeasurementsTableTableTableManager get bodyMeasurementsTable =>
      $$BodyMeasurementsTableTableTableManager(_db, _db.bodyMeasurementsTable);
  $$ProgressPhotosTableTableTableManager get progressPhotosTable =>
      $$ProgressPhotosTableTableTableManager(_db, _db.progressPhotosTable);
}
