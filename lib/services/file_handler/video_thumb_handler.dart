import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:vocechat_client/app.dart';
import 'package:vocechat_client/dao/init_dao/chat_msg.dart';
import 'package:vocechat_client/services/file_handler/voce_file_handler.dart';
import 'package:vocechat_client/shared_funcs.dart';

class VideoThumbHandler extends VoceFileHandler {
  static const String _pathStr = "video_thumb";

  /// Constructor
  ///
  /// File name should be generated by [generateFileName],
  /// format: gid.png
  VideoThumbHandler() : super();

  /// [chatId] is required.
  @override
  Future<String> filePath(String fileName,
      {String? chatId, String? dbName}) async {
    final directory = await getApplicationDocumentsDirectory();
    final databaseName = dbName ?? App.app.userDb?.dbName;
    try {
      if (databaseName != null && databaseName.isNotEmpty) {
        return "${directory.path}/file/${App.app.userDb!.dbName}/$chatId/$_pathStr/$fileName";
      }
    } catch (e) {
      App.logger.severe(e);
    }
    return "";
  }

  static String generateFileName(ChatMsgM chatMsgM) {
    return "${chatMsgM.localMid}.jpg";
  }

  /// Read file from local storage, if not exist, fetch from server.
  Future<File?> readOrFetch(ChatMsgM chatMsgM,
      {String? dbName, bool enableServerRetry = false}) async {
    final fileName = generateFileName(chatMsgM);
    final chatId =
        SharedFuncs.getChatId(gid: chatMsgM.gid, uid: chatMsgM.dmUid);
    final file = await read(fileName, chatId: chatId, dbName: dbName);
    if (file != null && await file.exists() && (await file.length()) > 0) {
      App.logger.info("Thumb fetched locally.");
      return file;
    }

    try {
      final serverFilePath = chatMsgM.msgNormal?.content ?? "";

      if (serverFilePath.isEmpty || chatId == null || chatId.isEmpty) {
        return null;
      }

      final fileUrl =
          "${App.app.chatServerM.fullUrl}/api/resource/file?file_path=$serverFilePath&thumbnail=false&download=false";
      final path = await filePath(generateFileName(chatMsgM),
          chatId: chatId, dbName: dbName);
      await File(path).create(recursive: true);

      final fileName = await VideoThumbnail.thumbnailFile(
        video: fileUrl,
        thumbnailPath: path,
        imageFormat: ImageFormat.JPEG,
        maxHeight:
            64, // specify the height of the thumbnail, let the width auto-scaled to keep the source aspect ratio
        quality: 75,
      );

      App.logger.info("Thumb fetched from server. filaName: $fileName");
      return fileName != null ? File(fileName) : null;
    } catch (e) {
      App.logger.severe(e);
    }

    return null;
  }
}
