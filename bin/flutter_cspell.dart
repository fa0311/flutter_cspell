import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_cspell_cli/dart_cspell_cli.dart';
import 'package:pub_api_client/pub_api_client.dart';

void main(List<String> arguments) async {
  final parser = ArgParser();
  parser.addOption('output', abbr: 'o');
  final results = parser.parse(arguments);
  final output = results["output"];
  final writer = output != null ? File(output).openWrite() : stdout;

  final client = PubClient();

  final resFuture = List.generate(100, (index) => index).map((page) {
    return client.search(
      '',
      page: page,
      sort: SearchOrder.popularity,
    );
  });
  final res = await Future.wait(resFuture);

  final names = res.expand((r) => r.packages).map((p) => p.package).toList();

  final diff = normalize(names).toSet();

  writer.writeAll(diff.toList(), "\n");
}
