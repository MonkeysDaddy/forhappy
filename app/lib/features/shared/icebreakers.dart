import '../../models/models.dart';

/// 客户端共同点计算（与后端模板一致，作为无服务端数据时的兜底）
List<String> commonTagsFor(
  PersonCard p,
  List<String> myTags, {
  String? myCity,
}) {
  final tags = <String>[];
  for (final t in p.tags) {
    if (myTags.contains(t)) tags.add('都喜欢$t');
    if (tags.length >= 3) return tags;
  }
  if (myCity != null && myCity.isNotEmpty && myCity == p.city) {
    tags.add('同在$myCity');
  }
  return tags.take(3).toList();
}

/// 客户端破冰话术生成（与后端模板一致，作为无服务端数据时的兜底）
List<String> icebreakersFor(
  PersonCard p,
  List<String> myTags, {
  String? myCity,
}) {
  final list = <String>[];
  final common = p.tags.where(myTags.contains).toList();
  if (common.isNotEmpty) {
    list.add('你们都「${common.first}」，最近一次入坑是什么时候？');
  }
  if (list.length < 3 && p.city.isNotEmpty && p.city == myCity) {
    list.add('都在$p.city，你最喜欢哪条散步路线？');
  }
  if (list.length < 3 && p.city.isNotEmpty && p.city != myCity) {
    list.add('一直想去${p.city}玩，有什么私藏推荐吗？');
  }
  if (list.length < 3 && p.occupation.isNotEmpty) {
    list.add('好奇问一下，${p.occupation}的日常是什么样的？');
  }
  if (list.length < 3) list.add('最近有什么值得安利的电影或歌吗？');
  if (list.length < 3) list.add('周末一般喜欢宅着还是出去玩？');
  return list.take(3).toList();
}
