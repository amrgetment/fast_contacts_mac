import 'package:flutter_test/flutter_test.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:fast_contacts/fast_contacts_platform_interface.dart';
import 'package:fast_contacts/fast_contacts_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFastContactsPlatform
    with MockPlatformInterfaceMixin
    implements FastContactsPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FastContactsPlatform initialPlatform = FastContactsPlatform.instance;

  test('$MethodChannelFastContacts is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFastContacts>());
  });

  test('getPlatformVersion', () async {
    FastContacts fastContactsPlugin = FastContacts();
    MockFastContactsPlatform fakePlatform = MockFastContactsPlatform();
    FastContactsPlatform.instance = fakePlatform;

    expect(await fastContactsPlugin.getPlatformVersion(), '42');
  });
}
