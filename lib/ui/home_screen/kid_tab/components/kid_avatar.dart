import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gowhymo/db/kid.dart';

/// 获取Kid的头像图片
Widget getKidAvatar(Kid kid, BuildContext context) {
  switch (kid.avatarType) {
    case AvatarType.randomAvatar:
      return SizedBox.expand(
        child: ClipOval(
          child: SvgPicture.string(
            kid.avatarImageData ?? '',
            fit: BoxFit.cover,
          ),
        ),
      );
    case AvatarType.imageFile:
      return SizedBox.expand(
        child: ClipOval(
          child: Image.memory(
            base64Decode(kid.avatarImageData ?? ''),
            fit: BoxFit.cover,
          ),
        ),
      );
    default:
      return Icon(
        Icons.camera_alt,
        size: MediaQuery.sizeOf(context).height / 10,
      );
  }
}