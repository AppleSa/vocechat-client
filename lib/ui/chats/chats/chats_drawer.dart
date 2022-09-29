import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vocechat_client/app.dart';
import 'package:vocechat_client/app_alert_dialog.dart';
import 'package:vocechat_client/app_text_styles.dart';
import 'package:vocechat_client/dao/org_dao/chat_server.dart';
import 'package:vocechat_client/dao/org_dao/status.dart';
import 'package:vocechat_client/dao/org_dao/userdb.dart';
import 'package:vocechat_client/ui/app_colors.dart';
import 'package:vocechat_client/ui/auth/server_page.dart';
import 'package:vocechat_client/ui/widgets/avatar/avatar_size.dart';
import 'package:vocechat_client/ui/widgets/avatar/user_avatar.dart';

class ChatsDrawer extends StatefulWidget {
  const ChatsDrawer(
      {required this.disableGesture, Key? key, this.afterDrawerPop})
      : super(key: key);

  final void Function(bool isBusy) disableGesture;
  final VoidCallback? afterDrawerPop;

  @override
  State<ChatsDrawer> createState() => _ChatsDrawerState();
}

class _ChatsDrawerState extends State<ChatsDrawer> {
  List<ValueNotifier<ServerSwitchData>> accountList = [];

  ValueNotifier<bool> isBusy = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _getServerData();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.8;
    final titleStr = accountList.length > 1 ? "Servers" : "Server";

    return Container(
        width: min(maxWidth, 320),
        height: double.maxFinite,
        color: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        titleStr,
                        style: AppTextStyles.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: isBusy,
                      builder: (context, isBusy, child) {
                        if (isBusy) {
                          return CupertinoActivityIndicator();
                        } else {
                          return SizedBox.shrink();
                        }
                      },
                    )
                  ],
                ),
              ),
              SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  separatorBuilder: (context, index) {
                    return Divider(indent: 86);
                  },
                  itemCount: accountList.length + 1,
                  itemBuilder: (context, index) {
                    if (index == accountList.length) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _onTapAdd,
                            child: Padding(
                                padding:
                                    const EdgeInsets.only(right: 16, top: 8),
                                child: Row(
                                  children: const [
                                    Icon(Icons.add),
                                    SizedBox(width: 4),
                                    Text("Add new account")
                                  ],
                                )),
                          ),
                        ],
                      );
                    } else {
                      final accountData = accountList[index];
                      return CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _switchUser(accountData.value),
                          child: ServerDrawerTile(
                            accountData: accountData,
                            onLogoutTapped: _onLogoutTapped,
                          ));
                    }
                  },
                ),
              ),
            ],
          ),
        ));
  }

  void _onTapAdd() async {
    final route = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          ServerPage(showClose: true),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.fastOutSlowIn;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
    Navigator.of(context).push(route);
  }

  void _switchUser(ServerSwitchData accountData) async {
    final status = await StatusMDao.dao.getStatus();

    if (status?.userDbId == accountData.userDbM.id) {
      _jumpToMainPage();
      return;
    }

    widget.disableGesture(true);
    isBusy.value = true;

    await App.app.changeUser(accountData.userDbM);

    accountList.clear();
    await _getServerData();
    if (mounted) {
      setState(() {});
    }
    widget.disableGesture(false);
    isBusy.value = false;

    _jumpToMainPage();
  }

  void _jumpToMainPage() async {
    Navigator.pop(context);
    if (widget.afterDrawerPop != null) {
      await Future.delayed(Duration(milliseconds: 300));
      widget.afterDrawerPop!();
    }
  }

  Future<void> _getServerData() async {
    final userDbList = await UserDbMDao.dao.getList();

    final status = await StatusMDao.dao.getStatus();

    if (userDbList == null || userDbList.isEmpty || status == null) return;

    for (final userDb in userDbList) {
      final serverId = userDb.chatServerId;

      final chatServer = await ChatServerDao.dao.getServerById(serverId);

      if (chatServer == null || userDb.loggedIn == 0) {
        continue;
      }

      accountList.add(ValueNotifier<ServerSwitchData>(ServerSwitchData(
          serverAvatarBytes: chatServer.logo,
          userAvatarBytes: userDb.avatarBytes,
          serverName: chatServer.properties.serverName,
          serverUrl: chatServer.fullUrl,
          username: userDb.userInfo.name,
          userEmail: userDb.userInfo.email ?? "",
          selected: status.userDbId == userDb.id,
          userDbM: userDb)));
    }
    setState(() {});
  }

  void _onLogoutTapped() async {
    widget.disableGesture(true);
    isBusy.value = true;

    await App.app.authService?.logout().then((value) async {
      await App.app.changeUserAfterLogOut();
    });

    accountList.clear();
    await _getServerData();
    if (mounted) {
      setState(() {});
    }
    widget.disableGesture(false);
    isBusy.value = false;

    return;
  }
}

