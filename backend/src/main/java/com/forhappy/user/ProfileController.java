package com.forhappy.user;

import com.forhappy.common.BizException;
import com.forhappy.common.Result;
import com.forhappy.common.UserContext;
import com.forhappy.entity.Photo;
import com.forhappy.entity.User;
import com.forhappy.mapper.PhotoMapper;
import com.forhappy.mapper.UserMapper;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/profile")
@RequiredArgsConstructor
public class ProfileController {

    private final UserMapper userMapper;
    private final PhotoMapper photoMapper;

    @GetMapping("/me")
    public Result<Map<String, Object>> me() {
        User u = userMapper.findById(UserContext.get());
        if (u == null) {
            throw new BizException(404, "用户不存在");
        }
        List<Photo> photos = photoMapper.listByUser(u.getId());
        // 本人视角：附带待审照片（App 照片墙可显示"审核中"标记）
        List<Photo> photosMine = photoMapper.listMineByUser(u.getId());
        Map<String, Object> data = new HashMap<>();
        data.put("user", u);
        data.put("photos", photos);
        data.put("photosMine", photosMine);
        return Result.ok(data);
    }

    @PutMapping("/me")
    public Result<Void> update(@RequestBody User body) {
        long uid = UserContext.get();
        // 内容审核（设计 4.2/6.1）：昵称与简介拦截联系方式引流
        com.forhappy.common.ContentFilter.checkNickname(body.getNickname());
        com.forhappy.common.ContentFilter.checkBio(body.getBio());
        body.setId(uid);
        userMapper.updateProfile(body);
        return Result.ok();
    }

    /** 上报 GPS 定位：更新坐标并反解最近城市（设计 3.2/7.5） */
    @PostMapping("/location")
    public Result<Map<String, Object>> updateLocation(
            @RequestBody Map<String, Object> body) {
        long uid = UserContext.get();
        double lat = ((Number) body.get("lat")).doubleValue();
        double lng = ((Number) body.get("lng")).doubleValue();
        String city = com.forhappy.common.CityGeo.nearestCity(lat, lng);
        userMapper.updateLocation(uid, lat, lng, city);
        Map<String, Object> data = new HashMap<>();
        data.put("city", city);
        return Result.ok(data);
    }

    /** 真人认证（演示版）：上传自拍照即自动通过；正式版接机审+人审异步回调 */
    @PostMapping("/verify")
    public Result<Map<String, Object>> verify(@RequestBody Map<String, Object> body) {
        long uid = UserContext.get();
        String photo = body.get("photo") == null ? "" : body.get("photo").toString();
        if (!photo.startsWith("/files/")) {
            throw new com.forhappy.common.BizException(400, "请先上传认证自拍照");
        }
        userMapper.updateVerified(uid);
        Map<String, Object> data = new HashMap<>();
        data.put("verified", 1);
        return Result.ok(data);
    }

    @PostMapping("/photos")
    public Result<Void> addPhoto(@RequestBody Map<String, Object> body) {
        long uid = UserContext.get();
        Photo p = new Photo();
        p.setUserId(uid);
        p.setUrl(String.valueOf(body.get("url")));
        p.setSortOrder(body.containsKey("sortOrder")
                ? ((Number) body.get("sortOrder")).intValue() : 0);
        p.setIsAvatar(Boolean.TRUE.equals(body.get("isAvatar")) ? 1 : 0);
        photoMapper.insert(p);
        if (p.getIsAvatar() == 1) {
            activateAvatar(uid, p.getUrl());
        }
        return Result.ok();
    }

    /** 设为头像（设计 4.2：第一张照片为头像）
     *  PUT /photos/{id} {isAvatar:true} */
    @PutMapping("/photos/{id}")
    public Result<Void> updatePhoto(@PathVariable long id,
                                    @RequestBody Map<String, Object> body) {
        long uid = UserContext.get();
        Photo p = photoMapper.findById(id);
        if (p == null || p.getUserId() != uid) {
            throw new BizException(404, "照片不存在");
        }
        if (Boolean.TRUE.equals(body.get("isAvatar"))) {
            photoMapper.clearAvatar(uid);
            photoMapper.markAvatar(id, uid);
            activateAvatar(uid, p.getUrl());
        }
        return Result.ok();
    }

    /** 删除照片（至少保留 1 张由客户端保证；头像被删时回退到剩余第一张） */
    @org.springframework.web.bind.annotation.DeleteMapping("/photos/{id}")
    public Result<Void> deletePhoto(@PathVariable long id) {
        long uid = UserContext.get();
        Photo p = photoMapper.findById(id);
        if (p == null || p.getUserId() != uid) {
            throw new BizException(404, "照片不存在");
        }
        photoMapper.delete(id, uid);
        if (p.getIsAvatar() != null && p.getIsAvatar() == 1) {
            List<Photo> rest = photoMapper.listByUser(uid);
            if (!rest.isEmpty()) {
                photoMapper.clearAvatar(uid);
                photoMapper.markAvatar(rest.get(0).getId(), uid);
                userMapper.updateAvatar(uid, rest.get(0).getUrl());
            }
        }
        return Result.ok();
    }

    /** 同步头像：清除其他照片头像位 + 更新用户主头像 */
    private void activateAvatar(long uid, String url) {
        photoMapper.clearAvatar(uid);
        // 重新标记刚插入/选定的那张
        List<Photo> all = photoMapper.listByUser(uid);
        for (Photo photo : all) {
            if (url.equals(photo.getUrl())) {
                photoMapper.markAvatar(photo.getId(), uid);
                break;
            }
        }
        userMapper.updateAvatar(uid, url);
    }
}
