// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_dao.dart';

// ignore_for_file: type=lint
mixin _$EpgDaoMixin on DatabaseAccessor<EpgDatabase> {
  $EpgChannelsTable get epgChannels => attachedDatabase.epgChannels;
  $EpgProgramsTable get epgPrograms => attachedDatabase.epgPrograms;
  $EpgSyncMetaTable get epgSyncMeta => attachedDatabase.epgSyncMeta;
  EpgDaoManager get managers => EpgDaoManager(this);
}

class EpgDaoManager {
  final _$EpgDaoMixin _db;
  EpgDaoManager(this._db);
  $$EpgChannelsTableTableManager get epgChannels =>
      $$EpgChannelsTableTableManager(_db.attachedDatabase, _db.epgChannels);
  $$EpgProgramsTableTableManager get epgPrograms =>
      $$EpgProgramsTableTableManager(_db.attachedDatabase, _db.epgPrograms);
  $$EpgSyncMetaTableTableManager get epgSyncMeta =>
      $$EpgSyncMetaTableTableManager(_db.attachedDatabase, _db.epgSyncMeta);
}
