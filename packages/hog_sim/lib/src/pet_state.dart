import 'dart:convert';

import 'constants.dart';

enum Stage { egg, piglet, shoat, adult }

enum Form { base, prizeHog, farmHog, runt }

enum DeathCause { starvation, illness, neglect, oldAge }

/// Marks a `copyWith` argument as "not supplied", so nullable fields can be
/// explicitly cleared as well as set.
const Object _unset = Object();

/// The complete state of one pig.
///
/// Immutable, and serialised as plain JSON types only — no `DateTime`, no
/// `Duration`, no enums on the wire. Times are integer milliseconds since the
/// epoch, which stay exact under dart2js (a millisecond timestamp is ~1.7e12,
/// far inside the 53-bit range) and cross the Node bridge without conversion.
class PetState {
  const PetState({
    required this.petId,
    required this.ownerId,
    required this.name,
    required this.bornAtMillis,
    required this.lastTickAtMillis,
    required this.expiresAtMillis,
    required this.utcOffsetMinutes,
    required this.stage,
    required this.form,
    required this.fullness,
    required this.enrichment,
    required this.comfort,
    required this.cleanliness,
    required this.health,
    required this.weight,
    required this.discipline,
    required this.isSick,
    required this.lightsOn,
    required this.poops,
    required this.pendingPoopTicks,
    required this.needZeroSinceTick,
    required this.careMistakes,
    required this.stageCareMistakes,
    this.sickSinceTick,
    this.diedAtMillis,
    this.deathCause,
    this.lastPlayedAtMillis,
  });

  /// A brand new egg, with every need full and no history.
  factory PetState.newborn({
    required String petId,
    required String ownerId,
    required String name,
    required int nowMillis,
    required int utcOffsetMinutes,
  }) {
    final trimmed = name.length > kMaxNameLength
        ? name.substring(0, kMaxNameLength)
        : name;
    return PetState(
      petId: petId,
      ownerId: ownerId,
      name: trimmed,
      bornAtMillis: nowMillis,
      lastTickAtMillis: nowMillis,
      expiresAtMillis: kExpiresAtSentinelMillis,
      utcOffsetMinutes: utcOffsetMinutes,
      stage: Stage.egg,
      form: Form.base,
      fullness: 100,
      enrichment: 100,
      comfort: 100,
      cleanliness: 100,
      health: 100,
      weight: kNewbornWeight,
      discipline: 0,
      isSick: false,
      lightsOn: true,
      poops: const [],
      pendingPoopTicks: const [],
      needZeroSinceTick: const {},
      careMistakes: 0,
      stageCareMistakes: 0,
    );
  }

  final String petId;
  final String ownerId;
  final String name;

  /// The simulation cursor. `advance` steps from here to the current time.
  final int bornAtMillis;
  final int lastTickAtMillis;
  final int expiresAtMillis;

  /// Offset from UTC in minutes, captured from the player's device when the pet
  /// was created. Drives the sleep window. See the plan's note on why this is an
  /// offset rather than an IANA zone name.
  final int utcOffsetMinutes;

  final Stage stage;
  final Form form;

  final double fullness;
  final double enrichment;
  final double comfort;
  final double cleanliness;
  final double health;
  final double weight;

  /// Raised by training, lowered by ignoring misbehaviour. Cut from v1 (D2) but
  /// kept in the model so restoring it later is not a migration.
  final double discipline;

  final bool isSick;

  /// Tick at which the current illness began. Required by the `illness` death
  /// cause, which asks whether the pig has been sick for the preceding 24h.
  final int? sickSinceTick;

  final bool lightsOn;

  /// Tick indices of poops currently on the floor.
  final List<int> poops;

  /// Tick indices of poops scheduled to arrive.
  final List<int> pendingPoopTicks;

  /// Per-need tick at which it bottomed out. A need absent from this map is not
  /// currently at zero.
  final Map<String, int> needZeroSinceTick;

  final int careMistakes;
  final int stageCareMistakes;

  final int? lastPlayedAtMillis;
  final int? diedAtMillis;
  final DeathCause? deathCause;

  bool get isDead => diedAtMillis != null;

  /// Reads a need by name. Lets the tick loop treat all four identically.
  double need(String name) => switch (name) {
    'fullness' => fullness,
    'enrichment' => enrichment,
    'comfort' => comfort,
    'cleanliness' => cleanliness,
    _ => throw ArgumentError('unknown need: $name'),
  };

