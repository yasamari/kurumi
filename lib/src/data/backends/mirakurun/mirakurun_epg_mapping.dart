import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/utils/program_text.dart';
import '../../../domain/entities/backend_type.dart';
import '../../epg/epg_database.dart';
import 'mirakurun_filter.dart';
import 'mirakurun_genre.dart';
import 'mirakurun_program_dto.dart';
import 'mirakurun_service_dto.dart';

/// Mirakurunサービス1件をEPGチャンネル行に変換する純粋関数。
///
/// [sortOrder] は `/api/services` の応答順 (0始まり)。出力順の維持用。
EpgChannelsCompanion epgChannelFromService(
  MirakurunServiceDto service, {
  required int sortOrder,
}) {
  final channel = service.channel;
  return EpgChannelsCompanion(
    sourceBackend: Value(BackendType.mirakurun.name),
    networkId: Value(service.networkId),
    serviceId: Value(service.serviceId),
    remoteId: Value(service.id.toString()),
    name: Value(formatProgramText(service.name)),
    channelType: Value(channel?.type ?? ''),
    channelNumber: Value(
      service.remoteControlKeyId != null
          ? service.remoteControlKeyId.toString().padLeft(3, '0')
          : '',
    ),
    tunerChannel: Value(channel?.channel ?? ''),
    hasLogo: Value(service.hasLogoData == true),
    sortOrder: Value(sortOrder),
  );
}

/// Mirakurun番組1件をEPG番組行に変換する純粋関数。
EpgProgramsCompanion epgProgramFromDto(MirakurunProgramDto program) {
  return EpgProgramsCompanion(
    sourceBackend: Value(BackendType.mirakurun.name),
    networkId: Value(program.networkId),
    serviceId: Value(program.serviceId),
    eventId: Value(program.eventId),
    startAtMs: Value(program.startAt),
    endAtMs: Value(program.startAt + program.duration),
    title: Value(formatProgramText(program.name ?? '')),
    description: Value(formatProgramText(program.description ?? '')),
    genresJson: Value(jsonEncode(mirakurunGenreLabels(program.genres))),
    detailJson: Value(jsonEncode(mirakurunDetailStrings(program.extended))),
  );
}
