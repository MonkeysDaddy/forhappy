package com.forhappy.admin;

import com.forhappy.common.BizException;
import com.forhappy.common.Result;
import com.forhappy.entity.Photo;
import com.forhappy.mapper.AdminManageMapper;
import com.forhappy.mapper.MomentMapper;
import com.forhappy.mapper.PhotoMapper;
import com.forhappy.mapper.UserMapper;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 内容审核队列：照片 / 动态 先审后发 */
@RestController
@RequestMapping("/api/v1/admin/reviews")
@RequiredArgsConstructor
public class AdminReviewController {

    private final PhotoMapper photoMapper;
    private final MomentMapper momentMapper;
    private final UserMapper userMapper;
    private final com.forhappy.mapper.NotificationMapper notificationMapper;
    private final AdminApiSupport support;

    @GetMapping("/photos")
    public Result<?> photos(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        support.require(key, authHeader, "content");
        return Result.ok(photoMapper.pending());
    }

    /** action=1 通过（含头像激活）/ 2 驳回 */
    @PostMapping("/photos/{id}")
    public Result<Void> reviewPhoto(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id,
            @RequestParam int action) {
        support.require(key, authHeader, "content");
        Photo photo = photoMapper.findById(id);
        if (photo == null) {
            throw new BizException(404, "照片不存在");
        }
        int status = action == 1 ? 1 : 2;
        photoMapper.setReviewStatus(id, status);
        if (action == 1 && photo.getIsAvatar() != null && photo.getIsAvatar() == 1) {
            // 头像照通过后激活（与用户自传逻辑一致）
            userMapper.updateAvatar(photo.getUserId(), photo.getUrl());
        }
        // 审核结果通知作者
        notificationMapper.insert(photo.getUserId(), "system",
                action == 1 ? "头像审核通过" : "头像审核未通过",
                action == 1 ? "你的新头像已通过审核并生效" : "你上传的头像未通过审核，请更换后重试");
        support.log("review.photo", "照片 #" + id + (action == 1 ? " 通过" : " 驳回"));
        return Result.ok();
    }

    @GetMapping("/moments")
    public Result<?> moments(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        support.require(key, authHeader, "content");
        return Result.ok(momentMapper.pending());
    }

    @PostMapping("/moments/{id}")
    public Result<Void> reviewMoment(
            @RequestHeader(value = "X-Admin-Key", required = false) String key,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @PathVariable long id,
            @RequestParam int action,
            @RequestParam(required = false) String reason) {
        support.require(key, authHeader, "content");
        if (action != 1 && action != 2) {
            throw new BizException(400, "无效操作");
        }
        Long author = momentMapper.findUserIdById(id);
        momentMapper.setStatus(id, action);
        if (author != null) {
            notificationMapper.insert(author, "system",
                    action == 1 ? "动态审核通过" : "动态审核未通过",
                    action == 1
                            ? "你发布的动态已通过审核，已在社区展示"
                            : "你发布的动态未通过审核"
                                    + (reason == null || reason.isBlank()
                                            ? "，未能展示"
                                            : "：" + reason)
                                    + "。如有疑问请联系客服");
        }
        support.log("review.moment", "动态 #" + id + (action == 1 ? " 通过" : " 驳回"));
        return Result.ok();
    }
}