  PetState withNeed(String name, double value) => switch (name) {
    'fullness' => copyWith(fullness: value),
    'enrichment' => copyWith(enrichment: value),
    'comfort' => copyWith(comfort: value),
    'cleanliness' => copyWith(cleanliness: value),
    _ => throw ArgumentError('unknown need: $name'),
  };

  PetState copyWith({
    String? name,
    int? lastTickAtMillis,
    int? expiresAtMillis,
    int? utcOffsetMinutes,
    Stage? stage,
    Form? form,
    double? fullness,
    double? enrichment,
    double? comfort,
    double? cleanliness,
    double? health,
    double? weight,
    double? discipline,
    bool? isSick,
    bool? lightsOn,
    List<int>? poops,
    List<int>? pendingPoopTicks,
    Map<String, int>? needZeroSinceTick,
    int? careMistakes,
    int? stageCareMistakes,
    Object? sickSinceTick = _unset,
    Object? lastPlayedAtMillis = _unset,
    Object? diedAtMillis = _unset,
    Object? deathCause = _unset,
  }) {
    return PetState(
      petId: petId,
      ownerId: ownerId,
      name: name ?? this.name,
      bornAtMillis: bornAtMillis,
      lastTickAtMillis: lastTickAtMillis ?? this.lastTickAtMillis,
      expiresAtMillis: expiresAtMillis ?? this.expiresAtMillis,
      utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
      stage: stage ?? this.stage,
      form: form ?? this.form,
      fullness: fullness ?? this.fullness,
      enrichment: enrichment ?? this.enrichment,
      comfort: comfort ?? this.comfort,
      cleanliness: cleanliness ?? this.cleanliness,
      health: health ?? this.health,
      weight: weight ?? this.weight,
      discipline: discipline ?? this.discipline,
      isSick: isSick ?? this.isSick,
      lightsOn: lightsOn ?? this.lightsOn,
      poops: poops ?? this.poops,
      pendingPoopTicks: pendingPoopTicks ?? this.pendingPoopTicks,
      needZeroSinceTick: needZeroSinceTick ?? this.needZeroSinceTick,
      careMistakes: careMistakes ?? this.careMistakes,
      stageCareMistakes: stageCareMistakes ?? this.stageCareMistakes,
      sickSinceTick: identical(sickSinceTick, _unset)
          ? this.sickSinceTick
          : sickSinceTick as int?,
      lastPlayedAtMillis: identical(lastPlayedAtMillis, _unset)
          ? this.lastPlayedAtMillis
          : lastPlayedAtMillis as int?,
      diedAtMillis: identical(diedAtMillis, _unset)
          ? this.diedAtMillis
          : diedAtMillis as int?,
      deathCause: identical(deathCause, _unset)
          ? this.deathCause
          : deathCause as DeathCause?,
    );
  }

  Map<String, Object?> toJson() => {
    'petId': petId,
    'ownerId': ownerId,
    'name': name,
    'bornAtMillis': bornAtMillis,
    'lastTickAtMillis': lastTickAtMillis,
    'expiresAtMillis': expiresAtMillis,
    'utcOffsetMinutes': utcOffsetMinutes,
    'stage': stage.name,
    'form': form.name,
    'fullness': fullness,
    'enrichment': enrichment,
    'comfort': comfort,
    'cleanliness': cleanliness,
    'health': health,
    'weight': weight,
    'discipline': discipline,
    'isSick': isSick,
    'sickSinceTick': sickSinceTick,
    'lightsOn': lightsOn,
    'poops': List<int>.unmodifiable(poops),
    'pendingPoopTicks': List<int>.unmodifiable(pendingPoopTicks),
    'needZeroSinceTick': Map<String, int>.from(needZeroSinceTick),
    'careMistakes': careMistakes,
    'stageCareMistakes': stageCareMistakes,
    'lastPlayedAtMillis': lastPlayedAtMillis,
    'diedAtMillis': diedAtMillis,
    'deathCause': deathCause?.name,
  };

