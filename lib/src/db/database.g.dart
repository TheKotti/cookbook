// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RecipesTable extends Recipes with TableInfo<$RecipesTable, Recipe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseServingsMeta = const VerificationMeta(
    'baseServings',
  );
  @override
  late final GeneratedColumn<int> baseServings = GeneratedColumn<int>(
    'base_servings',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prepMinutesMeta = const VerificationMeta(
    'prepMinutes',
  );
  @override
  late final GeneratedColumn<int> prepMinutes = GeneratedColumn<int>(
    'prep_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cookMinutesMeta = const VerificationMeta(
    'cookMinutes',
  );
  @override
  late final GeneratedColumn<int> cookMinutes = GeneratedColumn<int>(
    'cook_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalMinutesMeta = const VerificationMeta(
    'totalMinutes',
  );
  @override
  late final GeneratedColumn<int> totalMinutes = GeneratedColumn<int>(
    'total_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ingredientsJsonMeta = const VerificationMeta(
    'ingredientsJson',
  );
  @override
  late final GeneratedColumn<String> ingredientsJson = GeneratedColumn<String>(
    'ingredients_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepsJsonMeta = const VerificationMeta(
    'stepsJson',
  );
  @override
  late final GeneratedColumn<String> stepsJson = GeneratedColumn<String>(
    'steps_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<String> importedAt = GeneratedColumn<String>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localImagePathMeta = const VerificationMeta(
    'localImagePath',
  );
  @override
  late final GeneratedColumn<String> localImagePath = GeneratedColumn<String>(
    'local_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceUrl,
    title,
    author,
    imageUrl,
    baseServings,
    prepMinutes,
    cookMinutes,
    totalMinutes,
    rating,
    ingredientsJson,
    stepsJson,
    importedAt,
    schemaVersion,
    localImagePath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Recipe> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('base_servings')) {
      context.handle(
        _baseServingsMeta,
        baseServings.isAcceptableOrUnknown(
          data['base_servings']!,
          _baseServingsMeta,
        ),
      );
    }
    if (data.containsKey('prep_minutes')) {
      context.handle(
        _prepMinutesMeta,
        prepMinutes.isAcceptableOrUnknown(
          data['prep_minutes']!,
          _prepMinutesMeta,
        ),
      );
    }
    if (data.containsKey('cook_minutes')) {
      context.handle(
        _cookMinutesMeta,
        cookMinutes.isAcceptableOrUnknown(
          data['cook_minutes']!,
          _cookMinutesMeta,
        ),
      );
    }
    if (data.containsKey('total_minutes')) {
      context.handle(
        _totalMinutesMeta,
        totalMinutes.isAcceptableOrUnknown(
          data['total_minutes']!,
          _totalMinutesMeta,
        ),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('ingredients_json')) {
      context.handle(
        _ingredientsJsonMeta,
        ingredientsJson.isAcceptableOrUnknown(
          data['ingredients_json']!,
          _ingredientsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ingredientsJsonMeta);
    }
    if (data.containsKey('steps_json')) {
      context.handle(
        _stepsJsonMeta,
        stepsJson.isAcceptableOrUnknown(data['steps_json']!, _stepsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsJsonMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('local_image_path')) {
      context.handle(
        _localImagePathMeta,
        localImagePath.isAcceptableOrUnknown(
          data['local_image_path']!,
          _localImagePathMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Recipe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Recipe(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      baseServings: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_servings'],
      ),
      prepMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prep_minutes'],
      ),
      cookMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cook_minutes'],
      ),
      totalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_minutes'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      ingredientsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ingredients_json'],
      )!,
      stepsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps_json'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imported_at'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      localImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_image_path'],
      ),
    );
  }

  @override
  $RecipesTable createAlias(String alias) {
    return $RecipesTable(attachedDatabase, alias);
  }
}

