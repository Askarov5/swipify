import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/core/native_gallery_helper.dart';

import 'support/gallery_channel_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeGalleryHelper (mocked channel)', () {
    test('fetchLibraryMetadata maps native payloads to SwipifyPhoto', () async {
      final mock = GalleryChannelMock(
        fetchLibraryMetadataResponse: [
          {
            'id': 'asset-a',
            'creationTime': 1700000000000,
            'isVideo': false,
          },
          {
            'id': 'asset-b',
            'creationTime': 1700008640000,
            'isVideo': true,
          },
        ],
      )..register();
      addTearDown(mock.unregister);

      final list = await NativeGalleryHelper.fetchLibraryMetadata();
      expect(list, hasLength(2));
      expect(list[0].id, 'asset-a');
      expect(list[0].isVideo, false);
      expect(list[1].id, 'asset-b');
      expect(list[1].isVideo, true);
    });

    test('checkPermission returns mocked status string', () async {
      final mock = GalleryChannelMock(checkPermissionResponse: 'denied')
        ..register();
      addTearDown(mock.unregister);

      expect(await NativeGalleryHelper.checkPermission(), 'denied');
    });

    test('requestPermission returns mocked status string', () async {
      final mock = GalleryChannelMock(requestPermissionResponse: 'authorized')
        ..register();
      addTearDown(mock.unregister);

      expect(await NativeGalleryHelper.requestPermission(), 'authorized');
    });

    test('deletePhotos returns mocked bool', () async {
      final mock = GalleryChannelMock(deletePhotosResponse: false)..register();
      addTearDown(mock.unregister);

      expect(await NativeGalleryHelper.deletePhotos(['x']), false);
    });
  });
}
