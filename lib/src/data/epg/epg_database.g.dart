// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_database.dart';

// ignore_for_file: type=lint
class $EpgChannelsTable extends EpgChannels
    with TableInfo<$EpgChannelsTable, EpgChannel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceBackendMeta = const VerificationMeta(
    'sourceBackend',
  );
  @override
  late final GeneratedColumn<String> sourceBackend = GeneratedColumn<String>(
    'source_backend',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _networkIdMeta = const VerificationMeta(
    'networkId',
  );
  @override
  late final GeneratedColumn<int> networkId = GeneratedColumn<int>(
    'network_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serviceIdMeta = const VerificationMeta(
    'serviceId',
  );
  @override
  late final GeneratedColumn<int> serviceId = GeneratedColumn<int>(
    'service_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
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
  static const VerificationMeta _channelTypeMeta = const VerificationMeta(
    'channelType',
  );
  @override
  late final GeneratedColumn<String> channelType = GeneratedColumn<String>(
    'channel_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelNumberMeta = const VerificationMeta(
    'channelNumber',
  );
  @override
  late final GeneratedColumn<String> channelNumber = GeneratedColumn<String>(
    'channel_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tunerChannelMeta = const VerificationMeta(
    'tunerChannel',
  );
  @override
  late final GeneratedColumn<String> tunerChannel = GeneratedColumn<String>(
    'tuner_channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _hasLogoMeta = const VerificationMeta(
    'hasLogo',
  );
  @override
  late final GeneratedColumn<bool> hasLogo = GeneratedColumn<bool>(
    'has_logo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_logo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  List<GeneratedColumn> get $columns => [
    sourceBackend,
    networkId,
    serviceId,
    remoteId,
    name,
    channelType,
    channelNumber,
    tunerChannel,
    hasLogo,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgChannel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_backend')) {
      context.handle(
        _sourceBackendMeta,
        sourceBackend.isAcceptableOrUnknown(
          data['source_backend']!,
          _sourceBackendMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceBackendMeta);
    }
    if (data.containsKey('network_id')) {
      context.handle(
        _networkIdMeta,
        networkId.isAcceptableOrUnknown(data['network_id']!, _networkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_networkIdMeta);
    }
    if (data.containsKey('service_id')) {
      context.handle(
        _serviceIdMeta,
        serviceId.isAcceptableOrUnknown(data['service_id']!, _serviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serviceIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('channel_type')) {
      context.handle(
        _channelTypeMeta,
        channelType.isAcceptableOrUnknown(
          data['channel_type']!,
          _channelTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_channelTypeMeta);
    }
    if (data.containsKey('channel_number')) {
      context.handle(
        _channelNumberMeta,
        channelNumber.isAcceptableOrUnknown(
          data['channel_number']!,
          _channelNumberMeta,
        ),
      );
    }
    if (data.containsKey('tuner_channel')) {
      context.handle(
        _tunerChannelMeta,
        tunerChannel.isAcceptableOrUnknown(
          data['tuner_channel']!,
          _tunerChannelMeta,
        ),
      );
    }
    if (data.containsKey('has_logo')) {
      context.handle(
        _hasLogoMeta,
        hasLogo.isAcceptableOrUnknown(data['has_logo']!, _hasLogoMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceBackend, networkId, serviceId};
  @override
  EpgChannel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgChannel(
      sourceBackend: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_backend'],
      )!,
      networkId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}network_id'],
      )!,
      serviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}service_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      channelType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_type'],
      )!,
      channelNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_number'],
      )!,
      tunerChannel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tuner_channel'],
      )!,
      hasLogo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_logo'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $EpgChannelsTable createAlias(String alias) {
    return $EpgChannelsTable(attachedDatabase, alias);
  }
}

class EpgChannel extends DataClass implements Insertable<EpgChannel> {
  /// 取得元バックエンド (`BackendType.name`)。
  final String sourceBackend;

  /// MPEG-TS の network_id。
  final int networkId;

  /// MPEG-TS の service_id。
  final int serviceId;

  /// バックエンド固有の再生用ID。Mirakurun は `service.id` の文字列表現
  /// (現行 `Channel.id` と同一)。
  final String remoteId;

  /// 表示名 (`formatProgramText` 済み)。
  final String name;

  /// チャンネル種別 (`GR`/`BS`/`CS`/`SKY` 等)。
  final String channelType;

  /// ヘッダー表示用のチャンネル番号 (例: `011`)。なければ空文字。
  final String channelNumber;

  /// チューナーの物理チャンネル文字。サブチャンネル重複排除キー用。
  /// Mirakurun `service.channel.channel`、なければ空文字。
  final String tunerChannel;

  /// ロゴデータの有無 (`hasLogoData == true` か)。
  final bool hasLogo;

  /// 取得APIの応答順 (0始まり)。出力順の維持用でソートしない。
  final int sortOrder;
  const EpgChannel({
    required this.sourceBackend,
    required this.networkId,
    required this.serviceId,
    required this.remoteId,
    required this.name,
    required this.channelType,
    required this.channelNumber,
    required this.tunerChannel,
    required this.hasLogo,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_backend'] = Variable<String>(sourceBackend);
    map['network_id'] = Variable<int>(networkId);
    map['service_id'] = Variable<int>(serviceId);
    map['remote_id'] = Variable<String>(remoteId);
    map['name'] = Variable<String>(name);
    map['channel_type'] = Variable<String>(channelType);
    map['channel_number'] = Variable<String>(channelNumber);
    map['tuner_channel'] = Variable<String>(tunerChannel);
    map['has_logo'] = Variable<bool>(hasLogo);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  EpgChannelsCompanion toCompanion(bool nullToAbsent) {
    return EpgChannelsCompanion(
      sourceBackend: Value(sourceBackend),
      networkId: Value(networkId),
      serviceId: Value(serviceId),
      remoteId: Value(remoteId),
      name: Value(name),
      channelType: Value(channelType),
      channelNumber: Value(channelNumber),
      tunerChannel: Value(tunerChannel),
      hasLogo: Value(hasLogo),
      sortOrder: Value(sortOrder),
    );
  }

  factory EpgChannel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgChannel(
      sourceBackend: serializer.fromJson<String>(json['sourceBackend']),
      networkId: serializer.fromJson<int>(json['networkId']),
      serviceId: serializer.fromJson<int>(json['serviceId']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      name: serializer.fromJson<String>(json['name']),
      channelType: serializer.fromJson<String>(json['channelType']),
      channelNumber: serializer.fromJson<String>(json['channelNumber']),
      tunerChannel: serializer.fromJson<String>(json['tunerChannel']),
      hasLogo: serializer.fromJson<bool>(json['hasLogo']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceBackend': serializer.toJson<String>(sourceBackend),
      'networkId': serializer.toJson<int>(networkId),
      'serviceId': serializer.toJson<int>(serviceId),
      'remoteId': serializer.toJson<String>(remoteId),
      'name': serializer.toJson<String>(name),
      'channelType': serializer.toJson<String>(channelType),
      'channelNumber': serializer.toJson<String>(channelNumber),
      'tunerChannel': serializer.toJson<String>(tunerChannel),
      'hasLogo': serializer.toJson<bool>(hasLogo),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  EpgChannel copyWith({
    String? sourceBackend,
    int? networkId,
    int? serviceId,
    String? remoteId,
    String? name,
    String? channelType,
    String? channelNumber,
    String? tunerChannel,
    bool? hasLogo,
    int? sortOrder,
  }) => EpgChannel(
    sourceBackend: sourceBackend ?? this.sourceBackend,
    networkId: networkId ?? this.networkId,
    serviceId: serviceId ?? this.serviceId,
    remoteId: remoteId ?? this.remoteId,
    name: name ?? this.name,
    channelType: channelType ?? this.channelType,
    channelNumber: channelNumber ?? this.channelNumber,
    tunerChannel: tunerChannel ?? this.tunerChannel,
    hasLogo: hasLogo ?? this.hasLogo,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  EpgChannel copyWithCompanion(EpgChannelsCompanion data) {
    return EpgChannel(
      sourceBackend: data.sourceBackend.present
          ? data.sourceBackend.value
          : this.sourceBackend,
      networkId: data.networkId.present ? data.networkId.value : this.networkId,
      serviceId: data.serviceId.present ? data.serviceId.value : this.serviceId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      name: data.name.present ? data.name.value : this.name,
      channelType: data.channelType.present
          ? data.channelType.value
          : this.channelType,
      channelNumber: data.channelNumber.present
          ? data.channelNumber.value
          : this.channelNumber,
      tunerChannel: data.tunerChannel.present
          ? data.tunerChannel.value
          : this.tunerChannel,
      hasLogo: data.hasLogo.present ? data.hasLogo.value : this.hasLogo,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannel(')
          ..write('sourceBackend: $sourceBackend, ')
          ..write('networkId: $networkId, ')
          ..write('serviceId: $serviceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('channelType: $channelType, ')
          ..write('channelNumber: $channelNumber, ')
          ..write('tunerChannel: $tunerChannel, ')
          ..write('hasLogo: $hasLogo, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceBackend,
    networkId,
    serviceId,
    remoteId,
    name,
    channelType,
    channelNumber,
    tunerChannel,
    hasLogo,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgChannel &&
          other.sourceBackend == this.sourceBackend &&
          other.networkId == this.networkId &&
          other.serviceId == this.serviceId &&
          other.remoteId == this.remoteId &&
          other.name == this.name &&
          other.channelType == this.channelType &&
          other.channelNumber == this.channelNumber &&
          other.tunerChannel == this.tunerChannel &&
          other.hasLogo == this.hasLogo &&
          other.sortOrder == this.sortOrder);
}

class EpgChannelsCompanion extends UpdateCompanion<EpgChannel> {
  final Value<String> sourceBackend;
  final Value<int> networkId;
  final Value<int> serviceId;
  final Value<String> remoteId;
  final Value<String> name;
  final Value<String> channelType;
  final Value<String> channelNumber;
  final Value<String> tunerChannel;
  final Value<bool> hasLogo;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const EpgChannelsCompanion({
    this.sourceBackend = const Value.absent(),
    this.networkId = const Value.absent(),
    this.serviceId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.name = const Value.absent(),
    this.channelType = const Value.absent(),
    this.channelNumber = const Value.absent(),
    this.tunerChannel = const Value.absent(),
    this.hasLogo = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgChannelsCompanion.insert({
    required String sourceBackend,
    required int networkId,
    required int serviceId,
    required String remoteId,
    required String name,
    required String channelType,
    this.channelNumber = const Value.absent(),
    this.tunerChannel = const Value.absent(),
    this.hasLogo = const Value.absent(),
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : sourceBackend = Value(sourceBackend),
       networkId = Value(networkId),
       serviceId = Value(serviceId),
       remoteId = Value(remoteId),
       name = Value(name),
       channelType = Value(channelType),
       sortOrder = Value(sortOrder);
  static Insertable<EpgChannel> custom({
    Expression<String>? sourceBackend,
    Expression<int>? networkId,
    Expression<int>? serviceId,
    Expression<String>? remoteId,
    Expression<String>? name,
    Expression<String>? channelType,
    Expression<String>? channelNumber,
    Expression<String>? tunerChannel,
    Expression<bool>? hasLogo,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceBackend != null) 'source_backend': sourceBackend,
      if (networkId != null) 'network_id': networkId,
      if (serviceId != null) 'service_id': serviceId,
      if (remoteId != null) 'remote_id': remoteId,
      if (name != null) 'name': name,
      if (channelType != null) 'channel_type': channelType,
      if (channelNumber != null) 'channel_number': channelNumber,
      if (tunerChannel != null) 'tuner_channel': tunerChannel,
      if (hasLogo != null) 'has_logo': hasLogo,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgChannelsCompanion copyWith({
    Value<String>? sourceBackend,
    Value<int>? networkId,
    Value<int>? serviceId,
    Value<String>? remoteId,
    Value<String>? name,
    Value<String>? channelType,
    Value<String>? channelNumber,
    Value<String>? tunerChannel,
    Value<bool>? hasLogo,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return EpgChannelsCompanion(
      sourceBackend: sourceBackend ?? this.sourceBackend,
      networkId: networkId ?? this.networkId,
      serviceId: serviceId ?? this.serviceId,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      channelType: channelType ?? this.channelType,
      channelNumber: channelNumber ?? this.channelNumber,
      tunerChannel: tunerChannel ?? this.tunerChannel,
      hasLogo: hasLogo ?? this.hasLogo,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceBackend.present) {
      map['source_backend'] = Variable<String>(sourceBackend.value);
    }
    if (networkId.present) {
      map['network_id'] = Variable<int>(networkId.value);
    }
    if (serviceId.present) {
      map['service_id'] = Variable<int>(serviceId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (channelType.present) {
      map['channel_type'] = Variable<String>(channelType.value);
    }
    if (channelNumber.present) {
      map['channel_number'] = Variable<String>(channelNumber.value);
    }
    if (tunerChannel.present) {
      map['tuner_channel'] = Variable<String>(tunerChannel.value);
    }
    if (hasLogo.present) {
      map['has_logo'] = Variable<bool>(hasLogo.value);
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
    return (StringBuffer('EpgChannelsCompanion(')
          ..write('sourceBackend: $sourceBackend, ')
          ..write('networkId: $networkId, ')
          ..write('serviceId: $serviceId, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('channelType: $channelType, ')
          ..write('channelNumber: $channelNumber, ')
          ..write('tunerChannel: $tunerChannel, ')
          ..write('hasLogo: $hasLogo, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgProgramsTable extends EpgPrograms
    with TableInfo<$EpgProgramsTable, EpgProgram> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgProgramsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceBackendMeta = const VerificationMeta(
    'sourceBackend',
  );
  @override
  late final GeneratedColumn<String> sourceBackend = GeneratedColumn<String>(
    'source_backend',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _networkIdMeta = const VerificationMeta(
    'networkId',
  );
  @override
  late final GeneratedColumn<int> networkId = GeneratedColumn<int>(
    'network_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serviceIdMeta = const VerificationMeta(
    'serviceId',
  );
  @override
  late final GeneratedColumn<int> serviceId = GeneratedColumn<int>(
    'service_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startAtMsMeta = const VerificationMeta(
    'startAtMs',
  );
  @override
  late final GeneratedColumn<int> startAtMs = GeneratedColumn<int>(
    'start_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMsMeta = const VerificationMeta(
    'endAtMs',
  );
  @override
  late final GeneratedColumn<int> endAtMs = GeneratedColumn<int>(
    'end_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _genresJsonMeta = const VerificationMeta(
    'genresJson',
  );
  @override
  late final GeneratedColumn<String> genresJson = GeneratedColumn<String>(
    'genres_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _detailJsonMeta = const VerificationMeta(
    'detailJson',
  );
  @override
  late final GeneratedColumn<String> detailJson = GeneratedColumn<String>(
    'detail_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceBackend,
    networkId,
    serviceId,
    eventId,
    startAtMs,
    endAtMs,
    title,
    description,
    genresJson,
    detailJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_programs';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgProgram> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_backend')) {
      context.handle(
        _sourceBackendMeta,
        sourceBackend.isAcceptableOrUnknown(
          data['source_backend']!,
          _sourceBackendMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceBackendMeta);
    }
    if (data.containsKey('network_id')) {
      context.handle(
        _networkIdMeta,
        networkId.isAcceptableOrUnknown(data['network_id']!, _networkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_networkIdMeta);
    }
    if (data.containsKey('service_id')) {
      context.handle(
        _serviceIdMeta,
        serviceId.isAcceptableOrUnknown(data['service_id']!, _serviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serviceIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('start_at_ms')) {
      context.handle(
        _startAtMsMeta,
        startAtMs.isAcceptableOrUnknown(data['start_at_ms']!, _startAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMsMeta);
    }
    if (data.containsKey('end_at_ms')) {
      context.handle(
        _endAtMsMeta,
        endAtMs.isAcceptableOrUnknown(data['end_at_ms']!, _endAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMsMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('genres_json')) {
      context.handle(
        _genresJsonMeta,
        genresJson.isAcceptableOrUnknown(data['genres_json']!, _genresJsonMeta),
      );
    }
    if (data.containsKey('detail_json')) {
      context.handle(
        _detailJsonMeta,
        detailJson.isAcceptableOrUnknown(data['detail_json']!, _detailJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    sourceBackend,
    networkId,
    serviceId,
    eventId,
  };
  @override
  EpgProgram map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgProgram(
      sourceBackend: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_backend'],
      )!,
      networkId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}network_id'],
      )!,
      serviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}service_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      )!,
      startAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_at_ms'],
      )!,
      endAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_at_ms'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      genresJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genres_json'],
      )!,
      detailJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail_json'],
      )!,
    );
  }

  @override
  $EpgProgramsTable createAlias(String alias) {
    return $EpgProgramsTable(attachedDatabase, alias);
  }
}

class EpgProgram extends DataClass implements Insertable<EpgProgram> {
  /// 取得元バックエンド (`BackendType.name`)。
  final String sourceBackend;

  /// MPEG-TS の network_id。
  final int networkId;

  /// MPEG-TS の service_id。
  final int serviceId;

  /// MPEG-TS の event_id。
  final int eventId;

  /// 開始時刻 (ms epoch)。
  final int startAtMs;

  /// 終了時刻 (ms epoch。書込時に `startAt + duration` で計算)。
  final int endAtMs;

  /// 番組名 (`formatProgramText` 済み)。
  final String title;

  /// 番組概要 (`formatProgramText` 済み)。なければ空文字。
  final String description;

  /// 表示用ジャンルラベル配列のJSON。既定 `'[]'`。
  final String genresJson;

  /// 番組詳細 (キー→説明文) のJSON。既定 `'{}'`。
  final String detailJson;
  const EpgProgram({
    required this.sourceBackend,
    required this.networkId,
    required this.serviceId,
    required this.eventId,
    required this.startAtMs,
    required this.endAtMs,
    required this.title,
    required this.description,
    required this.genresJson,
    required this.detailJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_backend'] = Variable<String>(sourceBackend);
    map['network_id'] = Variable<int>(networkId);
    map['service_id'] = Variable<int>(serviceId);
    map['event_id'] = Variable<int>(eventId);
    map['start_at_ms'] = Variable<int>(startAtMs);
    map['end_at_ms'] = Variable<int>(endAtMs);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['genres_json'] = Variable<String>(genresJson);
    map['detail_json'] = Variable<String>(detailJson);
    return map;
  }

  EpgProgramsCompanion toCompanion(bool nullToAbsent) {
    return EpgProgramsCompanion(
      sourceBackend: Value(sourceBackend),
      networkId: Value(networkId),
      serviceId: Value(serviceId),
      eventId: Value(eventId),
      startAtMs: Value(startAtMs),
      endAtMs: Value(endAtMs),
      title: Value(title),
      description: Value(description),
      genresJson: Value(genresJson),
      detailJson: Value(detailJson),
    );
  }

  factory EpgProgram.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgProgram(
      sourceBackend: serializer.fromJson<String>(json['sourceBackend']),
      networkId: serializer.fromJson<int>(json['networkId']),
      serviceId: serializer.fromJson<int>(json['serviceId']),
      eventId: serializer.fromJson<int>(json['eventId']),
      startAtMs: serializer.fromJson<int>(json['startAtMs']),
      endAtMs: serializer.fromJson<int>(json['endAtMs']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      genresJson: serializer.fromJson<String>(json['genresJson']),
      detailJson: serializer.fromJson<String>(json['detailJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceBackend': serializer.toJson<String>(sourceBackend),
      'networkId': serializer.toJson<int>(networkId),
      'serviceId': serializer.toJson<int>(serviceId),
      'eventId': serializer.toJson<int>(eventId),
      'startAtMs': serializer.toJson<int>(startAtMs),
      'endAtMs': serializer.toJson<int>(endAtMs),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'genresJson': serializer.toJson<String>(genresJson),
      'detailJson': serializer.toJson<String>(detailJson),
    };
  }

  EpgProgram copyWith({
    String? sourceBackend,
    int? networkId,
    int? serviceId,
    int? eventId,
    int? startAtMs,
    int? endAtMs,
    String? title,
    String? description,
    String? genresJson,
    String? detailJson,
  }) => EpgProgram(
    sourceBackend: sourceBackend ?? this.sourceBackend,
    networkId: networkId ?? this.networkId,
    serviceId: serviceId ?? this.serviceId,
    eventId: eventId ?? this.eventId,
    startAtMs: startAtMs ?? this.startAtMs,
    endAtMs: endAtMs ?? this.endAtMs,
    title: title ?? this.title,
    description: description ?? this.description,
    genresJson: genresJson ?? this.genresJson,
    detailJson: detailJson ?? this.detailJson,
  );
  EpgProgram copyWithCompanion(EpgProgramsCompanion data) {
    return EpgProgram(
      sourceBackend: data.sourceBackend.present
          ? data.sourceBackend.value
          : this.sourceBackend,
      networkId: data.networkId.present ? data.networkId.value : this.networkId,
      serviceId: data.serviceId.present ? data.serviceId.value : this.serviceId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      startAtMs: data.startAtMs.present ? data.startAtMs.value : this.startAtMs,
      endAtMs: data.endAtMs.present ? data.endAtMs.value : this.endAtMs,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      genresJson: data.genresJson.present
          ? data.genresJson.value
          : this.genresJson,
      detailJson: data.detailJson.present
          ? data.detailJson.value
          : this.detailJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgram(')
          ..write('sourceBackend: $sourceBackend, ')
          ..write('networkId: $networkId, ')
          ..write('serviceId: $serviceId, ')
          ..write('eventId: $eventId, ')
          ..write('startAtMs: $startAtMs, ')
          ..write('endAtMs: $endAtMs, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('genresJson: $genresJson, ')
          ..write('detailJson: $detailJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceBackend,
    networkId,
    serviceId,
    eventId,
    startAtMs,
    endAtMs,
    title,
    description,
    genresJson,
    detailJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgProgram &&
          other.sourceBackend == this.sourceBackend &&
          other.networkId == this.networkId &&
          other.serviceId == this.serviceId &&
          other.eventId == this.eventId &&
          other.startAtMs == this.startAtMs &&
          other.endAtMs == this.endAtMs &&
          other.title == this.title &&
          other.description == this.description &&
          other.genresJson == this.genresJson &&
          other.detailJson == this.detailJson);
}

class EpgProgramsCompanion extends UpdateCompanion<EpgProgram> {
  final Value<String> sourceBackend;
  final Value<int> networkId;
  final Value<int> serviceId;
  final Value<int> eventId;
  final Value<int> startAtMs;
  final Value<int> endAtMs;
  final Value<String> title;
  final Value<String> description;
  final Value<String> genresJson;
  final Value<String> detailJson;
  final Value<int> rowid;
  const EpgProgramsCompanion({
    this.sourceBackend = const Value.absent(),
    this.networkId = const Value.absent(),
    this.serviceId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.startAtMs = const Value.absent(),
    this.endAtMs = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.detailJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgProgramsCompanion.insert({
    required String sourceBackend,
    required int networkId,
    required int serviceId,
    required int eventId,
    required int startAtMs,
    required int endAtMs,
    required String title,
    this.description = const Value.absent(),
    this.genresJson = const Value.absent(),
    this.detailJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceBackend = Value(sourceBackend),
       networkId = Value(networkId),
       serviceId = Value(serviceId),
       eventId = Value(eventId),
       startAtMs = Value(startAtMs),
       endAtMs = Value(endAtMs),
       title = Value(title);
  static Insertable<EpgProgram> custom({
    Expression<String>? sourceBackend,
    Expression<int>? networkId,
    Expression<int>? serviceId,
    Expression<int>? eventId,
    Expression<int>? startAtMs,
    Expression<int>? endAtMs,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? genresJson,
    Expression<String>? detailJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceBackend != null) 'source_backend': sourceBackend,
      if (networkId != null) 'network_id': networkId,
      if (serviceId != null) 'service_id': serviceId,
      if (eventId != null) 'event_id': eventId,
      if (startAtMs != null) 'start_at_ms': startAtMs,
      if (endAtMs != null) 'end_at_ms': endAtMs,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (genresJson != null) 'genres_json': genresJson,
      if (detailJson != null) 'detail_json': detailJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgProgramsCompanion copyWith({
    Value<String>? sourceBackend,
    Value<int>? networkId,
    Value<int>? serviceId,
    Value<int>? eventId,
    Value<int>? startAtMs,
    Value<int>? endAtMs,
    Value<String>? title,
    Value<String>? description,
    Value<String>? genresJson,
    Value<String>? detailJson,
    Value<int>? rowid,
  }) {
    return EpgProgramsCompanion(
      sourceBackend: sourceBackend ?? this.sourceBackend,
      networkId: networkId ?? this.networkId,
      serviceId: serviceId ?? this.serviceId,
      eventId: eventId ?? this.eventId,
      startAtMs: startAtMs ?? this.startAtMs,
      endAtMs: endAtMs ?? this.endAtMs,
      title: title ?? this.title,
      description: description ?? this.description,
      genresJson: genresJson ?? this.genresJson,
      detailJson: detailJson ?? this.detailJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceBackend.present) {
      map['source_backend'] = Variable<String>(sourceBackend.value);
    }
    if (networkId.present) {
      map['network_id'] = Variable<int>(networkId.value);
    }
    if (serviceId.present) {
      map['service_id'] = Variable<int>(serviceId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (startAtMs.present) {
      map['start_at_ms'] = Variable<int>(startAtMs.value);
    }
    if (endAtMs.present) {
      map['end_at_ms'] = Variable<int>(endAtMs.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (genresJson.present) {
      map['genres_json'] = Variable<String>(genresJson.value);
    }
    if (detailJson.present) {
      map['detail_json'] = Variable<String>(detailJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgramsCompanion(')
          ..write('sourceBackend: $sourceBackend, ')
          ..write('networkId: $networkId, ')
          ..write('serviceId: $serviceId, ')
          ..write('eventId: $eventId, ')
          ..write('startAtMs: $startAtMs, ')
          ..write('endAtMs: $endAtMs, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('genresJson: $genresJson, ')
          ..write('detailJson: $detailJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgSyncMetaTable extends EpgSyncMeta
    with TableInfo<$EpgSyncMetaTable, EpgSyncMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgSyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceBackendMeta = const VerificationMeta(
    'sourceBackend',
  );
  @override
  late final GeneratedColumn<String> sourceBackend = GeneratedColumn<String>(
    'source_backend',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMsMeta = const VerificationMeta(
    'fetchedAtMs',
  );
  @override
  late final GeneratedColumn<int> fetchedAtMs = GeneratedColumn<int>(
    'fetched_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelCountMeta = const VerificationMeta(
    'channelCount',
  );
  @override
  late final GeneratedColumn<int> channelCount = GeneratedColumn<int>(
    'channel_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programCountMeta = const VerificationMeta(
    'programCount',
  );
  @override
  late final GeneratedColumn<int> programCount = GeneratedColumn<int>(
    'program_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceBackend,
    baseUrl,
    fetchedAtMs,
    channelCount,
    programCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgSyncMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_backend')) {
      context.handle(
        _sourceBackendMeta,
        sourceBackend.isAcceptableOrUnknown(
          data['source_backend']!,
          _sourceBackendMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceBackendMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('fetched_at_ms')) {
      context.handle(
        _fetchedAtMsMeta,
        fetchedAtMs.isAcceptableOrUnknown(
          data['fetched_at_ms']!,
          _fetchedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMsMeta);
    }
    if (data.containsKey('channel_count')) {
      context.handle(
        _channelCountMeta,
        channelCount.isAcceptableOrUnknown(
          data['channel_count']!,
          _channelCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_channelCountMeta);
    }
    if (data.containsKey('program_count')) {
      context.handle(
        _programCountMeta,
        programCount.isAcceptableOrUnknown(
          data['program_count']!,
          _programCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceBackend, baseUrl};
  @override
  EpgSyncMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgSyncMetaData(
      sourceBackend: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_backend'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      fetchedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at_ms'],
      )!,
      channelCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channel_count'],
      )!,
      programCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}program_count'],
      )!,
    );
  }

  @override
  $EpgSyncMetaTable createAlias(String alias) {
    return $EpgSyncMetaTable(attachedDatabase, alias);
  }
}

class EpgSyncMetaData extends DataClass implements Insertable<EpgSyncMetaData> {
  /// 同期対象バックエンド (`BackendType.name`)。
  final String sourceBackend;

  /// 正規化済み baseUrl (サーバー識別・変更検知用)。
  final String baseUrl;

  /// 取得完了時刻 (ms epoch)。
  final int fetchedAtMs;

  /// 書込チャンネル数。
  final int channelCount;

  /// 書込番組数。
  final int programCount;
  const EpgSyncMetaData({
    required this.sourceBackend,
    required this.baseUrl,
    required this.fetchedAtMs,
    required this.channelCount,
    required this.programCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_backend'] = Variable<String>(sourceBackend);
    map['base_url'] = Variable<String>(baseUrl);
    map['fetched_at_ms'] = Variable<int>(fetchedAtMs);
    map['channel_count'] = Variable<int>(channelCount);
    map['program_count'] = Variable<int>(programCount);
    return map;
  }

  EpgSyncMetaCompanion toCompanion(bool nullToAbsent) {
    return EpgSyncMetaCompanion(
      sourceBackend: Value(sourceBackend),
      baseUrl: Value(baseUrl),
      fetchedAtMs: Value(fetchedAtMs),
      channelCount: Value(channelCount),
      programCount: Value(programCount),
    );
  }

  factory EpgSyncMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgSyncMetaData(
      sourceBackend: serializer.fromJson<String>(json['sourceBackend']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      fetchedAtMs: serializer.fromJson<int>(json['fetchedAtMs']),
      channelCount: serializer.fromJson<int>(json['channelCount']),
      programCount: serializer.fromJson<int>(json['programCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceBackend': serializer.toJson<String>(sourceBackend),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'fetchedAtMs': serializer.toJson<int>(fetchedAtMs),
      'channelCount': serializer.toJson<int>(channelCount),
      'programCount': serializer.toJson<int>(programCount),
    };
  }

  EpgSyncMetaData copyWith({
    String? sourceBackend,
    String? baseUrl,
    int? fetchedAtMs,
    int? channelCount,
    int? programCount,
  }) => EpgSyncMetaData(
    sourceBackend: sourceBackend ?? this.sourceBackend,
    baseUrl: baseUrl ?? this.baseUrl,
    fetchedAtMs: fetchedAtMs ?? this.fetchedAtMs,
    channelCount: channelCount ?? this.channelCount,
    programCount: programCount ?? this.programCount,
  );
  EpgSyncMetaData copyWithCompanion(EpgSyncMetaCompanion data) {
    return EpgSyncMetaData(
      sourceBackend: data.sourceBackend.present
          ? data.sourceBackend.value
          : this.sourceBackend,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      fetchedAtMs: data.fetchedAtMs.present
          ? data.fetchedAtMs.value
          : this.fetchedAtMs,
      channelCount: data.channelCount.present
          ? data.channelCount.value
          : this.channelCount,
      programCount: data.programCount.present
          ? data.programCount.value
          : this.programCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgSyncMetaData(')
          ..write('sourceBackend: $sourceBackend, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('fetchedAtMs: $fetchedAtMs, ')
          ..write('channelCount: $channelCount, ')
          ..write('programCount: $programCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceBackend,
    baseUrl,
    fetchedAtMs,
    channelCount,
    programCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgSyncMetaData &&
          other.sourceBackend == this.sourceBackend &&
          other.baseUrl == this.baseUrl &&
          other.fetchedAtMs == this.fetchedAtMs &&
          other.channelCount == this.channelCount &&
          other.programCount == this.programCount);
}

class EpgSyncMetaCompanion extends UpdateCompanion<EpgSyncMetaData> {
  final Value<String> sourceBackend;
  final Value<String> baseUrl;
  final Value<int> fetchedAtMs;
  final Value<int> channelCount;
  final Value<int> programCount;
  final Value<int> rowid;
  const EpgSyncMetaCompanion({
    this.sourceBackend = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.fetchedAtMs = const Value.absent(),
    this.channelCount = const Value.absent(),
    this.programCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgSyncMetaCompanion.insert({
    required String sourceBackend,
    required String baseUrl,
    required int fetchedAtMs,
    required int channelCount,
    required int programCount,
    this.rowid = const Value.absent(),
  }) : sourceBackend = Value(sourceBackend),
       baseUrl = Value(baseUrl),
       fetchedAtMs = Value(fetchedAtMs),
       channelCount = Value(channelCount),
       programCount = Value(programCount);
  static Insertable<EpgSyncMetaData> custom({
    Expression<String>? sourceBackend,
    Expression<String>? baseUrl,
    Expression<int>? fetchedAtMs,
    Expression<int>? channelCount,
    Expression<int>? programCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceBackend != null) 'source_backend': sourceBackend,
      if (baseUrl != null) 'base_url': baseUrl,
      if (fetchedAtMs != null) 'fetched_at_ms': fetchedAtMs,
      if (channelCount != null) 'channel_count': channelCount,
      if (programCount != null) 'program_count': programCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgSyncMetaCompanion copyWith({
    Value<String>? sourceBackend,
    Value<String>? baseUrl,
    Value<int>? fetchedAtMs,
    Value<int>? channelCount,
    Value<int>? programCount,
    Value<int>? rowid,
  }) {
    return EpgSyncMetaCompanion(
      sourceBackend: sourceBackend ?? this.sourceBackend,
      baseUrl: baseUrl ?? this.baseUrl,
      fetchedAtMs: fetchedAtMs ?? this.fetchedAtMs,
      channelCount: channelCount ?? this.channelCount,
      programCount: programCount ?? this.programCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceBackend.present) {
      map['source_backend'] = Variable<String>(sourceBackend.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (fetchedAtMs.present) {
      map['fetched_at_ms'] = Variable<int>(fetchedAtMs.value);
    }
    if (channelCount.present) {
      map['channel_count'] = Variable<int>(channelCount.value);
    }
    if (programCount.present) {
      map['program_count'] = Variable<int>(programCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgSyncMetaCompanion(')
          ..write('sourceBackend: $sourceBackend, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('fetchedAtMs: $fetchedAtMs, ')
          ..write('channelCount: $channelCount, ')
          ..write('programCount: $programCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$EpgDatabase extends GeneratedDatabase {
  _$EpgDatabase(QueryExecutor e) : super(e);
  $EpgDatabaseManager get managers => $EpgDatabaseManager(this);
  late final $EpgChannelsTable epgChannels = $EpgChannelsTable(this);
  late final $EpgProgramsTable epgPrograms = $EpgProgramsTable(this);
  late final $EpgSyncMetaTable epgSyncMeta = $EpgSyncMetaTable(this);
  late final EpgDao epgDao = EpgDao(this as EpgDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    epgChannels,
    epgPrograms,
    epgSyncMeta,
  ];
}

typedef $$EpgChannelsTableCreateCompanionBuilder =
    EpgChannelsCompanion Function({
      required String sourceBackend,
      required int networkId,
      required int serviceId,
      required String remoteId,
      required String name,
      required String channelType,
      Value<String> channelNumber,
      Value<String> tunerChannel,
      Value<bool> hasLogo,
      required int sortOrder,
      Value<int> rowid,
    });
typedef $$EpgChannelsTableUpdateCompanionBuilder =
    EpgChannelsCompanion Function({
      Value<String> sourceBackend,
      Value<int> networkId,
      Value<int> serviceId,
      Value<String> remoteId,
      Value<String> name,
      Value<String> channelType,
      Value<String> channelNumber,
      Value<String> tunerChannel,
      Value<bool> hasLogo,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$EpgChannelsTableFilterComposer
    extends Composer<_$EpgDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceBackend => $composableBuilder(
    column: $table.sourceBackend,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelType => $composableBuilder(
    column: $table.channelType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelNumber => $composableBuilder(
    column: $table.channelNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tunerChannel => $composableBuilder(
    column: $table.tunerChannel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasLogo => $composableBuilder(
    column: $table.hasLogo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpgChannelsTableOrderingComposer
    extends Composer<_$EpgDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceBackend => $composableBuilder(
    column: $table.sourceBackend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelType => $composableBuilder(
    column: $table.channelType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelNumber => $composableBuilder(
    column: $table.channelNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tunerChannel => $composableBuilder(
    column: $table.tunerChannel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasLogo => $composableBuilder(
    column: $table.hasLogo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpgChannelsTableAnnotationComposer
    extends Composer<_$EpgDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceBackend => $composableBuilder(
    column: $table.sourceBackend,
    builder: (column) => column,
  );

  GeneratedColumn<int> get networkId =>
      $composableBuilder(column: $table.networkId, builder: (column) => column);

  GeneratedColumn<int> get serviceId =>
      $composableBuilder(column: $table.serviceId, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get channelType => $composableBuilder(
    column: $table.channelType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get channelNumber => $composableBuilder(
    column: $table.channelNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tunerChannel => $composableBuilder(
    column: $table.tunerChannel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasLogo =>
      $composableBuilder(column: $table.hasLogo, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$EpgChannelsTableTableManager
    extends
        RootTableManager<
          _$EpgDatabase,
          $EpgChannelsTable,
          EpgChannel,
          $$EpgChannelsTableFilterComposer,
          $$EpgChannelsTableOrderingComposer,
          $$EpgChannelsTableAnnotationComposer,
          $$EpgChannelsTableCreateCompanionBuilder,
          $$EpgChannelsTableUpdateCompanionBuilder,
          (
            EpgChannel,
            BaseReferences<_$EpgDatabase, $EpgChannelsTable, EpgChannel>,
          ),
          EpgChannel,
          PrefetchHooks Function()
        > {
  $$EpgChannelsTableTableManager(_$EpgDatabase db, $EpgChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceBackend = const Value.absent(),
                Value<int> networkId = const Value.absent(),
                Value<int> serviceId = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> channelType = const Value.absent(),
                Value<String> channelNumber = const Value.absent(),
                Value<String> tunerChannel = const Value.absent(),
                Value<bool> hasLogo = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgChannelsCompanion(
                sourceBackend: sourceBackend,
                networkId: networkId,
                serviceId: serviceId,
                remoteId: remoteId,
                name: name,
                channelType: channelType,
                channelNumber: channelNumber,
                tunerChannel: tunerChannel,
                hasLogo: hasLogo,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceBackend,
                required int networkId,
                required int serviceId,
                required String remoteId,
                required String name,
                required String channelType,
                Value<String> channelNumber = const Value.absent(),
                Value<String> tunerChannel = const Value.absent(),
                Value<bool> hasLogo = const Value.absent(),
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => EpgChannelsCompanion.insert(
                sourceBackend: sourceBackend,
                networkId: networkId,
                serviceId: serviceId,
                remoteId: remoteId,
                name: name,
                channelType: channelType,
                channelNumber: channelNumber,
                tunerChannel: tunerChannel,
                hasLogo: hasLogo,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpgChannelsTable, EpgChannel>(table),
                  BaseReferences<_$EpgDatabase, $EpgChannelsTable, EpgChannel>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpgChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$EpgDatabase,
      $EpgChannelsTable,
      EpgChannel,
      $$EpgChannelsTableFilterComposer,
      $$EpgChannelsTableOrderingComposer,
      $$EpgChannelsTableAnnotationComposer,
      $$EpgChannelsTableCreateCompanionBuilder,
      $$EpgChannelsTableUpdateCompanionBuilder,
      (
        EpgChannel,
        BaseReferences<_$EpgDatabase, $EpgChannelsTable, EpgChannel>,
      ),
      EpgChannel,
      PrefetchHooks Function()
    >;
typedef $$EpgProgramsTableCreateCompanionBuilder =
    EpgProgramsCompanion Function({
      required String sourceBackend,
      required int networkId,
      required int serviceId,
      required int eventId,
      required int startAtMs,
      required int endAtMs,
      required String title,
      Value<String> description,
      Value<String> genresJson,
      Value<String> detailJson,
      Value<int> rowid,
    });
typedef $$EpgProgramsTableUpdateCompanionBuilder =
    EpgProgramsCompanion Function({
      Value<String> sourceBackend,
      Value<int> networkId,
      Value<int> serviceId,
      Value<int> eventId,
      Value<int> startAtMs,
      Value<int> endAtMs,
      Value<String> title,
      Value<String> description,
      Value<String> genresJson,
      Value<String> detailJson,
      Value<int> rowid,
    });

class $$EpgProgramsTableFilterComposer
    extends Composer<_$EpgDatabase, $EpgProgramsTable> {
  $$EpgProgramsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceBackend => $composableBuilder(
    column: $table.sourceBackend,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startAtMs => $composableBuilder(
    column: $table.startAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endAtMs => $composableBuilder(
    column: $table.endAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpgProgramsTableOrderingComposer
    extends Composer<_$EpgDatabase, $EpgProgramsTable> {
  $$EpgProgramsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceBackend => $composableBuilder(
    column: $table.sourceBackend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startAtMs => $composableBuilder(
    column: $table.startAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endAtMs => $composableBuilder(
    column: $table.endAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpgProgramsTableAnnotationComposer
    extends Composer<_$EpgDatabase, $EpgProgramsTable> {
  $$EpgProgramsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceBackend => $composableBuilder(
    column: $table.sourceBackend,
    builder: (column) => column,
  );

  GeneratedColumn<int> get networkId =>
      $composableBuilder(column: $table.networkId, builder: (column) => column);

  GeneratedColumn<int> get serviceId =>
      $composableBuilder(column: $table.serviceId, builder: (column) => column);

  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get startAtMs =>
      $composableBuilder(column: $table.startAtMs, builder: (column) => column);

  GeneratedColumn<int> get endAtMs =>
      $composableBuilder(column: $table.endAtMs, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genresJson => $composableBuilder(
    column: $table.genresJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => column,
  );
}

class $$EpgProgramsTableTableManager
    extends
        RootTableManager<
          _$EpgDatabase,
          $EpgProgramsTable,
          EpgProgram,
          $$EpgProgramsTableFilterComposer,
          $$EpgProgramsTableOrderingComposer,
          $$EpgProgramsTableAnnotationComposer,
          $$EpgProgramsTableCreateCompanionBuilder,
          $$EpgProgramsTableUpdateCompanionBuilder,
          (
            EpgProgram,
            BaseReferences<_$EpgDatabase, $EpgProgramsTable, EpgProgram>,
          ),
          EpgProgram,
          PrefetchHooks Function()
        > {
  $$EpgProgramsTableTableManager(_$EpgDatabase db, $EpgProgramsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgProgramsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgProgramsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgProgramsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceBackend = const Value.absent(),
                Value<int> networkId = const Value.absent(),
                Value<int> serviceId = const Value.absent(),
                Value<int> eventId = const Value.absent(),
                Value<int> startAtMs = const Value.absent(),
                Value<int> endAtMs = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> genresJson = const Value.absent(),
                Value<String> detailJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgProgramsCompanion(
                sourceBackend: sourceBackend,
                networkId: networkId,
                serviceId: serviceId,
                eventId: eventId,
                startAtMs: startAtMs,
                endAtMs: endAtMs,
                title: title,
                description: description,
                genresJson: genresJson,
                detailJson: detailJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceBackend,
                required int networkId,
                required int serviceId,
                required int eventId,
                required int startAtMs,
                required int endAtMs,
                required String title,
                Value<String> description = const Value.absent(),
                Value<String> genresJson = const Value.absent(),
                Value<String> detailJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgProgramsCompanion.insert(
                sourceBackend: sourceBackend,
                networkId: networkId,
                serviceId: serviceId,
                eventId: eventId,
                startAtMs: startAtMs,
                endAtMs: endAtMs,
                title: title,
                description: description,
                genresJson: genresJson,
                detailJson: detailJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpgProgramsTable, EpgProgram>(table),
                  BaseReferences<_$EpgDatabase, $EpgProgramsTable, EpgProgram>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpgProgramsTableProcessedTableManager =
    ProcessedTableManager<
      _$EpgDatabase,
      $EpgProgramsTable,
      EpgProgram,
      $$EpgProgramsTableFilterComposer,
      $$EpgProgramsTableOrderingComposer,
      $$EpgProgramsTableAnnotationComposer,
      $$EpgProgramsTableCreateCompanionBuilder,
      $$EpgProgramsTableUpdateCompanionBuilder,
      (
        EpgProgram,
        BaseReferences<_$EpgDatabase, $EpgProgramsTable, EpgProgram>,
      ),
      EpgProgram,
      PrefetchHooks Function()
    >;
typedef $$EpgSyncMetaTableCreateCompanionBuilder =
    EpgSyncMetaCompanion Function({
      required String sourceBackend,
      required String baseUrl,
      required int fetchedAtMs,
      required int channelCount,
      required int programCount,
      Value<int> rowid,
    });
typedef $$EpgSyncMetaTableUpdateCompanionBuilder =
    EpgSyncMetaCompanion Function({
      Value<String> sourceBackend,
      Value<String> baseUrl,
      Value<int> fetchedAtMs,
      Value<int> channelCount,
      Value<int> programCount,
      Value<int> rowid,
    });

class $$EpgSyncMetaTableFilterComposer
    extends Composer<_$EpgDatabase, $EpgSyncMetaTable> {
  $$EpgSyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceBackend => $composableBuilder(
    column: $table.sourceBackend,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAtMs => $composableBuilder(
    column: $table.fetchedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get channelCount => $composableBuilder(
    column: $table.channelCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get programCount => $composableBuilder(
    column: $table.programCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpgSyncMetaTableOrderingComposer
    extends Composer<_$EpgDatabase, $EpgSyncMetaTable> {
  $$EpgSyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceBackend => $composableBuilder(
    column: $table.sourceBackend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAtMs => $composableBuilder(
    column: $table.fetchedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get channelCount => $composableBuilder(
    column: $table.channelCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get programCount => $composableBuilder(
    column: $table.programCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpgSyncMetaTableAnnotationComposer
    extends Composer<_$EpgDatabase, $EpgSyncMetaTable> {
  $$EpgSyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceBackend => $composableBuilder(
    column: $table.sourceBackend,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<int> get fetchedAtMs => $composableBuilder(
    column: $table.fetchedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get channelCount => $composableBuilder(
    column: $table.channelCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get programCount => $composableBuilder(
    column: $table.programCount,
    builder: (column) => column,
  );
}

class $$EpgSyncMetaTableTableManager
    extends
        RootTableManager<
          _$EpgDatabase,
          $EpgSyncMetaTable,
          EpgSyncMetaData,
          $$EpgSyncMetaTableFilterComposer,
          $$EpgSyncMetaTableOrderingComposer,
          $$EpgSyncMetaTableAnnotationComposer,
          $$EpgSyncMetaTableCreateCompanionBuilder,
          $$EpgSyncMetaTableUpdateCompanionBuilder,
          (
            EpgSyncMetaData,
            BaseReferences<_$EpgDatabase, $EpgSyncMetaTable, EpgSyncMetaData>,
          ),
          EpgSyncMetaData,
          PrefetchHooks Function()
        > {
  $$EpgSyncMetaTableTableManager(_$EpgDatabase db, $EpgSyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgSyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgSyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgSyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceBackend = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<int> fetchedAtMs = const Value.absent(),
                Value<int> channelCount = const Value.absent(),
                Value<int> programCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgSyncMetaCompanion(
                sourceBackend: sourceBackend,
                baseUrl: baseUrl,
                fetchedAtMs: fetchedAtMs,
                channelCount: channelCount,
                programCount: programCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceBackend,
                required String baseUrl,
                required int fetchedAtMs,
                required int channelCount,
                required int programCount,
                Value<int> rowid = const Value.absent(),
              }) => EpgSyncMetaCompanion.insert(
                sourceBackend: sourceBackend,
                baseUrl: baseUrl,
                fetchedAtMs: fetchedAtMs,
                channelCount: channelCount,
                programCount: programCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpgSyncMetaTable, EpgSyncMetaData>(table),
                  BaseReferences<
                    _$EpgDatabase,
                    $EpgSyncMetaTable,
                    EpgSyncMetaData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpgSyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$EpgDatabase,
      $EpgSyncMetaTable,
      EpgSyncMetaData,
      $$EpgSyncMetaTableFilterComposer,
      $$EpgSyncMetaTableOrderingComposer,
      $$EpgSyncMetaTableAnnotationComposer,
      $$EpgSyncMetaTableCreateCompanionBuilder,
      $$EpgSyncMetaTableUpdateCompanionBuilder,
      (
        EpgSyncMetaData,
        BaseReferences<_$EpgDatabase, $EpgSyncMetaTable, EpgSyncMetaData>,
      ),
      EpgSyncMetaData,
      PrefetchHooks Function()
    >;

class $EpgDatabaseManager {
  final _$EpgDatabase _db;
  $EpgDatabaseManager(this._db);
  $$EpgChannelsTableTableManager get epgChannels =>
      $$EpgChannelsTableTableManager(_db, _db.epgChannels);
  $$EpgProgramsTableTableManager get epgPrograms =>
      $$EpgProgramsTableTableManager(_db, _db.epgPrograms);
  $$EpgSyncMetaTableTableManager get epgSyncMeta =>
      $$EpgSyncMetaTableTableManager(_db, _db.epgSyncMeta);
}
