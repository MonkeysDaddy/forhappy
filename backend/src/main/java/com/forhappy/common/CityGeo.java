package com.forhappy.common;

import java.util.Map;

/** 城市中心坐标（与种子数据 data.sql 保持一致；未知城市回退杭州） */
public final class CityGeo {

    private static final Map<String, double[]> CENTERS = Map.of(
            "杭州", new double[]{30.2741, 120.1551},
            "上海", new double[]{31.2304, 121.4737},
            "北京", new double[]{39.9042, 116.4074},
            "深圳", new double[]{22.5431, 114.0579},
            "成都", new double[]{30.5728, 104.0668});

    private CityGeo() {}

    public static double lat(String city) {
        return CENTERS.getOrDefault(city, CENTERS.get("杭州"))[0];
    }

    public static double lng(String city) {
        return CENTERS.getOrDefault(city, CENTERS.get("杭州"))[1];
    }

    /** 经纬度反解最近城市（无外部逆地理编码服务时的演示替代） */
    public static String nearestCity(double lat, double lng) {
        String best = "杭州";
        double bestDist = Double.MAX_VALUE;
        for (var e : CENTERS.entrySet()) {
            double d = Math.hypot(lat - e.getValue()[0], lng - e.getValue()[1]);
            if (d < bestDist) {
                bestDist = d;
                best = e.getKey();
            }
        }
        return best;
    }
}