  static PetState fromJson(Map<String, Object?> json) {
    // Firestore and JSON both hand back whole numbers as int, so every double
    // field has to tolerate arriving as an int.
    double asDouble(String key) => (json[key]! as num).toDouble();
    int asInt(String key) => (json[key]! as num).toInt();
    int? asIntOrNull(String key) => (json[key] as num?)?.toInt();

    return PetState(
      petId: json['petId']! as String,
      ownerId: json['ownerId']! as String,
      name: json['name']! as String,
      bornAtMillis: asInt('bornAtMillis'),
      lastTickAtMillis: asInt('lastTickAtMillis'),
      expiresAtMillis: asInt('expiresAtMillis'),
      utcOffsetMinutes: asInt('utcOffsetMinutes'),
      stage: _byName(Stage.values, json['stage']! as String, 'stage'),
      form: _byName(Form.values, json['form']! as String, 'form'),
      fullness: asDouble('fullness'),
      enrichment: asDouble('enrichment'),
      comfort: asDouble('comfort'),
      cleanliness: asDouble('cleanliness'),
      health: asDouble('health'),
      weight: asDouble('weight'),
      discipline: asDouble('discipline'),
      isSick: json['isSick']! as bool,
      sickSinceTick: asIntOrNull('sickSinceTick'),
      lightsOn: json['lightsOn']! as bool,
      poops: [for (final v in json['poops']! as List) (v as num).toInt()],
      pendingPoopTicks: [
        for (final v in json['pendingPoopTicks']! as List) (v as num).toInt(),
      ],
      needZeroSinceTick: {
        for (final e in (json['needZeroSinceTick']! as Map).entries)
          e.key as String: (e.value as num).toInt(),
      },
      careMistakes: asInt('careMistakes'),
      stageCareMistakes: asInt('stageCareMistakes'),
      lastPlayedAtMillis: asIntOrNull('lastPlayedAtMillis'),
      diedAtMillis: asIntOrNull('diedAtMillis'),
      deathCause: json['deathCause'] == null
          ? null
          : _byName(
              DeathCause.values,
              json['deathCause']! as String,
              'deathCause',
            ),
    );
  }

  static T _byName<T extends Enum>(List<T> values, String name, String field) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw ArgumentError('unknown $field: $name');
  }

  @override
  bool operator ==(Object other) =>
      other is PetState &&
      other.petId == petId &&
      other.ownerId == ownerId &&
      other.name == name &&
      other.bornAtMillis == bornAtMillis &&
      other.lastTickAtMillis == lastTickAtMillis &&
      other.expiresAtMillis == expiresAtMillis &&
      other.utcOffsetMinutes == utcOffsetMinutes &&
      other.stage == stage &&
      other.form == form &&
      other.fullness == fullness &&
      other.enrichment == enrichment &&
      other.comfort == comfort &&
      other.cleanliness == cleanliness &&
      other.health == health &&
      other.weight == weight &&
      other.discipline == discipline &&
      other.isSick == isSick &&
      other.sickSinceTick == sickSinceTick &&
      other.lightsOn == lightsOn &&
      _listEquals(other.poops, poops) &&
      _listEquals(other.pendingPoopTicks, pendingPoopTicks) &&
      _mapEquals(other.needZeroSinceTick, needZeroSinceTick) &&
      other.careMistakes == careMistakes &&
      other.stageCareMistakes == stageCareMistakes &&
      other.lastPlayedAtMillis == lastPlayedAtMillis &&
      other.diedAtMillis == diedAtMillis &&
      other.deathCause == deathCause;

  // Never fed into the simulation — see the determinism rules in rng.dart. This
  // exists so PetState can go in a Set or Map during tests.
  @override
  int get hashCode => Object.hash(
    petId,
    lastTickAtMillis,
    stage,
    form,
    fullness,
    enrichment,
    comfort,
    cleanliness,
    health,
    weight,
    isSick,
    careMistakes,
    diedAtMillis,
  );

  @override
  String toString() =>
      'PetState($name ${stage.name}/${form.name} '
      'f=${fullness.toStringAsFixed(1)} e=${enrichment.toStringAsFixed(1)} '
      'c=${comfort.toStringAsFixed(1)} cl=${cleanliness.toStringAsFixed(1)} '
      'hp=${health.toStringAsFixed(1)} w=${weight.toStringAsFixed(1)} '
      '${isSick ? 'sick ' : ''}${isDead ? 'DEAD:${deathCause?.name} ' : ''}'
      'mistakes=$careMistakes/$stageCareMistakes)';
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

String jsonEncodeState(PetState state) => jsonEncode(state.toJson());

PetState jsonDecodeState(String text) =>
    PetState.fromJson(jsonDecode(text) as Map<String, Object?>);