class Recipe extends DataClass implements Insertable<Recipe> {
  final int id;
  final String sourceUrl;
  final String title;
  final String author;
  final String? imageUrl;
  final int? baseServings;
  final int? prepMinutes;
  final int? cookMinutes;
  final int? totalMinutes;
  final double? rating;
  final String ingredientsJson;
  final String stepsJson;
  final String importedAt;
  final int schemaVersion;
  final String? localImagePath;
  const Recipe({
    required this.id,
    required this.sourceUrl,
    required this.title,
    required this.author,
    this.imageUrl,
    this.baseServings,
    this.prepMinutes,
    this.cookMinutes,
    this.totalMinutes,
    this.rating,
    required this.ingredientsJson,
    required this.stepsJson,
    required this.importedAt,
    required this.schemaVersion,
    this.localImagePath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_url'] = Variable<String>(sourceUrl);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || baseServings != null) {
      map['base_servings'] = Variable<int>(baseServings);
    }
    if (!nullToAbsent || prepMinutes != null) {
      map['prep_minutes'] = Variable<int>(prepMinutes);
    }
    if (!nullToAbsent || cookMinutes != null) {
      map['cook_minutes'] = Variable<int>(cookMinutes);
    }
    if (!nullToAbsent || totalMinutes != null) {
      map['total_minutes'] = Variable<int>(totalMinutes);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    map['ingredients_json'] = Variable<String>(ingredientsJson);
    map['steps_json'] = Variable<String>(stepsJson);
    map['imported_at'] = Variable<String>(importedAt);
    map['schema_version'] = Variable<int>(schemaVersion);
    if (!nullToAbsent || localImagePath != null) {
      map['local_image_path'] = Variable<String>(localImagePath);
    }
    return map;
  }

  RecipesCompanion toCompanion(bool nullToAbsent) {
    return RecipesCompanion(
      id: Value(id),
      sourceUrl: Value(sourceUrl),
      title: Value(title),
      author: Value(author),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      baseServings: baseServings == null && nullToAbsent
          ? const Value.absent()
          : Value(baseServings),
      prepMinutes: prepMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(prepMinutes),
      cookMinutes: cookMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(cookMinutes),
      totalMinutes: totalMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalMinutes),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      ingredientsJson: Value(ingredientsJson),
      stepsJson: Value(stepsJson),
      importedAt: Value(importedAt),
      schemaVersion: Value(schemaVersion),
      localImagePath: localImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localImagePath),
    );
  }

  factory Recipe.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Recipe(
      id: serializer.fromJson<int>(json['id']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      baseServings: serializer.fromJson<int?>(json['baseServings']),
      prepMinutes: serializer.fromJson<int?>(json['prepMinutes']),
      cookMinutes: serializer.fromJson<int?>(json['cookMinutes']),
      totalMinutes: serializer.fromJson<int?>(json['totalMinutes']),
      rating: serializer.fromJson<double?>(json['rating']),
      ingredientsJson: serializer.fromJson<String>(json['ingredientsJson']),
      stepsJson: serializer.fromJson<String>(json['stepsJson']),
      importedAt: serializer.fromJson<String>(json['importedAt']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      localImagePath: serializer.fromJson<String?>(json['localImagePath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'baseServings': serializer.toJson<int?>(baseServings),
      'prepMinutes': serializer.toJson<int?>(prepMinutes),
      'cookMinutes': serializer.toJson<int?>(cookMinutes),
      'totalMinutes': serializer.toJson<int?>(totalMinutes),
      'rating': serializer.toJson<double?>(rating),
      'ingredientsJson': serializer.toJson<String>(ingredientsJson),
      'stepsJson': serializer.toJson<String>(stepsJson),
      'importedAt': serializer.toJson<String>(importedAt),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'localImagePath': serializer.toJson<String?>(localImagePath),
    };
  }

  Recipe copyWith({
    int? id,
    String? sourceUrl,
    String? title,
    String? author,
    Value<String?> imageUrl = const Value.absent(),
    Value<int?> baseServings = const Value.absent(),
    Value<int?> prepMinutes = const Value.absent(),
    Value<int?> cookMinutes = const Value.absent(),
    Value<int?> totalMinutes = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    String? ingredientsJson,
    String? stepsJson,
    String? importedAt,
    int? schemaVersion,
    Value<String?> localImagePath = const Value.absent(),
  }) => Recipe(
    id: id ?? this.id,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    title: title ?? this.title,
    author: author ?? this.author,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    baseServings: baseServings.present ? baseServings.value : this.baseServings,
    prepMinutes: prepMinutes.present ? prepMinutes.value : this.prepMinutes,
    cookMinutes: cookMinutes.present ? cookMinutes.value : this.cookMinutes,
    totalMinutes: totalMinutes.present ? totalMinutes.value : this.totalMinutes,
    rating: rating.present ? rating.value : this.rating,
    ingredientsJson: ingredientsJson ?? this.ingredientsJson,
    stepsJson: stepsJson ?? this.stepsJson,
    importedAt: importedAt ?? this.importedAt,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    localImagePath: localImagePath.present
        ? localImagePath.value
        : this.localImagePath,
  );
  Recipe copyWithCompanion(RecipesCompanion data) {
    return Recipe(
      id: data.id.present ? data.id.value : this.id,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      baseServings: data.baseServings.present
          ? data.baseServings.value
          : this.baseServings,
      prepMinutes: data.prepMinutes.present
          ? data.prepMinutes.value
          : this.prepMinutes,
      cookMinutes: data.cookMinutes.present
          ? data.cookMinutes.value
          : this.cookMinutes,
      totalMinutes: data.totalMinutes.present
          ? data.totalMinutes.value
          : this.totalMinutes,
      rating: data.rating.present ? data.rating.value : this.rating,
      ingredientsJson: data.ingredientsJson.present
          ? data.ingredientsJson.value
          : this.ingredientsJson,
      stepsJson: data.stepsJson.present ? data.stepsJson.value : this.stepsJson,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      localImagePath: data.localImagePath.present
          ? data.localImagePath.value
          : this.localImagePath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Recipe(')
          ..write('id: $id, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('baseServings: $baseServings, ')
          ..write('prepMinutes: $prepMinutes, ')
          ..write('cookMinutes: $cookMinutes, ')
          ..write('totalMinutes: $totalMinutes, ')
          ..write('rating: $rating, ')
          ..write('ingredientsJson: $ingredientsJson, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('importedAt: $importedAt, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('localImagePath: $localImagePath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceUrl,
    title,
    author,
    imageUrl,
    baseServings,
    prepMinutes,
    cookMinutes,
    totalMinutes,
    rating,
    ingredientsJson,
    stepsJson,
    importedAt,
    schemaVersion,
    localImagePath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Recipe &&
          other.id == this.id &&
          other.sourceUrl == this.sourceUrl &&
          other.title == this.title &&
          other.author == this.author &&
          other.imageUrl == this.imageUrl &&
          other.baseServings == this.baseServings &&
          other.prepMinutes == this.prepMinutes &&
          other.cookMinutes == this.cookMinutes &&
          other.totalMinutes == this.totalMinutes &&
          other.rating == this.rating &&
          other.ingredientsJson == this.ingredientsJson &&
          other.stepsJson == this.stepsJson &&
          other.importedAt == this.importedAt &&
          other.schemaVersion == this.schemaVersion &&
          other.localImagePath == this.localImagePath);
}

class RecipesCompanion extends UpdateCompanion<Recipe> {
  final Value<int> id;
  final Value<String> sourceUrl;
  final Value<String> title;
  final Value<String> author;
  final Value<String?> imageUrl;
  final Value<int?> baseServings;
  final Value<int?> prepMinutes;
  final Value<int?> cookMinutes;
  final Value<int?> totalMinutes;
  final Value<double?> rating;
  final Value<String> ingredientsJson;
  final Value<String> stepsJson;
  final Value<String> importedAt;
  final Value<int> schemaVersion;
  final Value<String?> localImagePath;
  const RecipesCompanion({
    this.id = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.baseServings = const Value.absent(),
    this.prepMinutes = const Value.absent(),
    this.cookMinutes = const Value.absent(),
    this.totalMinutes = const Value.absent(),
    this.rating = const Value.absent(),
    this.ingredientsJson = const Value.absent(),
    this.stepsJson = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.localImagePath = const Value.absent(),
  });
  RecipesCompanion.insert({
    this.id = const Value.absent(),
    required String sourceUrl,
    required String title,
    required String author,
    this.imageUrl = const Value.absent(),
    this.baseServings = const Value.absent(),
    this.prepMinutes = const Value.absent(),
    this.cookMinutes = const Value.absent(),
    this.totalMinutes = const Value.absent(),
    this.rating = const Value.absent(),
    required String ingredientsJson,
    required String stepsJson,
    required String importedAt,
    required int schemaVersion,
    this.localImagePath = const Value.absent(),
  }) : sourceUrl = Value(sourceUrl),
       title = Value(title),
       author = Value(author),
       ingredientsJson = Value(ingredientsJson),
       stepsJson = Value(stepsJson),
       importedAt = Value(importedAt),
       schemaVersion = Value(schemaVersion);
  static Insertable<Recipe> custom({
    Expression<int>? id,
    Expression<String>? sourceUrl,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? imageUrl,
    Expression<int>? baseServings,
    Expression<int>? prepMinutes,
    Expression<int>? cookMinutes,
    Expression<int>? totalMinutes,
    Expression<double>? rating,
    Expression<String>? ingredientsJson,
    Expression<String>? stepsJson,
    Expression<String>? importedAt,
    Expression<int>? schemaVersion,
    Expression<String>? localImagePath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (imageUrl != null) 'image_url': imageUrl,
      if (baseServings != null) 'base_servings': baseServings,
      if (prepMinutes != null) 'prep_minutes': prepMinutes,
      if (cookMinutes != null) 'cook_minutes': cookMinutes,
      if (totalMinutes != null) 'total_minutes': totalMinutes,
      if (rating != null) 'rating': rating,
      if (ingredientsJson != null) 'ingredients_json': ingredientsJson,
      if (stepsJson != null) 'steps_json': stepsJson,
      if (importedAt != null) 'imported_at': importedAt,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (localImagePath != null) 'local_image_path': localImagePath,
    });
  }

  RecipesCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceUrl,
    Value<String>? title,
    Value<String>? author,
    Value<String?>? imageUrl,
    Value<int?>? baseServings,
    Value<int?>? prepMinutes,
    Value<int?>? cookMinutes,
    Value<int?>? totalMinutes,
    Value<double?>? rating,
    Value<String>? ingredientsJson,
    Value<String>? stepsJson,
    Value<String>? importedAt,
    Value<int>? schemaVersion,
    Value<String?>? localImagePath,
  }) {
    return RecipesCompanion(
      id: id ?? this.id,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      title: title ?? this.title,
      author: author ?? this.author,
      imageUrl: imageUrl ?? this.imageUrl,
      baseServings: baseServings ?? this.baseServings,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      cookMinutes: cookMinutes ?? this.cookMinutes,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      rating: rating ?? this.rating,
      ingredientsJson: ingredientsJson ?? this.ingredientsJson,
      stepsJson: stepsJson ?? this.stepsJson,
      importedAt: importedAt ?? this.importedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (baseServings.present) {
      map['base_servings'] = Variable<int>(baseServings.value);
    }
    if (prepMinutes.present) {
      map['prep_minutes'] = Variable<int>(prepMinutes.value);
    }
    if (cookMinutes.present) {
      map['cook_minutes'] = Variable<int>(cookMinutes.value);
    }
    if (totalMinutes.present) {
      map['total_minutes'] = Variable<int>(totalMinutes.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (ingredientsJson.present) {
      map['ingredients_json'] = Variable<String>(ingredientsJson.value);
    }
    if (stepsJson.present) {
      map['steps_json'] = Variable<String>(stepsJson.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<String>(importedAt.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (localImagePath.present) {
      map['local_image_path'] = Variable<String>(localImagePath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipesCompanion(')
          ..write('id: $id, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('baseServings: $baseServings, ')
          ..write('prepMinutes: $prepMinutes, ')
          ..write('cookMinutes: $cookMinutes, ')
          ..write('totalMinutes: $totalMinutes, ')
          ..write('rating: $rating, ')
          ..write('ingredientsJson: $ingredientsJson, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('importedAt: $importedAt, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('localImagePath: $localImagePath')
          ..write(')'))
        .toString();
  }
}

class $RecipeTagsTable extends RecipeTags
    with TableInfo<$RecipeTagsTable, RecipeTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipeTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recipeIdMeta = const VerificationMeta(
    'recipeId',
  );
  @override
  late final GeneratedColumn<int> recipeId = GeneratedColumn<int>(
    'recipe_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recipes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [recipeId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipeTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('recipe_id')) {
      context.handle(
        _recipeIdMeta,
        recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recipeId, tag};
  @override
  RecipeTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeTag(
      recipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recipe_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $RecipeTagsTable createAlias(String alias) {
    return $RecipeTagsTable(attachedDatabase, alias);
  }
}

class RecipeTag extends DataClass implements Insertable<RecipeTag> {
  final int recipeId;
  final String tag;
  const RecipeTag({required this.recipeId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['recipe_id'] = Variable<int>(recipeId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  RecipeTagsCompanion toCompanion(bool nullToAbsent) {
    return RecipeTagsCompanion(recipeId: Value(recipeId), tag: Value(tag));
  }

  factory RecipeTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeTag(
      recipeId: serializer.fromJson<int>(json['recipeId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recipeId': serializer.toJson<int>(recipeId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  RecipeTag copyWith({int? recipeId, String? tag}) =>
      RecipeTag(recipeId: recipeId ?? this.recipeId, tag: tag ?? this.tag);
  RecipeTag copyWithCompanion(RecipeTagsCompanion data) {
    return RecipeTag(
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeTag(')
          ..write('recipeId: $recipeId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recipeId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeTag &&
          other.recipeId == this.recipeId &&
          other.tag == this.tag);
}

class RecipeTagsCompanion extends UpdateCompanion<RecipeTag> {
  final Value<int> recipeId;
  final Value<String> tag;
  final Value<int> rowid;
  const RecipeTagsCompanion({
    this.recipeId = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipeTagsCompanion.insert({
    required int recipeId,
    required String tag,
    this.rowid = const Value.absent(),
  }) : recipeId = Value(recipeId),
       tag = Value(tag);
  static Insertable<RecipeTag> custom({
    Expression<int>? recipeId,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recipeId != null) 'recipe_id': recipeId,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipeTagsCompanion copyWith({
    Value<int>? recipeId,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return RecipeTagsCompanion(
      recipeId: recipeId ?? this.recipeId,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recipeId.present) {
      map['recipe_id'] = Variable<int>(recipeId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipeTagsCompanion(')
          ..write('recipeId: $recipeId, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShoppingItemsTable extends ShoppingItems
    with TableInfo<$ShoppingItemsTable, ShoppingItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, content, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShoppingItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
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
  ShoppingItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ShoppingItemsTable createAlias(String alias) {
    return $ShoppingItemsTable(attachedDatabase, alias);
  }
}

class ShoppingItem extends DataClass implements Insertable<ShoppingItem> {
  final int id;
  final String content;
  final String createdAt;
  const ShoppingItem({
    required this.id,
    required this.content,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  ShoppingItemsCompanion toCompanion(bool nullToAbsent) {
    return ShoppingItemsCompanion(
      id: Value(id),
      content: Value(content),
      createdAt: Value(createdAt),
    );
  }

  factory ShoppingItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingItem(
      id: serializer.fromJson<int>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  ShoppingItem copyWith({int? id, String? content, String? createdAt}) =>
      ShoppingItem(
        id: id ?? this.id,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
      );
  ShoppingItem copyWithCompanion(ShoppingItemsCompanion data) {
    return ShoppingItem(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItem(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, content, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingItem &&
          other.id == this.id &&
          other.content == this.content &&
          other.createdAt == this.createdAt);
}

class ShoppingItemsCompanion extends UpdateCompanion<ShoppingItem> {
  final Value<int> id;
  final Value<String> content;
  final Value<String> createdAt;
  const ShoppingItemsCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ShoppingItemsCompanion.insert({
    this.id = const Value.absent(),
    required String content,
    required String createdAt,
  }) : content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<ShoppingItem> custom({
    Expression<int>? id,
    Expression<String>? content,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ShoppingItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? content,
    Value<String>? createdAt,
  }) {
    return ShoppingItemsCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItemsCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RecipesTable recipes = $RecipesTable(this);
  late final $RecipeTagsTable recipeTags = $RecipeTagsTable(this);
  late final $ShoppingItemsTable shoppingItems = $ShoppingItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    recipes,
    recipeTags,
    shoppingItems,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recipes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recipe_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$RecipesTableCreateCompanionBuilder =
    RecipesCompanion Function({
      Value<int> id,
      required String sourceUrl,
      required String title,
      required String author,
      Value<String?> imageUrl,
      Value<int?> baseServings,
      Value<int?> prepMinutes,
      Value<int?> cookMinutes,
      Value<int?> totalMinutes,
      Value<double?> rating,
      required String ingredientsJson,
      required String stepsJson,
      required String importedAt,
      required int schemaVersion,
      Value<String?> localImagePath,
    });
typedef $$RecipesTableUpdateCompanionBuilder =
    RecipesCompanion Function({
      Value<int> id,
      Value<String> sourceUrl,
      Value<String> title,
      Value<String> author,
      Value<String?> imageUrl,
      Value<int?> baseServings,
      Value<int?> prepMinutes,
      Value<int?> cookMinutes,
      Value<int?> totalMinutes,
      Value<double?> rating,
      Value<String> ingredientsJson,
      Value<String> stepsJson,
      Value<String> importedAt,
      Value<int> schemaVersion,
      Value<String?> localImagePath,
    });

final class $$RecipesTableReferences
    extends BaseReferences<_$AppDatabase, $RecipesTable, Recipe> {
  $$RecipesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RecipeTagsTable, List<RecipeTag>>
  _recipeTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recipeTags,
    aliasName: 'recipes__id__recipe_tags__recipe_id',
  );

  $$RecipeTagsTableProcessedTableManager get recipeTagsRefs {
    final manager = $$RecipeTagsTableTableManager(
      $_db,
      $_db.recipeTags,
    ).filter((f) => f.recipeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_recipeTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecipesTableFilterComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseServings => $composableBuilder(
    column: $table.baseServings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get prepMinutes => $composableBuilder(
    column: $table.prepMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cookMinutes => $composableBuilder(
    column: $table.cookMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalMinutes => $composableBuilder(
    column: $table.totalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ingredientsJson => $composableBuilder(
    column: $table.ingredientsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> recipeTagsRefs(
    Expression<bool> Function($$RecipeTagsTableFilterComposer f) f,
  ) {
    final $$RecipeTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipeTags,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeTagsTableFilterComposer(
            $db: $db,
            $table: $db.recipeTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecipesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseServings => $composableBuilder(
    column: $table.baseServings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get prepMinutes => $composableBuilder(
    column: $table.prepMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cookMinutes => $composableBuilder(
    column: $table.cookMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalMinutes => $composableBuilder(
    column: $table.totalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ingredientsJson => $composableBuilder(
    column: $table.ingredientsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecipesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<int> get baseServings => $composableBuilder(
    column: $table.baseServings,
    builder: (column) => column,
  );

  GeneratedColumn<int> get prepMinutes => $composableBuilder(
    column: $table.prepMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cookMinutes => $composableBuilder(
    column: $table.cookMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalMinutes => $composableBuilder(
    column: $table.totalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get ingredientsJson => $composableBuilder(
    column: $table.ingredientsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stepsJson =>
      $composableBuilder(column: $table.stepsJson, builder: (column) => column);

  GeneratedColumn<String> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => column,
  );

  Expression<T> recipeTagsRefs<T extends Object>(
    Expression<T> Function($$RecipeTagsTableAnnotationComposer a) f,
  ) {
    final $$RecipeTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipeTags,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.recipeTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecipesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipesTable,
          Recipe,
          $$RecipesTableFilterComposer,
          $$RecipesTableOrderingComposer,
          $$RecipesTableAnnotationComposer,
          $$RecipesTableCreateCompanionBuilder,
          $$RecipesTableUpdateCompanionBuilder,
          (Recipe, $$RecipesTableReferences),
          Recipe,
          PrefetchHooks Function({bool recipeTagsRefs})
        > {
  $$RecipesTableTableManager(_$AppDatabase db, $RecipesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<int?> baseServings = const Value.absent(),
                Value<int?> prepMinutes = const Value.absent(),
                Value<int?> cookMinutes = const Value.absent(),
                Value<int?> totalMinutes = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<String> ingredientsJson = const Value.absent(),
                Value<String> stepsJson = const Value.absent(),
                Value<String> importedAt = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String?> localImagePath = const Value.absent(),
              }) => RecipesCompanion(
                id: id,
                sourceUrl: sourceUrl,
                title: title,
                author: author,
                imageUrl: imageUrl,
                baseServings: baseServings,
                prepMinutes: prepMinutes,
                cookMinutes: cookMinutes,
                totalMinutes: totalMinutes,
                rating: rating,
                ingredientsJson: ingredientsJson,
                stepsJson: stepsJson,
                importedAt: importedAt,
                schemaVersion: schemaVersion,
                localImagePath: localImagePath,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceUrl,
                required String title,
                required String author,
                Value<String?> imageUrl = const Value.absent(),
                Value<int?> baseServings = const Value.absent(),
                Value<int?> prepMinutes = const Value.absent(),
                Value<int?> cookMinutes = const Value.absent(),
                Value<int?> totalMinutes = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                required String ingredientsJson,
                required String stepsJson,
                required String importedAt,
                required int schemaVersion,
                Value<String?> localImagePath = const Value.absent(),
              }) => RecipesCompanion.insert(
                id: id,
                sourceUrl: sourceUrl,
                title: title,
                author: author,
                imageUrl: imageUrl,
                baseServings: baseServings,
                prepMinutes: prepMinutes,
                cookMinutes: cookMinutes,
                totalMinutes: totalMinutes,
                rating: rating,
                ingredientsJson: ingredientsJson,
                stepsJson: stepsJson,
                importedAt: importedAt,
                schemaVersion: schemaVersion,
                localImagePath: localImagePath,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecipesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (recipeTagsRefs) db.recipeTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (recipeTagsRefs)
                    await $_getPrefetchedData<Recipe, $RecipesTable, RecipeTag>(
                      currentTable: table,
                      referencedTable: $$RecipesTableReferences
                          ._recipeTagsRefsTable(db),
                      managerFromTypedResult: (p0) => $$RecipesTableReferences(
                        db,
                        table,
                        p0,
                      ).recipeTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.recipeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RecipesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipesTable,
      Recipe,
      $$RecipesTableFilterComposer,
      $$RecipesTableOrderingComposer,
      $$RecipesTableAnnotationComposer,
      $$RecipesTableCreateCompanionBuilder,
      $$RecipesTableUpdateCompanionBuilder,
      (Recipe, $$RecipesTableReferences),
      Recipe,
      PrefetchHooks Function({bool recipeTagsRefs})
    >;
typedef $$RecipeTagsTableCreateCompanionBuilder =
    RecipeTagsCompanion Function({
      required int recipeId,
      required String tag,
      Value<int> rowid,
    });
typedef $$RecipeTagsTableUpdateCompanionBuilder =
    RecipeTagsCompanion Function({
      Value<int> recipeId,
      Value<String> tag,
      Value<int> rowid,
    });

final class $$RecipeTagsTableReferences
    extends BaseReferences<_$AppDatabase, $RecipeTagsTable, RecipeTag> {
  $$RecipeTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.recipes.createAlias('recipe_tags__recipe_id__recipes__id');

  $$RecipesTableProcessedTableManager get recipeId {
    final $_column = $_itemColumn<int>('recipe_id')!;

    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecipeTagsTableFilterComposer
    extends Composer<_$AppDatabase, $RecipeTagsTable> {
  $$RecipeTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  $$RecipesTableFilterComposer get recipeId {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipeTagsTable> {
  $$RecipeTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecipesTableOrderingComposer get recipeId {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableOrderingComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipeTagsTable> {
  $$RecipeTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  $$RecipesTableAnnotationComposer get recipeId {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipeTagsTable,
          RecipeTag,
          $$RecipeTagsTableFilterComposer,
          $$RecipeTagsTableOrderingComposer,
          $$RecipeTagsTableAnnotationComposer,
          $$RecipeTagsTableCreateCompanionBuilder,
          $$RecipeTagsTableUpdateCompanionBuilder,
          (RecipeTag, $$RecipeTagsTableReferences),
          RecipeTag,
          PrefetchHooks Function({bool recipeId})
        > {
  $$RecipeTagsTableTableManager(_$AppDatabase db, $RecipeTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipeTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipeTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipeTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> recipeId = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipeTagsCompanion(
                recipeId: recipeId,
                tag: tag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int recipeId,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => RecipeTagsCompanion.insert(
                recipeId: recipeId,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecipeTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeId = false}) {
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
                    if (recipeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.recipeId,
                                referencedTable: $$RecipeTagsTableReferences
                                    ._recipeIdTable(db),
                                referencedColumn: $$RecipeTagsTableReferences
                                    ._recipeIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$RecipeTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipeTagsTable,
      RecipeTag,
      $$RecipeTagsTableFilterComposer,
      $$RecipeTagsTableOrderingComposer,
      $$RecipeTagsTableAnnotationComposer,
      $$RecipeTagsTableCreateCompanionBuilder,
      $$RecipeTagsTableUpdateCompanionBuilder,
      (RecipeTag, $$RecipeTagsTableReferences),
      RecipeTag,
      PrefetchHooks Function({bool recipeId})
    >;
typedef $$ShoppingItemsTableCreateCompanionBuilder =
    ShoppingItemsCompanion Function({
      Value<int> id,
      required String content,
      required String createdAt,
    });
typedef $$ShoppingItemsTableUpdateCompanionBuilder =
    ShoppingItemsCompanion Function({
      Value<int> id,
      Value<String> content,
      Value<String> createdAt,
    });

class $$ShoppingItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShoppingItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShoppingItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ShoppingItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShoppingItemsTable,
          ShoppingItem,
          $$ShoppingItemsTableFilterComposer,
          $$ShoppingItemsTableOrderingComposer,
          $$ShoppingItemsTableAnnotationComposer,
          $$ShoppingItemsTableCreateCompanionBuilder,
          $$ShoppingItemsTableUpdateCompanionBuilder,
          (
            ShoppingItem,
            BaseReferences<_$AppDatabase, $ShoppingItemsTable, ShoppingItem>,
          ),
          ShoppingItem,
          PrefetchHooks Function()
        > {
  $$ShoppingItemsTableTableManager(_$AppDatabase db, $ShoppingItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => ShoppingItemsCompanion(
                id: id,
                content: content,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String content,
                required String createdAt,
              }) => ShoppingItemsCompanion.insert(
                id: id,
                content: content,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShoppingItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShoppingItemsTable,
      ShoppingItem,
      $$ShoppingItemsTableFilterComposer,
      $$ShoppingItemsTableOrderingComposer,
      $$ShoppingItemsTableAnnotationComposer,
      $$ShoppingItemsTableCreateCompanionBuilder,
      $$ShoppingItemsTableUpdateCompanionBuilder,
      (
        ShoppingItem,
        BaseReferences<_$AppDatabase, $ShoppingItemsTable, ShoppingItem>,
      ),
      ShoppingItem,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RecipesTableTableManager get recipes =>
      $$RecipesTableTableManager(_db, _db.recipes);
  $$RecipeTagsTableTableManager get recipeTags =>
      $$RecipeTagsTableTableManager(_db, _db.recipeTags);
  $$ShoppingItemsTableTableManager get shoppingItems =>
      $$ShoppingItemsTableTableManager(_db, _db.shoppingItems);
}
