import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart';
import 'package:source_gen/source_gen.dart';

import 'dependency_config.dart';
import 'generator/config_code_generator.dart';
import 'utils.dart';

final _microPackageRootInit = const TypeChecker.fromRuntime(MicroPackageRootInit);

class InjectableConfigGenerator extends GeneratorForAnnotation<InjectableInit> {
  @override
  dynamic generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) async {
    final generateForDir = annotation.read('generateForDir').listValue.map((e) => e.toStringValue());

    var targetFile = element.source.uri;
    var preferRelativeImports = (annotation.peek("preferRelativeImports")?.boolValue ?? true == true);
    var isMicroPackageRoot = annotation.instanceOf(_microPackageRootInit);


    final dirPattern = generateForDir.length > 1 ? '{${generateForDir.join(',')}}' : '${generateForDir.first}';
    final injectableConfigFiles = Glob("$dirPattern/**.injectable.json");

    final jsonData = <Map>[];
    await for (final id in buildStep.findAssets(injectableConfigFiles)) {
      final json = jsonDecode(await buildStep.readAsString(id));
      jsonData.addAll([...json]);
    }

    final deps = <DependencyConfig>[];
    jsonData.forEach((json) => deps.add(DependencyConfig.fromJson(json)));

    final initializerName = annotation.read('initializerName').stringValue;
    final asExtension = annotation.read('asExtension').boolValue;

    _reportMissingDependencies(deps, targetFile);
    _validateDuplicateDependencies(deps);
    return ConfigCodeGenerator(
      deps,
      targetFile: preferRelativeImports ? targetFile : null,
      initializerName: initializerName,
      asExtension: asExtension,
      isMicroPackageRoot: isMicroPackageRoot
    ).generate();
  }

  void _reportMissingDependencies(List<DependencyConfig> deps, Uri targetFile) {
    final messages = [];
    final registeredDeps = deps.map((dep) => dep.type).toSet();
    deps.forEach((dep) {
      dep.dependencies
          .where((d) => !d.isFactoryParam && d.name != kEnvironmentsName)
          .forEach((iDep) {
        if (!registeredDeps.contains(iDep.type)) {
          messages.add(
              "[${dep.typeImpl}] depends on unregistered type [${iDep.type}] ${iDep.type.import == null ? '' : 'from ${iDep.type.import}'}");
        }
      });
    });

    if (messages.isNotEmpty) {
      messages.add(
          '\nDid you forget to annotate the above classe(s) or their implementation with @injectable?');
      printBoxed(messages.join('\n'),
          header: "Missing dependencies in ${targetFile.path}\n");
    }
  }

  void _validateDuplicateDependencies(List<DependencyConfig> deps) {
    final validatedDeps = <DependencyConfig>[];
    for (var dep in deps) {
      var registered = validatedDeps.where((elm) =>
      elm.type == dep.type && elm.instanceName == dep.instanceName);
      if (registered.isEmpty) {
        validatedDeps.add(dep);
      } else {
        Set<String> registeredEnvironments = registered
            .fold(<String>{}, (prev, elm) => prev..addAll(elm.environments));
        if (registeredEnvironments.isEmpty ||
            dep.environments
                .any((env) => registeredEnvironments.contains(env))) {
          throwBoxed(
              '${dep.typeImpl} [${dep.type}] env: ${dep.environments} \nis registered more than once under the same environment');
        }
      }
    }
  }
}
