class AppAssets {
  AppAssets._();

  static const String imagePath = 'assets/images';
  static const String rivePath = 'assets/rive';
  static const String videoPath = 'assets/videos';

  static const String foxHappy = '$imagePath/fox.png';
  static const String foxSad = '$imagePath/fox_sad.png';
  static const String foxThinking = '$imagePath/fox_thinking.png';
  static const String foxMailbox = '$imagePath/fox_mailbox.png';

  static const String treeSeed = '$imagePath/seed.png';
  static const String treeSprout = '$imagePath/sprout.png';
  static const String treeSeedling = '$imagePath/seedling.png';
  static const String treeYoung = '$imagePath/young_tree.png';
  static const String treeMature = '$imagePath/mature_tree.png';
  static const String forestBackground = '$imagePath/forestBG.jpg';

  static const String foxRunVideo = '$videoPath/fox_run.mp4';
  static const String foxKeepGoingVideo = '$videoPath/fox_keepgoing.mp4';
  static const String foxJumpVideo = '$videoPath/fox_jump.mp4';

  static const String hobieRive = '$rivePath/hobie_welcome.riv';

  static String avatar(String avatar, String gender) =>
      '$imagePath/avatar_${avatar}_${gender == 'female' ? 'f' : 'm'}.png';
}
