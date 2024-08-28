import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';

List<String> extractTopLevelNames(Iterable<SyntacticEntity> node) {
  final names = <String>[];
  for (final entity in node) {
    switch (entity) {
      case TopLevelVariableDeclaration():
        names.addAll(entity.childEntities
            .whereType<VariableDeclarationList>()
            .expand((e) => e.variables.map((e) => e.name.lexeme)));
      case FunctionDeclaration():
        names.add(entity.name.lexeme);
      case ClassDeclaration():
        names.add(entity.name.lexeme);
        names.addAll(extractConstructorNames(entity.childEntities));
      case MethodDeclaration():
        names.add(entity.name.lexeme);
      case EnumDeclaration():
        names.add(entity.name.lexeme);
        names.addAll(entity.childEntities
            .whereType<EnumConstantDeclaration>()
            .map((e) => e.name.lexeme));
      case GenericTypeAlias():
        names.add(entity.name.lexeme);
      case _:
      // print("not implemented ${entity.runtimeType}");
    }
  }
  return names;
}

List<String> extractConstructorNames(Iterable<SyntacticEntity> node) {
  final names = <String>[];
  for (final entity in node) {
    switch (entity) {
      case ConstructorDeclaration():
        names.addAll(entity.childEntities
            .whereType<FormalParameterList>()
            .expand((e) => e.childEntities
                .whereType<DefaultFormalParameter>()
                .map((e) => e.name!.lexeme)));
      case MethodDeclaration():
        names.add(entity.name.lexeme);
        names.addAll(entity.childEntities
            .whereType<FormalParameterList>()
            .expand((e) => e.childEntities
                .whereType<SimpleFormalParameter>()
                .map((e) => e.name!.lexeme)));
      case FieldDeclaration():
        names.addAll(entity.childEntities
            .whereType<VariableDeclarationList>()
            .expand((e) => e.variables.map((e) => e.name.lexeme)));

      case _:
      // print("not implemented ${entity.runtimeType}");
    }
  }
  return names;
}

List<String> filterNames(List<String> names) {
  return names.where((e) => !e.startsWith("_")).toList();
}

List<String> removeNumbers(List<String> names) {
  return names.map((e) => e.replaceAll(RegExp(r"\d"), "")).toList();
}

List<String> split(List<String> names) {
  final result = <List<String>>[];

  for (final name in names) {
    result.add([]);
    for (final c in name.split("")) {
      if (["_", "-", " "].contains(c)) {
        result.add([]);
      } else if (c.toUpperCase() == c) {
        result.add([c.toLowerCase()]);
      } else {
        result.last.add(c);
      }
    }
  }

  return result.map((e) => e.join("")).toList();
}

void toFile(List<String> names) {
  final file = File("flutter_cspell.txt");
  file.writeAsStringSync(names.join("\n"));
}

List<String> remove(List<String> names) {
  return names.where((e) => e.length > 4).toList();
}

void main(List<String> arguments) {
  final dartFile = Glob("flutter/packages/flutter/lib/**.dart");
  // final dartFile = Glob("flutter/packages/flutter/lib/src/material/icons.dart");
  // final dartFile = Glob(
  //     "flutter/packages/flutter/lib/src/animation/animation_controller.dart");
  final root = ".";
  final names = <String>[];

  for (final entity in dartFile.listSync(root: root)) {
    if (entity is File) {
      final result = parseFile(
        path: File(entity.path.substring(root.length + 1)).absolute.path,
        featureSet: FeatureSet.latestLanguageVersion(),
      );
      names.addAll(extractTopLevelNames(result.unit.childEntities));
    }
  }

  final res = remove(split(removeNumbers(filterNames(names)))).toSet().toList();
  toFile(res);
}