class ServerSwitchData {
  final Uint8List serverAvatarBytes;
  final Uint8List userAvatarBytes;
  final String serverName;
  final String serverUrl;
  final String username;
  final String userEmail;
  final bool selected;

  final UserDbM userDbM;

  ServerSwitchData(
      {required this.serverAvatarBytes,
      required this.userAvatarBytes,
      required this.serverName,
      required this.serverUrl,
      required this.username,
      required this.userEmail,
      required this.selected,
      required this.userDbM});
}

class ServerDrawerTile extends StatefulWidget {
  ValueNotifier<ServerSwitchData> accountData;
  final VoidCallback onLogoutTapped;

  ServerDrawerTile({required this.accountData, required this.onLogoutTapped});

  @override
  State<ServerDrawerTile> createState() => _ServerDrawerTileState();
}

class _ServerDrawerTileState extends State<ServerDrawerTile> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ServerSwitchData>(
        valueListenable: widget.accountData,
        builder: (context, account, _) {
          return Container(
              color: account.selected ? AppColors.cyan100 : Colors.white,
              padding: EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
              child: Row(
                children: [
                  Flexible(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildAvatar(account.serverAvatarBytes,
                            account.userAvatarBytes, account.username),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildInfo(
                              account.serverName,
                              account.serverUrl,
                              account.username,
                              account.userEmail),
                        ),
                        SizedBox(width: 8),
                      ],
                    ),
                  ),
                  _buildMore()
                ],
              ));
        });
  }

  Widget _buildAvatar(
      Uint8List serverAvatarBytes, Uint8List userAvatarBytes, String username) {
    final serverAvatar = CircleAvatar(
        foregroundImage: MemoryImage(serverAvatarBytes),
        backgroundColor: Colors.white,
        radius: 24);
    final userAvatar = UserAvatar(
        avatarSize: AvatarSize.s36,
        uid: -1,
        name: username,
        avatarBytes: userAvatarBytes);

    return SizedBox(
      height: 66,
      width: 66,
      child: Stack(children: [
        Positioned(top: 0, left: 0, child: serverAvatar),
        Positioned(right: 0, bottom: 0, child: userAvatar)
      ]),
    );
  }

  Widget _buildInfo(
      String serverName, String serverUrl, String username, String userEmail) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(serverName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.titleLarge),
      Text(serverUrl,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall),
      Padding(
          padding: EdgeInsets.only(left: 0, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium),
              Text(userEmail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall)
            ],
          ))
    ]);
  }

  Widget _buildMore() {
    return CupertinoButton(
        padding: EdgeInsets.zero,
        child: SizedBox(width: 32, height: 32, child: Icon(Icons.more_horiz)),
        onPressed: () {
          // logout
          showCupertinoModalPopup(
              context: context,
              builder: (context) {
                return CupertinoActionSheet(
                  actions: [
                    CupertinoActionSheetAction(
                        onPressed: () {
                          showAppAlert(
                            context: context,
                            title: "Log Out",
                            content:
                                "Are you sure to log out \"${widget.accountData.value.serverName}\"?",
                            actions: [
                              AppAlertDialogAction(
                                  text: "Cancel",
                                  action: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                  }),
                            ],
                            primaryAction: AppAlertDialogAction(
                                text: "Log Out",
                                action: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pop();
                                  _onTapLogOut();
                                },
                                isDangerAction: true),
                          );
                        },
                        child: Text(
                          "Log Out",
                          style: TextStyle(color: AppColors.systemRed),
                        )),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text("Cancel")),
                );
              });
        });
  }

  Future<void> _onTapLogOut() async {
    widget.onLogoutTapped();
  }
}
