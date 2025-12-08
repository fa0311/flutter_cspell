import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:dart_cspell_cli/dart_cspell_cli.dart';
import 'package:pub_api_client/pub_api_client.dart';

Future<T> retryWithExponentialBackoff<T>(
  Future<T> Function() operation, {
  int maxRetries = 5,
  int initialDelayMs = 500,
}) async {
  final retry = List.generate(
    maxRetries,
    (index) => initialDelayMs * pow(2, index),
  );
  for (final i in retry) {
    try {
      return await operation();
    } catch (e) {
      await Future.delayed(Duration(milliseconds: i.toInt()));
    }
  }
  throw Exception('Operation failed after $maxRetries retries');
}

Future<List<T>> syncFutureList<T>(List<Future<T> Function()> operations) async {
  final results = <T>[];
  for (final operation in operations) {
    final result = await operation();
    results.add(result);
  }
  return results;
}

void main(List<String> arguments) async {
  final parser = ArgParser();
  parser.addOption('output', abbr: 'o');
  final results = parser.parse(arguments);
  final output = results["output"];
  final writer = output != null ? File(output).openWrite() : stdout;

  final client = PubClient();
  final res = await syncFutureList([
    for (final i in List.generate(100, (index) => index))
      () async {
        print('Fetching page $i');
        final res = await retryWithExponentialBackoff(() async {
          return await client.search(
            '',
            page: i,
            sort: SearchOrder.popularity,
          );
        });
        await Future.delayed(Duration(milliseconds: 200));
        return res;
      }
  ]);

  final names = res.expand((r) => r.packages).map((p) => p.package).toList();

  final diff = normalize(names).toSet();

  writer.writeAll(diff.toList(), "\n");
}
