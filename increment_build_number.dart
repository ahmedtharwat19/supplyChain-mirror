/* import 'dart:io';
import 'dart:developer' as developer;

void main() {
  final pubspecFile = File('pubspec.yaml');

  if (!pubspecFile.existsSync()) {
    developer.log('pubspec.yaml not found!', level: 1000); // Error level
    exit(1);
  }

  final lines = pubspecFile.readAsLinesSync();
  final versionIndex = lines.indexWhere((line) => line.trim().startsWith('version:'));

  if (versionIndex == -1) {
    developer.log('No version field found in pubspec.yaml', level: 900); // Warning level
    exit(1);
  }

  final versionLine = lines[versionIndex];
  final regex = RegExp(r'version:\s*([\d\.]+)\+(\d+)');
  final match = regex.firstMatch(versionLine);

  if (match == null) {
    developer.log('Version line format is incorrect: $versionLine', level: 900);
    exit(1);
  }

  final versionName = match.group(1)!;
  final currentBuild = int.parse(match.group(2)!);
  final nextBuild = currentBuild + 1;

  final updatedLine = 'version: $versionName+$nextBuild';
  lines[versionIndex] = updatedLine;

  pubspecFile.writeAsStringSync(lines.join('\n'));

  developer.log('✅ Updated version: $updatedLine');
}
 */
/* 
import 'dart:io';
import 'dart:developer' as developer;

void main() {
  final pubspecFile = File('pubspec.yaml');

  if (!pubspecFile.existsSync()) {
    developer.log('❌ pubspec.yaml not found!');
    exit(1);
  }

  final lines = pubspecFile.readAsLinesSync();
  final versionIndex = lines.indexWhere((line) => line.trim().startsWith('version:'));

  if (versionIndex == -1) {
    developer.log('❌ version field not found in pubspec.yaml');
    exit(1);
  }

  final versionLine = lines[versionIndex];
  final regex = RegExp(r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)');
  final match = regex.firstMatch(versionLine);

  if (match == null) {
    developer.log('❌ version format is incorrect: $versionLine');
    exit(1);
  }

  int major = int.parse(match.group(1)!);
  int minor = int.parse(match.group(2)!);
  int patch = int.parse(match.group(3)!);
  int build = int.parse(match.group(4)!);

  // ⬆️ زيادة build number
  build += 1;

  // ⬆️ زيادة patch كل 10 builds
  if (build >= 10) {
    build = 0;
    patch += 1;

    // ⬆️ زيادة minor كل 10 patch
    if (patch >= 10) {
      patch = 0;
      minor += 1;

      // ⬆️ زيادة major كل 10 minor
      if (minor >= 10) {
        minor = 0;
        major += 1;
      }
    }
  }

  final newVersion = '$major.$minor.$patch+$build';
  lines[versionIndex] = 'version: $newVersion';

  pubspecFile.writeAsStringSync(lines.join('\n'));

  developer.log('✅ Updated version to $newVersion');
}
 */
import 'dart:io';
import 'dart:developer' as developer;

void main() {
  final pubspecFile = File('pubspec.yaml');

  if (!pubspecFile.existsSync()) {
    developer.log('❌ pubspec.yaml not found!');
    exit(1);
  }

  final lines = pubspecFile.readAsLinesSync();
  final versionIndex = lines.indexWhere((line) => line.trim().startsWith('version:'));

  if (versionIndex == -1) {
    developer.log('❌ version field not found in pubspec.yaml');
    exit(1);
  }

  final versionLine = lines[versionIndex];
  final pattern = r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)';
  final matches = pattern.allMatches(versionLine);

  if (matches.isEmpty) {
    developer.log('❌ version format is incorrect: $versionLine');
    exit(1);
  }

  final match = matches.first;
  int major = int.parse(match.group(1)!);
  int minor = int.parse(match.group(2)!);
  int patch = int.parse(match.group(3)!);
  int build = int.parse(match.group(4)!);

  // زيادة build number
  build += 1;

  // زيادة patch كل 10 builds
  if (build >= 10) {
    build = 0;
    patch += 1;

    // زيادة minor كل 10 patch
    if (patch >= 10) {
      patch = 0;
      minor += 1;

      // زيادة major كل 10 minor
      if (minor >= 10) {
        minor = 0;
        major += 1;
      }
    }
  }

  final newVersion = '$major.$minor.$patch+$build';
  lines[versionIndex] = 'version: $newVersion';
  pubspecFile.writeAsStringSync(lines.join('\n'));

  developer.log('✅ Updated version to $newVersion');
}