import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'package:kwaainet_gui/src/daemon/config_file.dart';

/// Apply [snap] to [yaml] and read the result back.
YamlMap _write(String yaml, ConfigSnapshot snap) {
  final editor = YamlEditor(yaml);
  ConfigFile.apply(editor, snap);
  return loadYaml(editor.toString()) as YamlMap;
}

ConfigSnapshot _read(String yaml) =>
    ConfigFile.parse(loadYaml(yaml) as YamlMap);

void main() {
  test('an absent contribute.shards reads as off, as the daemon treats it', () {
    expect(_read('model: m\n').shardingEnabled, isFalse);
    expect(_read('contribute:\n  shards: true\n').shardingEnabled, isTrue);
  });

  test('serving keys round-trip', () {
    final snap = _read('model: m\n').copyWith(
      blocks: 16,
      useGpu: false,
      shardBackend: ShardBackend.mlx,
      autoRebalance: true,
      rebalanceIntervalSecs: 600,
      rebalanceMinRedundancy: 2,
      forwardChainServe: false,
      publicName: 'my-node',
      vpkEnabled: true,
      vpkMode: VpkMode.eve,
    );
    final back = ConfigFile.parse(_write('model: m\n', snap));
    expect(back.blocks, 16);
    expect(back.useGpu, isFalse);
    expect(back.shardBackend, ShardBackend.mlx);
    expect(back.autoRebalance, isTrue);
    expect(back.rebalanceIntervalSecs, 600);
    expect(back.rebalanceMinRedundancy, 2);
    expect(back.forwardChainServe, isFalse);
    expect(back.publicName, 'my-node');
    expect(back.vpkEnabled, isTrue);
    expect(back.vpkMode, VpkMode.eve);
  });

  test(
    'defaults are left out of the file, and set back to default removes',
    () {
      const set =
          'model: m\nblocks: 16\nuse_gpu: false\n'
          'shard:\n  backend: mlx\n  forward_chain:\n    serve: false\n'
          'auto_rebalance: true\npublic_name: n\nvpk_enabled: true\n'
          'vpk_mode: bob\n';
      final reset = _read(set).copyWith(
        blocks: null,
        useGpu: true,
        shardBackend: ShardBackend.auto,
        forwardChainServe: true,
        autoRebalance: false,
        publicName: '',
        vpkEnabled: false,
        vpkMode: null,
      );
      final doc = _write(set, reset);
      for (final key in [
        'blocks',
        'use_gpu',
        'auto_rebalance',
        'public_name',
        'vpk_enabled',
        'vpk_mode',
      ]) {
        expect(doc.containsKey(key), isFalse, reason: key);
      }
      final shard = doc['shard'] as YamlMap;
      expect(shard.containsKey('backend'), isFalse);
      expect((shard['forward_chain'] as YamlMap).containsKey('serve'), isFalse);
    },
  );

  group('start_block', () {
    test('an auto-assigned range is written back as auto', () {
      const yaml = 'start_block: 8\nstart_block_auto: true\n';
      final doc = _write(yaml, _read(yaml));
      expect(doc['start_block'], 8);
      expect(doc['start_block_auto'], isTrue);
    });

    test('typing a start block pins it, so the rebalancer leaves it', () {
      const yaml = 'start_block: 8\nstart_block_auto: true\n';
      final pinned = _read(yaml)
          .copyWith(startBlock: 16, startBlockAuto: false);
      final doc = _write(yaml, pinned);
      expect(doc['start_block'], 16);
      expect(doc.containsKey('start_block_auto'), isFalse);
    });

    test('clearing it removes both keys, so the node is placed again', () {
      const yaml = 'start_block: 8\nstart_block_auto: true\n';
      final doc = _write(yaml, _read(yaml).copyWith(startBlock: null));
      expect(doc.containsKey('start_block'), isFalse);
      expect(doc.containsKey('start_block_auto'), isFalse);
    });

    test('0 is a pin, not "unset"', () {
      final doc = _write('{}\n', _read('{}\n').copyWith(startBlock: 0));
      expect(doc['start_block'], 0);
    });
  });

  group('storage.data_dir', () {
    test('is written into an initialised storage section', () {
      const yaml = 'storage:\n  data_dir: /a\n  capacity_gb: 10\n';
      final doc = _write(yaml, _read(yaml).copyWith(storageDataDir: '/b'));
      expect((doc['storage'] as YamlMap)['data_dir'], '/b');
    });

    test(
      'never creates the section, which would fake an initialised store',
      () {
        final doc = _write(
          'model: m\n',
          _read('model: m\n').copyWith(storageDataDir: '/b'),
        );
        expect(doc.containsKey('storage'), isFalse);
      },
    );
  });

  group('chat keys', () {
    test('round-trip and are left out at their defaults', () {
      final editor = YamlEditor('model: m\n');
      ConfigFile.applyChat(
        editor,
        const ChatConfig(maxTokens: 512, forwardChainOriginate: true),
      );
      var chat = ConfigFile.parseChat(loadYaml(editor.toString()) as YamlMap);
      expect(chat.maxTokens, 512);
      expect(chat.forwardChainOriginate, isTrue);

      ConfigFile.applyChat(editor, const ChatConfig());
      final doc = loadYaml(editor.toString()) as YamlMap;
      chat = ConfigFile.parseChat(doc);
      expect(chat.maxTokens, isNull);
      expect(chat.forwardChainOriginate, isFalse);
      expect((doc['shard'] as YamlMap).containsKey('max_tokens'), isFalse);
      expect(doc['model'], 'm', reason: 'other keys are untouched');
    });

    test('a hand-written 0 reads as the default, as the daemon reads it', () {
      final doc = loadYaml('shard:\n  max_tokens: 0\n') as YamlMap;
      expect(ConfigFile.parseChat(doc).maxTokens, isNull);
    });

    test('a Contribute apply does not touch them', () {
      const yaml =
          'shard:\n  max_tokens: 64\n  forward_chain:\n'
          '    originate: true\n';
      final doc = _write(yaml, _read(yaml));
      final chat = ConfigFile.parseChat(doc);
      expect(chat.maxTokens, 64);
      expect(chat.forwardChainOriginate, isTrue);
    });
  });
}
